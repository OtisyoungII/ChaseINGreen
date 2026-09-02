import Foundation

@MainActor
final class TradeHomeLifecycleOwnership {
    static let shared = TradeHomeLifecycleOwnership()

    enum Kind: Hashable {
        case quote
        case analysis
    }

    private var owners: [Kind: UUID] = [:]

    private init() {}

    func claim(_ kind: Kind, token: UUID) {
        owners[kind] = token
    }

    func owns(_ kind: Kind, token: UUID) -> Bool {
        owners[kind] == token
    }

    func release(_ kind: Kind, token: UUID) {
        guard owners[kind] == token else { return }
        owners[kind] = nil
    }
}

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
