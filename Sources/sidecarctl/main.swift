// sidecarctl: starts and ends Sidecar sessions from the command line. macOS has no
// public API for Sidecar, so this drives the private SidecarCore framework, the way
// SidecarLauncher (github.com/Ocasio-J/SidecarLauncher, MIT) showed it can be done.
// A macOS update can break it.
//
//   sidecarctl devices [--verbose]              reachable iPads, one per line, each as
//                                               its UUID, a tab, and its name, and with
//                                               --verbose a tab and its status value
//   sidecarctl connect [<device>] [--connection <how>] [--framerate <fps>] [--low-latency]
//                      [--ignore-not-ready]     start a session, streaming at <fps>, in low
//                                               latency mode
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

import Foundation

enum Exit: Int32 {
    case ok = 0, usage, noDevices, noSuchDevice, sidecarError, unavailable, ambiguous, alreadyRunning, noTransport, notReady
}

func warn(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
}

func fail(_ code: Exit, _ message: String) -> Never {
    warn(message)
    exit(code.rawValue)
}

let usage = """
    usage: sidecarctl devices [--verbose]
           sidecarctl connect [<device>] [--connection <prefer-wired | wired | wireless | system>]
                              [--framerate <fps>] [--low-latency] [--ignore-not-ready]
           sidecarctl disconnect [<device>]
           sidecarctl boost [--hz <rate>] [--retina]
           sidecarctl boost --stop
    """

// SidecarDisplayConfig's transport values. 0, its default, lets Sidecar choose.
let wirelessTransport: Int64 = 1
let wiredTransport: Int64 = 2

enum Connection: String {
    case preferWired = "prefer-wired", wired, wireless, system

