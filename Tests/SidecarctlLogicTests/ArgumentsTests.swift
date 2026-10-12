import Testing
@testable import SidecarctlLogic

@Suite struct ArgumentsTests {
    @Test func nothingOrAnUnknownCommandIsNoCommand() {
        #expect(parse([]) == .help(topic: nil))
        #expect(parse(["launch"]) == nil)
    }

    @Test func devices() {
        #expect(parse(["devices"]) == .devices(verbose: false, json: false))
        #expect(parse(["devices", "--verbose"]) == .devices(verbose: true, json: false))
        #expect(parse(["devices", "--json"]) == .devices(verbose: false, json: true))
        #expect(parse(["devices", "--verbose", "--json"]) == nil)
    }

    @Test func status() {
        #expect(parse(["status"]) == .status(json: false))
        #expect(parse(["status", "--json"]) == .status(json: true))
        #expect(parse(["status", "Test iPad"]) == nil)
        #expect(parse(["status", "--verbose"]) == nil)
        #expect(parse(["status", "--connection", "wired"]) == nil)
    }

    @Test func helpForTheTool() {
        #expect(parse(["help"]) == .help(topic: nil))
        #expect(parse(["--help"]) == .help(topic: nil))
        #expect(parse(["-h"]) == .help(topic: nil))
    }

    @Test(arguments: commands)
    func helpForOneCommand(command: String) {
        #expect(parse(["help", command]) == .help(topic: command))
        #expect(parse([command, "--help"]) == .help(topic: command))
        #expect(parse([command, "-h"]) == .help(topic: command))
        #expect(help(for: command).hasPrefix("usage: sidecarctl \(command)"))
        #expect(help(for: command) != help(for: nil))
    }

    @Test func helpForSomethingElseIsNoCommand() {
        #expect(parse(["help", "launch"]) == nil)
        #expect(parse(["help", "connect", "boost"]) == nil)
    }

    @Test func helpAmongOtherOptionsStillHelps() {
        #expect(parse(["connect", "--boost", "--help"]) == .help(topic: "connect"))
    }

