import Testing
@testable import SidecarctlLogic

@Suite struct ReportsTests {
    let id = "11111111-1111-1111-1111-111111111111"

    @Test func aDeviceAsJSON() {
        let report = DeviceReport(id: id, name: "Test iPad", status: 0x1880306, connected: true)
        #expect(json([report])
            == #"[{"connected":true,"id":"11111111-1111-1111-1111-111111111111","name":"Test iPad","notReady":false,"status":"0x1880306"}]"#)
    }

    @Test func aDeviceOnRecordAsNotReady() {
        #expect(DeviceReport(id: id, name: "Test iPad", status: 0x880002, connected: false).notReady)
    }

    @Test func aDeviceWithNoStatusIsNotCalledNotReady() {
        let report = DeviceReport(id: id, name: "Test iPad", status: nil, connected: false)
        #expect(!report.notReady)
        #expect(report.status == nil)
    }

    @Test func aSessionNamesItsConnection() {
        let wired = SessionReport(id: id, name: "Test iPad", live: LiveSession(transport: 2, framerate: 60, lowLatency: nil), displayID: 34)
        #expect(wired.connection == "wired")
        #expect(wired.line == "connected to Test iPad, wired, 60 fps")
        let wireless = SessionReport(id: id, name: "Test iPad", live: LiveSession(transport: 1, framerate: 120, lowLatency: 1), displayID: nil)
        #expect(wireless.connection == "wireless")
        #expect(wireless.line == "connected to Test iPad, wireless, 120 fps, low latency")
    }

    @Test func aSessionThatReportsNothing() {
        let session = SessionReport(id: id, name: "Test iPad", live: LiveSession(transport: nil, framerate: nil, lowLatency: nil), displayID: nil)
        #expect(session.connection == nil)
        #expect(session.line == "connected to Test iPad")
    }

    @Test func statusWithNothingRunning() {
        let report = StatusReport(sessions: [], boost: nil)
        #expect(report.lines == ["not connected", "no boost running"])
        #expect(json(report) == #"{"sessions":[]}"#)
    }

    @Test func statusWithASessionAndABoost() {
        let session = SessionReport(id: id, name: "Test iPad", live: LiveSession(transport: 2, framerate: 60, lowLatency: nil), displayID: 34)
        let report = StatusReport(sessions: [session], boost: 4242)
        #expect(report.lines == ["connected to Test iPad, wired, 60 fps", "boost running"])
        #expect(json(report)
            == #"{"boost":4242,"sessions":[{"connection":"wired","displayID":34,"framerate":60,"id":"11111111-1111-1111-1111-111111111111","lowLatency":false,"name":"Test iPad"}]}"#)
    }
}
