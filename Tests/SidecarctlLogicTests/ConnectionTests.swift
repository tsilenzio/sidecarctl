import Testing
@testable import SidecarctlLogic

@Suite struct ConnectionTests {
    @Test func transportValuesAreSidecarsOwn() {
        #expect(Transport.wireless.rawValue == 1)
        #expect(Transport.wired.rawValue == 2)
    }

    @Test func preferWiredTriesTheCableTwiceThenWiFi() {
        #expect(Connection.preferWired.attempts(cabled: true) == [.wired, .wired, .wireless])
    }

    @Test func preferWiredWithNoCableGoesStraightToWiFi() {
        #expect(Connection.preferWired.attempts(cabled: false) == [.wireless])
    }

    @Test(arguments: [true, false])
    func aForcedTransportIsTriedOnceAndNeverFallsBack(cabled: Bool) {
        #expect(Connection.wired.attempts(cabled: cabled) == [.wired])
        #expect(Connection.wireless.attempts(cabled: cabled) == [.wireless])
    }

    @Test(arguments: [true, false])
    func systemLeavesTheChoiceToSidecar(cabled: Bool) {
        #expect(Connection.system.attempts(cabled: cabled) == [nil])
    }

    @Test func aSessionOverTheSameTransportSatisfies() {
        let wired = LiveSession(transport: 2, framerate: 60, lowLatency: nil)
        #expect(wired.satisfies(transport: .wired, framerate: nil, lowLatency: false))
        #expect(!wired.satisfies(transport: .wireless, framerate: nil, lowLatency: false))
    }

    @Test func anySessionSatisfiesWhenSidecarChooses() {
        for transport in [1, 2] {
            let session = LiveSession(transport: transport, framerate: 60, lowLatency: nil)
            #expect(session.satisfies(transport: nil, framerate: nil, lowLatency: false))
        }
    }

    @Test func aFramerateIsComparedOnlyWhenAskedFor() {
        let session = LiveSession(transport: 2, framerate: 60, lowLatency: nil)
        #expect(session.satisfies(transport: .wired, framerate: 60, lowLatency: false))
        #expect(!session.satisfies(transport: .wired, framerate: 120, lowLatency: false))
    }

    @Test func lowLatencyIsComparedOnlyWhenAskedFor() {
        let plain = LiveSession(transport: 2, framerate: 60, lowLatency: nil)
        let low = LiveSession(transport: 2, framerate: 60, lowLatency: 1)
        #expect(!plain.satisfies(transport: .wired, framerate: nil, lowLatency: true))
        #expect(low.satisfies(transport: .wired, framerate: nil, lowLatency: true))
        #expect(low.satisfies(transport: .wired, framerate: nil, lowLatency: false))
    }

    @Test func aSessionThatReportsNothingSatisfiesOnlyAnUnspecificConnect() {
        let unknown = LiveSession(transport: nil, framerate: nil, lowLatency: nil)
        #expect(unknown.satisfies(transport: nil, framerate: nil, lowLatency: false))
        #expect(!unknown.satisfies(transport: .wired, framerate: nil, lowLatency: false))
    }

    // Statuses seen on a device that went on to connect, which must never be refused
    @Test(arguments: [0x880302, 0x1880306] as [UInt64])
    func aStatusSeenToConnectIsNotOnRecordAsNotReady(status: UInt64) {
        #expect(!notReadyStatuses.contains(status))
    }

    @Test func theRecordedNotReadyStatus() {
        #expect(notReadyStatuses.contains(0x880002))
    }
}