    @Test func theOverviewNamesEveryCommand() {
        for command in commands { #expect(help(for: nil).contains("  \(command) ")) }
    }

    @Test func noHelpLineRunsPastATerminal() {
        for topic in commands.map(Optional.some) + [nil] {
            for line in help(for: topic).split(separator: "\n") { #expect(line.count <= 100, "\(line)") }
        }
    }

    @Test func version() {
        #expect(parse(["--version"]) == .version)
        #expect(parse(["--version", "connect"]) == nil)
        #expect(SidecarctlLogic.version.split(separator: ".").count == 3)
    }

    @Test func anUnknownOptionIsNoCommandAndNeverADevice() {
        #expect(parse(["connect", "--wired"]) == nil)
        #expect(parse(["connect", "-w"]) == nil)
        #expect(parse(["disconnect", "--now"]) == nil)
        #expect(parse(["devices", "--all"]) == nil)
        #expect(parse(["status", "--watch"]) == nil)
    }

    @Test func onlyDevicesAndStatusPrintJSON() {
        #expect(parse(["connect", "--json"]) == nil)
        #expect(parse(["disconnect", "--json"]) == nil)
        #expect(parse(["boost", "--json"]) == nil)
    }

    @Test func devicesTakesNoDeviceAndNoConnectFlag() {
        #expect(parse(["devices", "Test iPad"]) == nil)
        #expect(parse(["devices", "--connection", "system"]) == nil)
        #expect(parse(["devices", "--ignore-not-ready"]) == nil)
    }

    @Test func connectDefaults() {
        #expect(parse(["connect"]) == .connect(ConnectOptions()))
        #expect(ConnectOptions().connection == .preferWired)
    }

    @Test func connectWithEverything() {
        let args = ["connect", "Test iPad", "--connection", "wireless", "--framerate", "120", "--low-latency", "--ignore-not-ready"]
        #expect(parse(args) == .connect(ConnectOptions(device: "Test iPad", connection: .wireless, framerate: 120,
                                                       lowLatency: true, ignoreNotReady: true)))
    }

    @Test func flagsMayComeBeforeTheDevice() {
        #expect(parse(["connect", "--connection", "wired", "Test iPad"])
            == .connect(ConnectOptions(device: "Test iPad", connection: .wired)))
    }

    @Test(arguments: ["prefer-wired", "wired", "wireless", "system"])
    func everyConnectionValueIsTaken(value: String) {
        #expect(parse(["connect", "--connection", value]) == .connect(ConnectOptions(connection: Connection(rawValue: value)!)))
    }

    @Test func aBadConnectionIsNoCommand() {
        #expect(parse(["connect", "--connection"]) == nil)
        #expect(parse(["connect", "--connection", "either"]) == nil)
        #expect(parse(["connect", "--connection", "wired", "--connection", "wireless"]) == nil)
    }

    @Test func aBadFramerateIsNoCommand() {
        #expect(parse(["connect", "--framerate"]) == nil)
        #expect(parse(["connect", "--framerate", "fast"]) == nil)
        #expect(parse(["connect", "--framerate", "0"]) == nil)
        #expect(parse(["connect", "--framerate", "-60"]) == nil)
    }

    @Test func oneDeviceAtMost() {
        #expect(parse(["connect", "Test iPad", "Other iPad"]) == nil)
        #expect(parse(["disconnect", "Test iPad", "Other iPad"]) == nil)
    }

    @Test func connectTakesNoVerbose() {
        #expect(parse(["connect", "--verbose"]) == nil)
    }

    @Test func connectAndBoost() {
        #expect(parse(["connect", "--boost"]) == .connect(ConnectOptions(boost: Boost())))
        #expect(Boost().hz == 120)
        #expect(parse(["connect", "Test iPad", "--boost", "--hz", "90", "--retina"])
            == .connect(ConnectOptions(device: "Test iPad", boost: Boost(hz: 90, retina: true))))
        #expect(parse(["connect", "--hz", "90", "--boost"]) == .connect(ConnectOptions(boost: Boost(hz: 90))))
    }

    @Test func aRateOrRetinaNeedsABoost() {
        #expect(parse(["connect", "--hz", "90"]) == nil)
        #expect(parse(["connect", "--retina"]) == nil)
        #expect(parse(["connect", "--boost", "--hz"]) == nil)
        #expect(parse(["connect", "--boost", "--hz", "0"]) == nil)
    }

    @Test func retries() {
        #expect(parse(["connect"]) == .connect(ConnectOptions(retries: 0)))
        #expect(parse(["connect", "--retries", "10"]) == .connect(ConnectOptions(retries: 10)))
        #expect(parse(["connect", "--retries", "0"]) == .connect(ConnectOptions(retries: 0)))
    }

    @Test func aBadRetryCountIsNoCommand() {
        #expect(parse(["connect", "--retries"]) == nil)
        #expect(parse(["connect", "--retries", "-1"]) == nil)
        #expect(parse(["connect", "--retries", "many"]) == nil)
    }

    @Test func onlyConnectBoostsOrRetries() {
        #expect(parse(["disconnect", "--boost"]) == nil)
        #expect(parse(["disconnect", "--retries", "2"]) == nil)
        #expect(parse(["devices", "--boost"]) == nil)
        #expect(parse(["devices", "--retries", "2"]) == nil)
    }

    @Test func disconnect() {
        #expect(parse(["disconnect"]) == .disconnect(device: nil))
        #expect(parse(["disconnect", "Test iPad"]) == .disconnect(device: "Test iPad"))
    }

    @Test func disconnectTakesNoFlag() {
        #expect(parse(["disconnect", "--connection", "wired"]) == nil)
        #expect(parse(["disconnect", "--framerate", "60"]) == nil)
        #expect(parse(["disconnect", "--low-latency"]) == nil)
        #expect(parse(["disconnect", "--ignore-not-ready"]) == nil)
        #expect(parse(["disconnect", "--verbose"]) == nil)
    }

    @Test func boost() {
        #expect(parse(["boost"]) == .boost(hz: 120, retina: false))
        #expect(parse(["boost", "--hz", "90", "--retina"]) == .boost(hz: 90, retina: true))
        #expect(parse(["boost", "--stop"]) == .stopBoost)
    }

    @Test func aBadBoostIsNoCommand() {
        #expect(parse(["boost", "--hz"]) == nil)
        #expect(parse(["boost", "--hz", "0"]) == nil)
        #expect(parse(["boost", "--hz", "fast"]) == nil)
        #expect(parse(["boost", "--stop", "--retina"]) == nil)
        #expect(parse(["boost", "Test iPad"]) == nil)
        #expect(parse(["boost", "--connection", "wired"]) == nil)
    }
}