    // The transport to ask for first, nil leaving it to Sidecar
    var transport: Int64? {
        switch self {
        case .preferWired: return iPadOnUSB() ? wiredTransport : wirelessTransport
        case .wired: return wiredTransport
        case .wireless: return wirelessTransport
        case .system: return nil
        }
    }
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

// SidecarDevice status values seen on a device that then refused every connect.
// Whole values rather than bits, since what each bit means is not known, so a device
// that reports anything else is asked as usual. 0x880002 was an iPad16,6 on macOS
// 27.0, thought to be locked or asleep, which refused with SidecarErrorDeviceNotFound.
let notReadyStatuses: Set<UInt64> = [0x880002]

func status(of device: NSObject) -> UInt64? {
    (device.value(forKey: "status") as? NSNumber)?.uint64Value
}

func identifier(of device: NSObject) -> String {
    (device.perform(Selector(("identifier")))?.takeUnretainedValue() as? NSUUID)?.uuidString ?? ""
}

// The device by that name or UUID, or with neither the only one reachable
func device(matching wanted: String?, in list: [NSObject]) -> NSObject {
    guard let wanted else {
        if list.count > 1 {
            fail(.ambiguous, "more than one Sidecar device reachable, name one: "
                + list.map { name(of: $0) }.joined(separator: ", "))
        }
        return list[0]
    }
    let found = list.first { identifier(of: $0).lowercased() == wanted.lowercased() }
        ?? list.first { name(of: $0).lowercased() == wanted.lowercased() }
    guard let found else { fail(.noSuchDevice, "no Sidecar device matches \(wanted), see: sidecarctl devices") }
    return found
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

func connect(_ manager: NSObject, _ device: NSObject, transport: Int64?, framerate: Int?, lowLatency: Bool) -> NSError? {
    runAndWait { completion in
        if transport != nil || framerate != nil || lowLatency {
            guard let configClass = NSClassFromString("SidecarDisplayConfig") as? NSObject.Type else {
                fail(.unavailable, "SidecarDisplayConfig is not available on this Mac")
            }
            let config = configClass.init()
            if let transport {
                let setTransport = Selector(("setTransport:"))
                typealias SetTransport = @convention(c) (AnyObject, Selector, Int64) -> Void
                unsafeBitCast(config.method(for: setTransport), to: SetTransport.self)(config, setTransport, transport)
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

let args = Array(CommandLine.arguments.dropFirst())
let command = args.first

if command == "boost" {
    if args.dropFirst().elementsEqual(["--stop"]) {
        stopBoost()
        exit(0)
    }
    var hz = 120.0
    var retina = false
    var rest = args.dropFirst()
    while let arg = rest.popFirst() {
        switch arg {
        case "--hz":
            guard let value = rest.popFirst().flatMap({ Double($0) }), value > 0 else { fail(.usage, usage) }
            hz = value
        case "--retina":
            retina = true
        default:
            fail(.usage, usage)
        }
    }
    boost(hz: hz, retina: retina)
}

var connection: Connection?
var framerate: Int?
var lowLatency = false
var ignoreNotReady = false
var verbose = false
var names: [String] = []
var rest = args.dropFirst()
while let arg = rest.popFirst() {
    switch arg {
    case "--connection":
        guard connection == nil, let value = rest.popFirst().flatMap({ Connection(rawValue: $0) }) else { fail(.usage, usage) }
        connection = value
    case "--framerate":
        guard let value = rest.popFirst().flatMap({ Int($0) }), value > 0 else { fail(.usage, usage) }
        framerate = value
    case "--low-latency":
        lowLatency = true
    case "--ignore-not-ready":
        ignoreNotReady = true
    case "--verbose":
        verbose = true
    default:
        names.append(arg)
    }
}
if names.count > 1 || ((connection != nil || framerate != nil || lowLatency || ignoreNotReady) && command != "connect")
    || (verbose && command != "devices") { fail(.usage, usage) }
let wanted = names.first

switch command {
case "devices" where names.isEmpty:
    for device in devices(manager()) {
        let reported = status(of: device).map { "0x" + String($0, radix: 16) } ?? "unknown"
        print("\(identifier(of: device))\t\(name(of: device))" + (verbose ? "\t\(reported)" : ""))
    }

case "connect":
    let m = manager()
    let target = device(matching: wanted, in: devices(m))
    let how = connection ?? .preferWired
    let transport = how.transport
    let current = connectedDevices(m).first { identifier(of: $0) == identifier(of: target) }
    // A session that already matches is kept, since SidecarCore refuses a second with
    // SidecarErrorServiceAlreadyInUse. One over another transport or at another rate,
    // such as a wireless session when the cable goes in, is replaced.
    let matches = current.map {
        (transport == nil || sessionValue(m, $0, "transport") == Int(transport!))
            && (framerate == nil || sessionValue(m, $0, "framerate") == framerate)
            && (!lowLatency || sessionValue(m, $0, "lowLatency") == 1)
    } ?? false
    if matches {
        print("already connected to \(name(of: target))")
    } else {
        // Checked before anything is torn down or tried, since a wired connect with no
        // cable fails inside Sidecar, which puts up its own dialog about it
        if !ignoreNotReady, let reported = status(of: target), notReadyStatuses.contains(reported) {
            fail(.notReady, "\(name(of: target)) reports it is not ready, which usually means it is locked or "
                + "asleep. Unlock it and try again, or pass --ignore-not-ready to try anyway.")
        }
        if how == .wired && !iPadOnUSB() { fail(.noTransport, "no iPad attached by USB") }
        if current != nil {
            if let error = disconnect(m, target) { fail(.sidecarError, "disconnect failed: \(error)") }
            // Gives the old session a moment to wind down before the new one starts
            Thread.sleep(forTimeInterval: 1)
        }
        var error = connect(m, target, transport: transport, framerate: framerate, lowLatency: lowLatency)
        if how == .preferWired, transport == wiredTransport {
            // A wired connect can fail once and then work seconds later, so it gets a
            // second try before Wi-Fi, which would otherwise carry the whole session
            if let first = error {
                warn("wired connect to \(name(of: target)) failed, trying once more: \(first)")
                Thread.sleep(forTimeInterval: 2)
                error = connect(m, target, transport: transport, framerate: framerate, lowLatency: lowLatency)
            }
            if let second = error {
                warn("wired connect to \(name(of: target)) failed, trying wireless: \(second)")
                error = connect(m, target, transport: wirelessTransport, framerate: framerate, lowLatency: lowLatency)
            }
        }
        if let error { fail(.sidecarError, "connect to \(name(of: target)) failed: \(error)") }
        print("connected to \(name(of: target))")
    }

case "disconnect":
    let m = manager()
    let target = device(matching: wanted, in: devices(m))
    // SidecarCore reports ending a session that is not there as an error
    if !connectedDevices(m).contains(where: { identifier(of: $0) == identifier(of: target) }) {
        print("not connected to \(name(of: target))")
    } else {
        if let error = disconnect(m, target) { fail(.sidecarError, "disconnect failed: \(error)") }
        print("disconnected from \(name(of: target))")
    }

default:
    fail(.usage, usage)
}
