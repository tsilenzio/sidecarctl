import Testing
@testable import SidecarctlLogic

@Suite struct DevicesTests {
    let one = [(identifier: "11111111-1111-1111-1111-111111111111", name: "Test iPad")]
    let two = [
        (identifier: "11111111-1111-1111-1111-111111111111", name: "Test iPad"),
        (identifier: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", name: "Other iPad"),
    ]

    @Test func withNothingAskedForTheOnlyDeviceIsPicked() {
        #expect(pick(nil, from: one) == .found(0))
    }

    @Test func withNothingAskedForSeveralDevicesAreAmbiguous() {
        #expect(pick(nil, from: two) == .ambiguous)
    }

    @Test func noDevicesIsNoSuch() {
        #expect(pick(nil, from: []) == .noSuch)
        #expect(pick("Test iPad", from: []) == .noSuch)
    }

    @Test func byName() {
        #expect(pick("Other iPad", from: two) == .found(1))
        #expect(pick("test ipad", from: two) == .found(0))
    }

    @Test func byUUID() {
        #expect(pick("AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", from: two) == .found(1))
        #expect(pick("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", from: two) == .found(1))
    }

    @Test func anUnknownNameOrUUIDIsNoSuch() {
        #expect(pick("Spare iPad", from: two) == .noSuch)
        #expect(pick("00000000-0000-0000-0000-000000000000", from: two) == .noSuch)
        #expect(pick("Test", from: two) == .noSuch)
    }

    @Test func aUUIDWinsOverADeviceNamedAfterIt() {
        let devices = [
            (identifier: "11111111-1111-1111-1111-111111111111", name: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"),
            (identifier: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", name: "Other iPad"),
        ]
        #expect(pick("AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", from: devices) == .found(1))
    }

    @Test func twoDevicesWithOneNameGiveTheFirst() {
        let devices = [
            (identifier: "11111111-1111-1111-1111-111111111111", name: "Test iPad"),
            (identifier: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", name: "Test iPad"),
        ]
        #expect(pick("Test iPad", from: devices) == .found(0))
    }
}
