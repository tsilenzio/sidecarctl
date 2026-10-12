public let usage = """
    usage: sidecarctl devices [--verbose]
           sidecarctl connect [<device>] [--connection <prefer-wired | wired | wireless | system>]
                              [--framerate <fps>] [--low-latency] [--ignore-not-ready]
           sidecarctl disconnect [<device>]
           sidecarctl boost [--hz <rate>] [--retina]
           sidecarctl boost --stop
    """

public struct ConnectOptions: Equatable {
    public var device: String?
    public var connection = Connection.preferWired
    public var framerate: Int?
    public var lowLatency = false
    public var ignoreNotReady = false

    public init(device: String? = nil, connection: Connection = .preferWired, framerate: Int? = nil,
                lowLatency: Bool = false, ignoreNotReady: Bool = false) {
        self.device = device
        self.connection = connection
        self.framerate = framerate
        self.lowLatency = lowLatency
        self.ignoreNotReady = ignoreNotReady
    }
}

public enum Command: Equatable {
    case devices(verbose: Bool)
    case connect(ConnectOptions)
    case disconnect(device: String?)
    case boost(hz: Double, retina: Bool)
    case stopBoost
}

// The command the arguments ask for, without the program's own name, or nil when
// they do not make one
public func parse(_ args: [String]) -> Command? {
    var rest = args.dropFirst()
    if args.first == "boost" {
        if rest.elementsEqual(["--stop"]) { return .stopBoost }
        var hz = 120.0
        var retina = false
        while let arg = rest.popFirst() {
            switch arg {
            case "--hz":
                guard let value = rest.popFirst().flatMap({ Double($0) }), value > 0 else { return nil }
                hz = value
            case "--retina":
                retina = true
            default:
                return nil
            }
        }
        return .boost(hz: hz, retina: retina)
    }

    var connection: Connection?
    var framerate: Int?
    var lowLatency = false
    var ignoreNotReady = false
    var verbose = false
    var names: [String] = []
    while let arg = rest.popFirst() {
        switch arg {
        case "--connection":
            guard connection == nil, let value = rest.popFirst().flatMap({ Connection(rawValue: $0) }) else { return nil }
            connection = value
        case "--framerate":
            guard let value = rest.popFirst().flatMap({ Int($0) }), value > 0 else { return nil }
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
    let connecting = connection != nil || framerate != nil || lowLatency || ignoreNotReady
    if names.count > 1 { return nil }

    switch args.first {
    case "devices" where names.isEmpty && !connecting:
        return .devices(verbose: verbose)
    case "connect" where !verbose:
        return .connect(ConnectOptions(device: names.first, connection: connection ?? .preferWired, framerate: framerate,
                                       lowLatency: lowLatency, ignoreNotReady: ignoreNotReady))
    case "disconnect" where !verbose && !connecting:
        return .disconnect(device: names.first)
    default:
        return nil
    }
}
