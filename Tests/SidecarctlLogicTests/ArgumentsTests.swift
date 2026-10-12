import Testing
@testable import SidecarctlLogic

@Suite struct ArgumentsTests {
    @Test func nothingOrAnUnknownCommandIsNoCommand() {
        #expect(parse([]) == nil)
        #expect(parse(["status"]) == nil)
    }

    @Test func devices() {
        #expect(parse(["devices"]) == .devices(verbose: false))
        #expect(parse(["devices", "--verbose"]) == .devices(verbose: true))
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
