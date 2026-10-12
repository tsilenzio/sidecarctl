// sidecarctl boost: mirroring Sidecar's display from a virtual display set to a
// higher refresh rate has the Mac render at that rate and Sidecar stream what it
// rendered. On one ProMotion iPad on macOS 27 that was plainly more responsive than
// Sidecar alone. Nothing here measures what an iPad ends up showing, so the rate is
// a request and never a result to report. The virtual display uses CoreGraphics'
// private CGVirtualDisplay, declared in the CGVirtualDisplayPrivate target.

import AppKit
import CGVirtualDisplayPrivate
import SidecarctlLogic

let boostLockPath = NSTemporaryDirectory() + "sidecarctl-boost.lock"

// The display of the live session, once it is up. SidecarCore is asked for its ID,
// and a session that reports none is looked for by name, which only works where
// macOS names the display in English.
//
// Either way the answer comes off NSScreen's list, and not only to know the display
// is up: a process that never reads that list is later given no modes for the
// virtual display by CoreGraphics, which left --retina with nothing to switch to.
func sidecarDisplay(_ manager: NSObject) -> CGDirectDisplayID? {
    let screens = NSScreen.screens.compactMap { screen in
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { ($0.uint32Value, screen) }
    }
    let reported = connectedDevices(manager).compactMap { sessionValue(manager, $0, "displayID") }
    return screens.first { reported.contains(Int($0.0)) }?.0
        ?? screens.first { $0.1.localizedName.contains("Sidecar") }?.0
}

func waitFor<T>(_ seconds: TimeInterval, _ find: () -> T?) -> T? {
    let deadline = Date().addingTimeInterval(seconds)
    while true {
        if let found = find() { return found }
        if Date() >= deadline { return nil }
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    }
}

// The lock is held for the life of a boost, so a held lock means one is running, and
// the file holds its pid. A boost that was just stopped may still be exiting, so a
// new one waits a moment for the lock before giving up.
func takeBoostLock() -> Int32? {
    let fd = open(boostLockPath, O_RDWR | O_CREAT, 0o600)
    guard fd >= 0 else { return nil }
    guard waitFor(3, { flock(fd, LOCK_EX | LOCK_NB) == 0 ? true : nil }) != nil else {
        close(fd)
        return nil
    }
    ftruncate(fd, 0)
    let pid = "\(getpid())\n"
    _ = pid.withCString { write(fd, $0, strlen($0)) }
    return fd
}

func stopBoost() {
    let fd = open(boostLockPath, O_RDONLY)
    guard fd >= 0 else { return print("no boost running") }
    defer { close(fd) }
    if flock(fd, LOCK_SH | LOCK_NB) == 0 { return print("no boost running") }
    let text = (try? String(contentsOfFile: boostLockPath, encoding: .utf8)) ?? ""
    guard let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)), kill(pid, SIGTERM) == 0 else {
        fail(.sidecarError, "could not stop the running boost")
    }
    print("stopped boost")
}

