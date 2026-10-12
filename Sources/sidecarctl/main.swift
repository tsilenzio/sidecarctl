// sidecarctl: starts and ends Sidecar sessions from the command line. macOS has no
// public API for Sidecar, so this drives the private SidecarCore framework, the way
// SidecarLauncher (github.com/Ocasio-J/SidecarLauncher, MIT) showed it can be done.
// A macOS update can break it.
//
//   sidecarctl devices [--verbose | --json]     reachable iPads, one per line, each as
//                                               its UUID, a tab, and its name, and with
//                                               --verbose a tab and its status value
//   sidecarctl status [--json]                  the live session and whether a boost is
//                                               running
//   sidecarctl connect [<device>] [--connection <how>] [--framerate <fps>] [--low-latency]
//                      [--ignore-not-ready] [--retries <count>]
//                      [--boost [--hz <rate>] [--retina]]
//                                               start a session, streaming at <fps>, in low
//                                               latency mode, and with --boost run a boost
//                                               on it and end both together
//   sidecarctl disconnect [<device>]            end a session
//   sidecarctl boost [--hz <rate>] [--retina]
//                                               mirror the Sidecar display from a virtual
//                                               one set to <rate>, 120 by default, and in
//                                               its Retina mode with --retina, until it
//                                               goes away or this ends
//   sidecarctl boost --stop                     end a running boost
//
// A device is given by its name or by its UUID from `sidecarctl devices`, either
// without regard to case. Without one the one reachable device is used.
//
// --connection takes one of:
//   prefer-wired   the default: over the cable when an iPad is attached by USB, and
//                  over Wi-Fi when none is or the cable does not connect in two tries
//   wired          over the cable, or not at all
//   wireless       over Wi-Fi, or not at all
//   system         whichever Sidecar picks
//
// Exit codes: 0 done, 1 bad arguments, 2 no reachable devices or no Sidecar display,
// 3 no such device, 4 SidecarCore or CoreGraphics reported an error,
// 5 SidecarCore could not be loaded, 6 no device given and more than one
// reachable, 7 a boost is already running, 8 the transport asked for is unavailable,
// 9 the device reports it is not ready.
//
// A connect that fails makes Sidecar put up a dialog of its own. To spare that, a
// device whose status is one recorded as not ready is not asked at all, and connect
// exits 9. --ignore-not-ready asks anyway. A status not on record is always asked.
//
// --retries allows that many further rounds, 3 s apart, 0 unless given, since every
// round that fails is another dialog. A round spent on a device that is not ready
// only reads its status again, and shows none.

import Foundation
import SidecarctlLogic

func warn(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
}

func fail(_ code: Exit, _ message: String) -> Never {
    warn(message)
    exit(code.rawValue)
}

func manager() -> NSObject {
    guard dlopen("/System/Library/PrivateFrameworks/SidecarCore.framework/SidecarCore", RTLD_LAZY) != nil,
          let managerClass = NSClassFromString("SidecarDisplayManager") as? NSObject.Type,
          let shared = managerClass.perform(Selector(("sharedManager")))?.takeUnretainedValue() as? NSObject
    else { fail(.unavailable, "SidecarCore is not available on this Mac") }
    return shared
}

func devices(_ manager: NSObject) -> [NSObject] {
    let list = manager.perform(Selector(("devices")))?.takeUnretainedValue() as? [NSObject] ?? []
    if list.isEmpty { fail(.noDevices, "no reachable Sidecar devices") }
    return list
}

func connectedDevices(_ manager: NSObject) -> [NSObject] {
    manager.perform(Selector(("connectedDevices")))?.takeUnretainedValue() as? [NSObject] ?? []
}

// A setting of the device's live session, such as its transport or framerate
func sessionValue(_ manager: NSObject, _ device: NSObject, _ key: String) -> Int? {
    let config = manager.perform(Selector(("configForDevice:")), with: device)?.takeUnretainedValue() as? NSObject
    return (config?.value(forKey: key) as? NSNumber)?.intValue
}

func name(of device: NSObject) -> String {
    device.perform(Selector(("name")))?.takeUnretainedValue() as? String ?? ""
}

