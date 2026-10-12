import Testing
@testable import SidecarctlLogic

@Suite struct ExitTests {
    // Callers branch on these numbers, so a change here is a breaking one
    @Test func theCodesKeepTheirNumbers() {
        let codes: [(Exit, Int32)] = [
            (.ok, 0), (.usage, 1), (.noDevices, 2), (.noSuchDevice, 3), (.sidecarError, 4), (.unavailable, 5),
            (.ambiguous, 6), (.alreadyRunning, 7), (.noTransport, 8), (.notReady, 9),
        ]
        for (code, number) in codes { #expect(code.rawValue == number) }
    }
}
