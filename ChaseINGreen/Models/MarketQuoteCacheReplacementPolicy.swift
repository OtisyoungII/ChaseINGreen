import Foundation

enum MarketQuoteCacheReplacementDecision: Equatable {
    case acceptIncoming
    case retainExistingUnavailable
    case retainExistingNewer
}

enum MarketQuoteCacheReplacementPolicy {
    static func decision(
        existingPrice: Double?,
        existingObservedAt: Date?,
        incomingPrice: Double?,
        incomingObservedAt: Date?
    ) -> MarketQuoteCacheReplacementDecision {
        guard incomingPrice != nil else {
            return existingPrice == nil
                ? .acceptIncoming
                : .retainExistingUnavailable
        }

        if existingPrice != nil,
           let existingObservedAt,
           let incomingObservedAt,
           incomingObservedAt < existingObservedAt {
            return .retainExistingNewer
        }

        return .acceptIncoming
    }
}