func status(of device: NSObject) -> UInt64? {
    (device.value(forKey: "status") as? NSNumber)?.uint64Value
}

func identifier(of device: NSObject) -> String {
    (device.perform(Selector(("identifier")))?.takeUnretainedValue() as? NSUUID)?.uuidString ?? ""
}

// The device by that name or UUID, or with neither the only one reachable
func device(matching wanted: String?, in list: [NSObject]) -> NSObject {
    switch pick(wanted, from: list.map { (identifier(of: $0), name(of: $0)) }) {
    case .found(let index):
        return list[index]
    case .ambiguous:
        fail(.ambiguous, "more than one Sidecar device reachable, name one: "
            + list.map { name(of: $0) }.joined(separator: ", "))
    case .noSuch:
        fail(.noSuchDevice, "no Sidecar device matches \(wanted ?? ""), see: sidecarctl devices")
    }
}

// SidecarCore calls back on its own queue, so the main thread waits for it
func runAndWait(_ start: (@escaping @convention(block) (NSError?) -> Void) -> Void) -> NSError? {
    let done = DispatchSemaphore(value: 0)
    var failure: NSError?
    start { error in
        failure = error
        done.signal()
    }
    done.wait()
    return failure
}

func connect(_ manager: NSObject, _ device: NSObject, transport: Transport?, framerate: Int?, lowLatency: Bool) -> NSError? {
    runAndWait { completion in
        if transport != nil || framerate != nil || lowLatency {
            guard let configClass = NSClassFromString("SidecarDisplayConfig") as? NSObject.Type else {
                fail(.unavailable, "SidecarDisplayConfig is not available on this Mac")
            }
            let config = configClass.init()
            if let transport {
                let setTransport = Selector(("setTransport:"))
                typealias SetTransport = @convention(c) (AnyObject, Selector, Int64) -> Void
                unsafeBitCast(config.method(for: setTransport), to: SetTransport.self)(config, setTransport, transport.rawValue)
            }
            // Sidecar asks for 60 when this is left unset
            if let framerate { config.setValue(NSNumber(value: framerate), forKey: "framerate") }
            // Unset unless asked for
            if lowLatency { config.setValue(NSNumber(value: true), forKey: "lowLatency") }

            let connectWithConfig = Selector(("connectToDevice:withConfig:completion:"))
            typealias Connect = @convention(c) (AnyObject, Selector, AnyObject, AnyObject, AnyObject) -> Void
            unsafeBitCast(manager.method(for: connectWithConfig), to: Connect.self)(
                manager, connectWithConfig, device, config, completion as AnyObject)
        } else {
            _ = manager.perform(Selector(("connectToDevice:completion:")), with: device, with: completion)
        }
    }
}

func disconnect(_ manager: NSObject, _ device: NSObject) -> NSError? {
    runAndWait { completion in
        _ = manager.perform(Selector(("disconnectFromDevice:completion:")), with: device, with: completion)
    }
}

// A line at a time even into a pipe or a file, where output is otherwise held back
// until exit, which for a boost is the end of the session
setvbuf(stdout, nil, _IOLBF, 0)

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = parse(arguments) else {
    let (message, topic) = complaint(about: arguments)
    fail(.usage, "sidecarctl: \(message)\n\n\(help(for: topic))")
}

