import Foundation

struct TradeHomePollingIdentity: Hashable {
    let symbol: String
    let isActive: Bool
    let canAnalyze: Bool

    init(symbol: String, isActive: Bool, canAnalyze: Bool = true) {
        self.symbol = symbol
        self.isActive = isActive
        self.canAnalyze = canAnalyze
    }
}

enum TradeHomeRefreshTrigger {
    case appearance
    case quoteTick
    case foreground
    case symbolChange
    case explicitRefresh
}

enum TradeHomeRefreshPolicy {
    static let quoteInterval: TimeInterval = 60
    static let opportunityFreshness: TimeInterval = 180
    static let preTradeFreshness: TimeInterval = 180
    static let alertFreshness: TimeInterval = 180

    static func isFresh(
        lastDate: Date?,
        lastSymbol: String?,
        symbol: String,
        lifetime: TimeInterval,
        now: Date = Date()
    ) -> Bool {
        guard let lastDate,
              lastSymbol?.caseInsensitiveCompare(symbol) == .orderedSame else {
            return false
        }
        return now.timeIntervalSince(lastDate) < lifetime
    }

    static func shouldStartPolling(isActive: Bool, isVisible: Bool) -> Bool {
        isActive && isVisible
    }

    static func shouldRunAnalysis(
        trigger: TradeHomeRefreshTrigger,
        isFresh: Bool
    ) -> Bool {
        switch trigger {
        case .quoteTick:
            return false
        case .symbolChange, .explicitRefresh:
            return true
        case .appearance, .foreground:
            return !isFresh
        }
    }
}
