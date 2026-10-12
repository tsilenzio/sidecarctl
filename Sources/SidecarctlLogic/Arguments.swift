public struct Boost: Equatable {
    public var hz = 120.0
    public var retina = false

    public init(hz: Double = 120, retina: Bool = false) {
        self.hz = hz
        self.retina = retina
    }
}

public struct ConnectOptions: Equatable {
    public var device: String?
    public var connection = Connection.preferWired
    public var framerate: Int?
    public var lowLatency = false
    public var ignoreNotReady = false
    // Further rounds of attempts after the first fails
    public var retries = 0
    // Set to boost the session once it is up, and to end it when the boost ends
    public var boost: Boost?

    public init(device: String? = nil, connection: Connection = .preferWired, framerate: Int? = nil,
                lowLatency: Bool = false, ignoreNotReady: Bool = false, retries: Int = 0, boost: Boost? = nil) {
        self.device = device
        self.connection = connection
        self.framerate = framerate
        self.lowLatency = lowLatency
        self.ignoreNotReady = ignoreNotReady
        self.retries = retries
        self.boost = boost
    }
}

public enum Command: Equatable {
    // With the command to explain, or nil for the tool as a whole
    case help(topic: String?)
    case version
    case devices(verbose: Bool, json: Bool)
    case status(json: Bool)
    case connect(ConnectOptions)
    case disconnect(device: String?)
    case boost(hz: Double, retina: Bool)
    case stopBoost
}

// The command the arguments ask for, without the program's own name, or nil when
// they do not make one, which complaint(about:) then puts into words. No arguments
// at all ask for the overview.
public func parse(_ args: [String]) -> Command? {
    if args.isEmpty { return .help(topic: nil) }
    if args.contains("--help") || args.contains("-h") {
        return .help(topic: args.first.flatMap { commands.contains($0) ? $0 : nil })
    }
    if args.first == "help" {
        if args.count == 1 { return .help(topic: nil) }
        return args.count == 2 && commands.contains(args[1]) ? .help(topic: args[1]) : nil
    }
    if args == ["--version"] { return .version }
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
    var retries: Int?
    var boosting = false
    var hz: Double?
    var retina = false
    var verbose = false
    var json = false
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
        case "--retries":
            guard let value = rest.popFirst().flatMap({ Int($0) }), value >= 0 else { return nil }
            retries = value
        case "--boost":
            boosting = true
        case "--hz":
            guard let value = rest.popFirst().flatMap({ Double($0) }), value > 0 else { return nil }
            hz = value
        case "--retina":
            retina = true
        case "--verbose":
            verbose = true
        case "--json":
            json = true
        default:
            // An option this does not know is a mistake, and never a device's name
            if arg.hasPrefix("-") { return nil }
            names.append(arg)
        }
    }
    let connecting = connection != nil || framerate != nil || lowLatency || ignoreNotReady || retries != nil
        || boosting || hz != nil || retina
    // A rate or Retina is the boost's, so neither means anything without one
    if names.count > 1 || ((hz != nil || retina) && !boosting) { return nil }

    switch args.first {
    case "devices" where names.isEmpty && !connecting && !(verbose && json):
        return .devices(verbose: verbose, json: json)
    case "status" where names.isEmpty && !connecting && !verbose:
        return .status(json: json)
    case "connect" where !verbose && !json:
        return .connect(ConnectOptions(device: names.first, connection: connection ?? .preferWired, framerate: framerate,
                                       lowLatency: lowLatency, ignoreNotReady: ignoreNotReady, retries: retries ?? 0,
                                       boost: boosting ? Boost(hz: hz ?? 120, retina: retina) : nil))
    case "disconnect" where !verbose && !json && !connecting:
        return .disconnect(device: names.first)
    default:
        return nil
    }
}
