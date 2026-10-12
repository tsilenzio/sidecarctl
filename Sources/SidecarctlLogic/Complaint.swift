// What to say about arguments that parse(_:) turned away, and which command's help
// to show under it, nil being the overview. Worked out apart from the parsing so
// that parsing stays a plain yes or no.

private struct Valued {
    var accepts: (String) -> Bool
    var wants: String
}

private let rate = Valued(accepts: { (Double($0) ?? 0) > 0 }, wants: "a rate above 0, such as 120")

private let valued: [String: [String: Valued]] = [
    "connect": [
        "--connection": Valued(accepts: { Connection(rawValue: $0) != nil },
                               wants: "one of prefer-wired, wired, wireless, system"),
        "--framerate": Valued(accepts: { (Int($0) ?? 0) > 0 }, wants: "a whole number above 0, such as 60"),
        "--retries": Valued(accepts: { (Int($0) ?? -1) >= 0 }, wants: "a whole number, 0 or more"),
        "--hz": rate,
    ],
    "boost": ["--hz": rate],
]

private let flags: [String: Set<String>] = [
    "devices": ["--verbose", "--json"],
    "status": ["--json"],
    "connect": ["--low-latency", "--ignore-not-ready", "--boost", "--retina"],
    "disconnect": [],
    "boost": ["--retina", "--stop"],
]

public func complaint(about args: [String]) -> (message: String, topic: String?) {
    guard let command = args.first else { return ("no command was given.", nil) }
    if command == "help" {
        return ("there is no command `\(args.dropFirst().joined(separator: " "))` to explain.", nil)
    }
    guard commands.contains(command) else {
        return (command.hasPrefix("-") ? "there is no option `\(command)`." : "there is no command `\(command)`.", nil)
    }

    var given: [String] = []
    var devices: [String] = []
    var rest = args.dropFirst()
    while let arg = rest.popFirst() {
        if let option = valued[command]?[arg] {
            guard let value = rest.popFirst() else { return ("`\(arg)` needs a value: \(option.wants).", command) }
            guard option.accepts(value) else { return ("`\(arg)` does not take `\(value)`. It wants \(option.wants).", command) }
            if given.contains(arg) { return ("`\(arg)` was given twice.", command) }
            given.append(arg)
        } else if flags[command]?.contains(arg) == true {
            given.append(arg)
        } else if arg.hasPrefix("-") {
            return ("`\(command)` has no option `\(arg)`.", command)
        } else {
            devices.append(arg)
        }
    }

    let takesDevice = command == "connect" || command == "disconnect"
    if !takesDevice, let extra = devices.first { return ("`\(command)` takes no device, and was given `\(extra)`.", command) }
    if devices.count > 1 { return ("`\(command)` takes one device, and was given \(devices.count).", command) }
    if command == "connect", !given.contains("--boost"), let lone = given.first(where: { $0 == "--hz" || $0 == "--retina" }) {
        return ("`\(lone)` goes with `--boost`.", command)
    }
    if command == "devices", given.contains("--verbose"), given.contains("--json") {
        return ("`--verbose` and `--json` do not go together.", command)
    }
    if command == "boost", given.contains("--stop"), given.count > 1 {
        return ("`--stop` goes on its own.", command)
    }
    return ("`\(command)` cannot be run that way.", command)
}