// ending runs when the boost is stopped, and not when it ends because its session did
func boost(hz: Double, retina: Bool, ending: (() -> Void)? = nil) -> Never {
    guard takeBoostLock() != nil else { fail(.alreadyRunning, "a boost is already running") }
    let sidecarManager = manager()
    guard let sidecar = waitFor(10, { sidecarDisplay(sidecarManager) }) else { fail(.noDevices, "no Sidecar display appeared") }
    guard let mode = CGDisplayCopyDisplayMode(sidecar) else { fail(.sidecarError, "could not read the Sidecar display's mode") }
    // Retina doubles the pixels each way at the same size in points
    let scale = retina && mode.pixelWidth == mode.width ? 2 : 1

    let descriptor = CGVirtualDisplayDescriptor()
    descriptor.queue = DispatchQueue.main
    // Named after the iPad, which is what Displays settings shows under the Mac's name.
    // The fallback avoids "Sidecar Display", the name of Sidecar's own.
    descriptor.name = "sidecarctl virtual display"
    if let device = connectedDevices(sidecarManager).first {
        descriptor.setDisplayInfoValue(["en_US": "\(name(of: device)) (sidecarctl)"], forKey: "DisplayProductName")
    }
    descriptor.maxPixelsWide = UInt32(mode.pixelWidth * scale)
    descriptor.maxPixelsHigh = UInt32(mode.pixelHeight * scale)
    let size = CGDisplayScreenSize(sidecar)
    descriptor.sizeInMillimeters = size.width > 0 ? size : CGSize(width: 280, height: 210)
    // Fixed IDs, so macOS remembers where the display was arranged from one session
    // to the next
    descriptor.vendorID = 0xCADD
    descriptor.productID = 0x5C
    descriptor.serialNum = 1
    descriptor.terminationHandler = { _, _ in exit(0) }
    guard let virtual = CGVirtualDisplay(descriptor: descriptor) else {
        fail(.sidecarError, "could not create the virtual display")
    }
    let settings = CGVirtualDisplaySettings()
    let retinaWidth = mode.pixelWidth * scale
    let hiDPI = retinaWidth > mode.width
    settings.hiDPI = hiDPI ? 1 : 0
    // With HiDPI on, macOS offers each mode both as given and scaled to half, so the
    // double-size mode also yields the Retina mode at the Sidecar display's size
    settings.modes = (hiDPI ? [(retinaWidth, mode.pixelHeight * scale)] : []).map {
        CGVirtualDisplayMode(width: UInt32($0.0), height: UInt32($0.1), refreshRate: hz)
    } + [CGVirtualDisplayMode(width: UInt32(mode.width), height: UInt32(mode.height), refreshRate: hz)]
    guard virtual.apply(settings) else { fail(.sidecarError, "the virtual display refused its mode") }
    let id = virtual.displayID

    // macOS offers scaled sizes besides the one asked for and may start on one of
    // them, so the matching mode is set explicitly once the display has registered
    let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
    func sized() -> [CGDisplayMode] {
        ((CGDisplayCopyAllDisplayModes(id, options) as? [CGDisplayMode]) ?? [])
            .filter { $0.width == mode.width && $0.height == mode.height }
    }
    // The mirror is set up at the Sidecar display's own mode, since mirroring onto it
    // in Retina failed with CGError 1001
    let target = waitFor(5) { sized().filter { $0.pixelWidth == mode.pixelWidth }.max { $0.refreshRate < $1.refreshRate } }
        ?? sized().max { $0.refreshRate < $1.refreshRate }

    // Set before mirroring and on its own, since a mode change in the same
    // configuration as the mirror leaves the mirror unapplied without an error
    if let target, CGDisplaySetDisplayMode(id, target, nil) == .success {
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    }

    var config: CGDisplayConfigRef?
    CGBeginDisplayConfiguration(&config)
    CGConfigureDisplayMirrorOfDisplay(config, sidecar, id)
    // App-only, so macOS undoes the mirroring when this process exits, however it ends
    let result = CGCompleteDisplayConfiguration(config, .forAppOnly)
    guard result == .success else { fail(.sidecarError, "mirroring failed: CGError \(result.rawValue)") }
    guard waitFor(3, { CGDisplayMirrorsDisplay(sidecar) == id ? true : nil }) != nil else {
        fail(.sidecarError, "the Sidecar display did not take the mirror")
    }
    // Then the mirror's source moves to Retina, and Sidecar's display, as its copy,
    // follows
    // Read back now, since the modes are often not listed until the mirror is up
    var pixels = waitFor(3) { CGDisplayCopyDisplayMode(id)?.pixelWidth } ?? mode.pixelWidth
    if scale > 1 {
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        guard let sharp = waitFor(3, { sized().filter { $0.pixelWidth == retinaWidth }.max { $0.refreshRate < $1.refreshRate } }) else {
            fail(.sidecarError, "the virtual display offers no Retina mode")
        }
        let result = CGDisplaySetDisplayMode(id, sharp, nil)
        guard result == .success else { fail(.sidecarError, "switching to Retina failed: CGError \(result.rawValue)") }
        pixels = sharp.pixelWidth
    }
    // The rate named is the virtual display's, which is all that is known here
    print("mirroring Sidecar from a virtual display set to \(Int(hz)) Hz, \(mode.width)x\(mode.height) on \(pixels) pixels wide")

    // Ends with the session. SidecarCore is asked rather than CoreGraphics, whose
    // display list in this process stayed stale after the session ended, and whose
    // reconfiguration callback never fired, leaving the virtual display behind.
    let watch = Timer(timeInterval: 2, repeats: true) { _ in
        if connectedDevices(sidecarManager).isEmpty { exit(0) }
    }
    RunLoop.main.add(watch, forMode: .default)
    signal(SIGTERM, SIG_IGN)
    signal(SIGINT, SIG_IGN)
    let signals = [SIGTERM, SIGINT].map { sig -> DispatchSourceSignal in
        let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
        source.setEventHandler {
            ending?()
            exit(0)
        }
        source.resume()
        return source
    }
    // The virtual display lasts only as long as its object
    withExtendedLifetime((virtual, signals, watch)) { RunLoop.main.run() }
    exit(0)
}
