// SidecarDisplayConfig's transport values. 0, its default, lets Sidecar choose, which
// is nil here.
public enum Transport: Int64 {
    case wireless = 1, wired
}

public enum Connection: String {
    case preferWired = "prefer-wired", wired, wireless, system

    // The transports to ask for, in order, each tried only when the one before fails.
    // nil leaves the choice to Sidecar. cabled is whether an iPad is attached by USB.
    public func attempts(cabled: Bool) -> [Transport?] {
        switch self {
        // A wired connect can fail once and then work seconds later, so it gets a
        // second try before Wi-Fi, which would otherwise carry the whole session
        case .preferWired: return cabled ? [.wired, .wired, .wireless] : [.wireless]
        case .wired: return [.wired]
        case .wireless: return [.wireless]
        case .system: return [nil]
        }
    }
}

// What a live session reports of itself, read from its SidecarDisplayConfig
public struct LiveSession {
    public var transport: Int?
    public var framerate: Int?
    public var lowLatency: Int?

    public init(transport: Int?, framerate: Int?, lowLatency: Int?) {
        self.transport = transport
        self.framerate = framerate
        self.lowLatency = lowLatency
    }

    // Whether this session is already what a connect asks for. Only what was asked
    // for is compared, so a session at any framerate satisfies a connect naming none.
    public func satisfies(transport: Transport?, framerate: Int?, lowLatency: Bool) -> Bool {
        (transport == nil || self.transport == Int(transport!.rawValue))
            && (framerate == nil || self.framerate == framerate)
            && (!lowLatency || self.lowLatency == 1)
    }
}

// SidecarDevice status values seen on a device that then refused every connect.
// Whole values rather than bits, since what each bit means is not known, so a device
// that reports anything else is asked as usual. 0x880002 was an iPad16,6 on macOS
// 27.0 that had sat unused for a while, which refused with SidecarErrorDeviceNotFound.
// What puts a device in that state is not known. Locking it alone did not.
public let notReadyStatuses: Set<UInt64> = [0x880002]
