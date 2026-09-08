import Foundation

struct KrakenConnectionSelectionResolution: Equatable {
    let selectedConnectionID: String?
    let requestedSelectionRejected: Bool
    let storedSelectionRejected: Bool
}

enum KrakenConnectionSelectionPolicy {
    static func resolve(
        eligibleConnectionIDs: [String],
        requestedConnectionID: String?,
        storedConnectionID: String?
    ) -> KrakenConnectionSelectionResolution {
        let eligible = Set(eligibleConnectionIDs)
        let requested = requestedConnectionID.flatMap {
            eligible.contains($0) ? $0 : nil
        }
        let stored = storedConnectionID.flatMap {
            eligible.contains($0) ? $0 : nil
        }
        let only = eligibleConnectionIDs.count == 1
            ? eligibleConnectionIDs.first
            : nil
        return KrakenConnectionSelectionResolution(
            selectedConnectionID: requested ?? stored ?? only,
            requestedSelectionRejected: requestedConnectionID != nil
                && requested == nil,
            storedSelectionRejected: storedConnectionID != nil
                && stored == nil
        )
    }
}
