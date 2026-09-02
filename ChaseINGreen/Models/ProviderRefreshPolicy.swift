import Foundation

enum ProviderRefreshScope: Equatable {
    case globalPortfolio
    case provider(String)
    case presentation

    func allows(_ provider: String) -> Bool {
        switch self {
        case .globalPortfolio:
            return true
        case .provider(let selected):
            return ProviderRefreshPolicy.identity(selected)
                == ProviderRefreshPolicy.identity(provider)
        case .presentation:
            return false
        }
    }
}

enum ProviderRefreshDecision: Equatable {
    case start
    case coalesced
    case unrelatedProvider
    case presentationOnly
    case fresh
    case failureCooldown
}

enum ProviderRefreshPolicy {
    static func decision(
        provider: String,
        scope: ProviderRefreshScope,
        isInFlight: Bool,
        lastSuccess: Date?,
        lastFailure: Date?,
        now: Date = Date(),
        maximumAge: TimeInterval,
        failureCooldown: TimeInterval,
        force: Bool
    ) -> ProviderRefreshDecision {
        if case .presentation = scope { return .presentationOnly }
        guard scope.allows(provider) else { return .unrelatedProvider }
        if isInFlight { return .coalesced }
        if force { return .start }
        if let lastSuccess,
           now.timeIntervalSince(lastSuccess) < maximumAge {
            return .fresh
        }
        if let lastFailure,
           now.timeIntervalSince(lastFailure) < failureCooldown {
            return .failureCooldown
        }
        return .start
    }

    static func identity(_ value: String) -> String {
        let compact = value.lowercased().filter(\.isLetter)
        if compact.contains("aqua") || compact.contains("matchtrader") {
            return "aqua"
        }
        if compact.contains("kraken") { return "kraken" }
        if compact == "ibkr" || compact.contains("interactivebrokers") {
            return "ibkr"
        }
        return compact
    }
}