switch command {
case .stopBoost:
    stopBoost()

case .boost(let hz, let retina):
    boost(hz: hz, retina: retina)

case .help(let topic):
    print(help(for: topic))

case .version:
    print(version)

case .devices(let verbose, let asJSON):
    let m = manager()
    let live = Set(connectedDevices(m).map { identifier(of: $0) })
    let reports = devices(m).map {
        DeviceReport(id: identifier(of: $0), name: name(of: $0), status: status(of: $0), connected: live.contains(identifier(of: $0)))
    }
    if asJSON {
        print(json(reports))
    } else {
        for report in reports { print("\(report.id)\t\(report.name)" + (verbose ? "\t\(report.status ?? "unknown")" : "")) }
    }

// Answers with no device reachable too, since the question is only what is running
case .status(let asJSON):
    let m = manager()
    let sessions = connectedDevices(m).map {
        SessionReport(id: identifier(of: $0), name: name(of: $0),
                      live: LiveSession(transport: sessionValue(m, $0, "transport"), framerate: sessionValue(m, $0, "framerate"),
                                        lowLatency: sessionValue(m, $0, "lowLatency")),
                      displayID: sessionValue(m, $0, "displayID"))
    }
    let report = StatusReport(sessions: sessions, boost: runningBoost())
    if asJSON { print(json(report)) } else { report.lines.forEach { print($0) } }

case .connect(let options):
    let m = manager()
    let target = device(matching: options.device, in: devices(m))
    let cabled = iPadOnUSB()
    let attempts = options.connection.attempts(cabled: cabled)
    let current = connectedDevices(m).first { identifier(of: $0) == identifier(of: target) }
    // A session that already matches is kept, since SidecarCore refuses a second with
    // SidecarErrorServiceAlreadyInUse. One over another transport or at another rate,
    // such as a wireless session when the cable goes in, is replaced.
    let matches = current.map {
        LiveSession(transport: sessionValue(m, $0, "transport"), framerate: sessionValue(m, $0, "framerate"),
                    lowLatency: sessionValue(m, $0, "lowLatency"))
            .satisfies(transport: attempts[0], framerate: options.framerate, lowLatency: options.lowLatency)
    } ?? false
    if matches {
        print("already connected to \(name(of: target))")
    } else {
        // Checked before anything is torn down or tried, since a wired connect with no
        // cable fails inside Sidecar, which puts up its own dialog about it
        if options.connection == .wired && !cabled { fail(.noTransport, "no iPad attached by USB") }
        var replaced = false
        var round = 0
        while true {
            // Read afresh each round, since a device that was not ready may be by now
            let fresh = devices(m).first { identifier(of: $0) == identifier(of: target) } ?? target
            let waiting = !options.ignoreNotReady && status(of: fresh).map(notReadyStatuses.contains) == true
            var error: NSError?
            if !waiting {
                if current != nil && !replaced {
                    if let error = disconnect(m, target) { fail(.sidecarError, "disconnect failed: \(error)") }
                    replaced = true
                    // Gives the old session a moment to wind down before the new one starts
                    Thread.sleep(forTimeInterval: 1)
                }
                for (index, transport) in attempts.enumerated() {
                    error = connect(m, fresh, transport: transport, framerate: options.framerate, lowLatency: options.lowLatency)
                    guard let error, index + 1 < attempts.count else { break }
                    if attempts[index + 1] == transport {
                        warn("wired connect to \(name(of: target)) failed, trying once more: \(error)")
                        Thread.sleep(forTimeInterval: 2)
                    } else {
                        warn("wired connect to \(name(of: target)) failed, trying wireless: \(error)")
                    }
                }
                if error == nil { break }
            }
            if round == options.retries {
                if waiting {
                    fail(.notReady, "\(name(of: target)) reports it is not ready. Wake and unlock it and try again, or pass "
                        + "--ignore-not-ready to try anyway.")
                }
                fail(.sidecarError, "connect to \(name(of: target)) failed: \(error!)")
            }
            round += 1
            // A device that is not ready is only looked at again, which costs no dialog
            warn(waiting ? "\(name(of: target)) reports it is not ready, looking again in 3 s"
                : "connect to \(name(of: target)) failed, trying again in 3 s: \(error!)")
            Thread.sleep(forTimeInterval: 3)
        }
        print("connected to \(name(of: target))")
    }
    // The boost and the session then end together, whichever goes first
    if let wanted = options.boost {
        boost(hz: wanted.hz, retina: wanted.retina) {
            if let error = disconnect(m, target) { warn("disconnect failed: \(error)") }
        }
    }

case .disconnect(let wanted):
    let m = manager()
    let target = device(matching: wanted, in: devices(m))
    // SidecarCore reports ending a session that is not there as an error
    if !connectedDevices(m).contains(where: { identifier(of: $0) == identifier(of: target) }) {
        print("not connected to \(name(of: target))")
    } else {
        if let error = disconnect(m, target) { fail(.sidecarError, "disconnect failed: \(error)") }
        print("disconnected from \(name(of: target))")
    }
}
