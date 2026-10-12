public enum Pick: Equatable {
    case found(Int)
    case noSuch
    case ambiguous
}

// The index of the device by that UUID or name, either without regard to case, or
// with neither the only one there is. A UUID is tried before a name.
public func pick(_ wanted: String?, from devices: [(identifier: String, name: String)]) -> Pick {
    guard let wanted = wanted?.lowercased() else {
        if devices.isEmpty { return .noSuch }
        return devices.count > 1 ? .ambiguous : .found(0)
    }
    let index = devices.firstIndex { $0.identifier.lowercased() == wanted }
        ?? devices.firstIndex { $0.name.lowercased() == wanted }
    return index.map { .found($0) } ?? .noSuch
}
