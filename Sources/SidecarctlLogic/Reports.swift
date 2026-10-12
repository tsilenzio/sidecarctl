import Foundation

// What --json prints. A field keeps its name and meaning once released, and new
// ones may be added, so a caller reads the fields it knows and ignores the rest. A
// field with no value is left out.

public struct DeviceReport: Codable, Equatable {
    public var id: String
    public var name: String
    // SidecarDevice's status, as devices --verbose prints it, or nil when unread
    public var status: String?
    // Whether that status is one recorded as not ready, in which case connect exits 9
    public var notReady: Bool
    public var connected: Bool

    public init(id: String, name: String, status: UInt64?, connected: Bool) {
        self.id = id
        self.name = name
        self.status = status.map(hex)
        self.notReady = status.map(notReadyStatuses.contains) ?? false
        self.connected = connected
    }
}

public struct SessionReport: Codable, Equatable {
    public var id: String
    public var name: String
    // "wired", "wireless", or nil when the session reports neither
    public var connection: String?
    public var framerate: Int?
    public var lowLatency: Bool
    public var displayID: Int?

    public init(id: String, name: String, live: LiveSession, displayID: Int?) {
        self.id = id
        self.name = name
        self.connection = live.transport.flatMap { Transport(rawValue: Int64($0)) }.map { $0 == .wired ? "wired" : "wireless" }
        self.framerate = live.framerate
        self.lowLatency = live.lowLatency == 1
        self.displayID = displayID
    }

    public var line: String {
        let parts = [connection, framerate.map { "\($0) fps" }, lowLatency ? "low latency" : nil].compactMap { $0 }
        return "connected to \(name)" + (parts.isEmpty ? "" : ", " + parts.joined(separator: ", "))
    }
}

public struct StatusReport: Codable, Equatable {
    public var sessions: [SessionReport]
    // The process ID of the running boost, or nil when none is
    public var boost: Int32?

    public init(sessions: [SessionReport], boost: Int32?) {
        self.sessions = sessions
        self.boost = boost
    }

    public var lines: [String] {
        (sessions.isEmpty ? ["not connected"] : sessions.map(\.line)) + [boost == nil ? "no boost running" : "boost running"]
    }
}

public func hex(_ status: UInt64) -> String {
    "0x" + String(status, radix: 16)
}

// One line, keys sorted, so the same state always prints the same text
public func json<T: Encodable>(_ value: T) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return String(decoding: (try? encoder.encode(value)) ?? Data("null".utf8), as: UTF8.self)
}
