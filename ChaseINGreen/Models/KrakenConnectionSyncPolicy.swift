import Foundation

enum KrakenConnectionSyncState: String, Equatable {
    case connected
    case syncing
    case fresh
    case lastKnown
    case failed

    var label: String {
        switch self {
        case .connected: return "CONNECTED"
        case .syncing: return "SYNCING"
        case .fresh: return "SYNCED • FRESH"
        case .lastKnown: return "LAST UPDATED"
        case .failed: return "SYNC FAILED"
        }
    }
}

struct KrakenConnectionSyncTracker: Equatable {
    private(set) var states: [String: KrakenConnectionSyncState] = [:]
    private(set) var attemptedConnectionIDs: Set<String> = []

    func state(for connectionID: String, hasLastSync: Bool) -> KrakenConnectionSyncState {
        states[connectionID] ?? (hasLastSync ? .lastKnown : .connected)
    }

    mutating func begin(
        connectionID: String,
        eligibleConnectionIDs: Set<String>,
        force: Bool = false
    ) -> Bool {
        guard eligibleConnectionIDs.contains(connectionID),
              states[connectionID] != .syncing,
              force || !attemptedConnectionIDs.contains(connectionID) else {
            return false
        }
        attemptedConnectionIDs.insert(connectionID)
        states[connectionID] = .syncing
        return true
    }

    mutating func complete(connectionID: String) {
        states[connectionID] = .fresh
    }

    mutating func fail(connectionID: String) {
        states[connectionID] = .failed
    }
}
