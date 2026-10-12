import Testing
@testable import SidecarctlLogic

@Suite struct ComplaintTests {
    @Test func anUnknownCommandGetsTheOverview() {
        let (message, topic) = complaint(about: ["launch"])
        #expect(message == "there is no command `launch`.")
        #expect(topic == nil)
    }

    @Test func anUnknownOptionGetsItsCommandsHelp() {
        let (message, topic) = complaint(about: ["connect", "--wired"])
        #expect(message == "`connect` has no option `--wired`.")
        #expect(topic == "connect")
    }

    @Test func anOptionWithNoCommand() {
        #expect(complaint(about: ["--verbose"]).message == "there is no option `--verbose`.")
    }

    @Test func aMissingValueSaysWhatIsWanted() {
        #expect(complaint(about: ["connect", "--connection"]).message
            == "`--connection` needs a value: one of prefer-wired, wired, wireless, system.")
        #expect(complaint(about: ["boost", "--hz"]).message == "`--hz` needs a value: a rate above 0, such as 120.")
    }

    @Test func aBadValueIsNamed() {
        #expect(complaint(about: ["connect", "--connection", "either"]).message
            == "`--connection` does not take `either`. It wants one of prefer-wired, wired, wireless, system.")
        #expect(complaint(about: ["connect", "--framerate", "fast"]).message
            == "`--framerate` does not take `fast`. It wants a whole number above 0, such as 60.")
        #expect(complaint(about: ["connect", "--retries", "-1"]).message
            == "`--retries` does not take `-1`. It wants a whole number, 0 or more.")
    }

    @Test func tooManyDevices() {
        #expect(complaint(about: ["connect", "Test iPad", "Other iPad"]).message == "`connect` takes one device, and was given 2.")
        #expect(complaint(about: ["status", "Test iPad"]).message == "`status` takes no device, and was given `Test iPad`.")
    }

    @Test func optionsThatNeedEachOtherOrCannotMeet() {
        #expect(complaint(about: ["connect", "--hz", "90"]).message == "`--hz` goes with `--boost`.")
        #expect(complaint(about: ["connect", "--retina"]).message == "`--retina` goes with `--boost`.")
        #expect(complaint(about: ["devices", "--verbose", "--json"]).message == "`--verbose` and `--json` do not go together.")
        #expect(complaint(about: ["boost", "--stop", "--retina"]).message == "`--stop` goes on its own.")
        #expect(complaint(about: ["connect", "--connection", "wired", "--connection", "wireless"]).message
            == "`--connection` was given twice.")
    }

    @Test func helpForNoSuchCommand() {
        #expect(complaint(about: ["help", "launch"]).message == "there is no command `launch` to explain.")
    }

    // Whatever parse turns away has something specific said about it
    @Test(arguments: [
        ["launch"], ["connect", "--wired"], ["connect", "--connection"], ["connect", "a", "b"], ["devices", "x"],
        ["connect", "--hz", "90"], ["boost", "--stop", "--retina"], ["devices", "--verbose", "--json"], ["disconnect", "--json"],
    ])
    func everyRefusalIsExplained(args: [String]) {
        #expect(parse(args) == nil)
        #expect(!complaint(about: args).message.hasSuffix("cannot be run that way."))
    }
}
