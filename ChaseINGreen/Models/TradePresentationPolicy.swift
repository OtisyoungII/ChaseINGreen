import Foundation

struct KnownPnlSummary: Equatable {
    let knownTotal: Double?
    let unavailableCount: Int
}

enum TradePresentationPolicy {
    // Displaying a last-known broker snapshot does not grant live/action eligibility.
    static func showsPositionSnapshot(provider: String, isOpen: Bool, isLive: Bool,
                                      source: String?, confirmed: Bool?, externalID: String?,
                                      connectionID: String?, accountID: String?, instrumentID: String?) -> Bool {
        guard isOpen else { return false }
        if source == "manual", confirmed != true, externalID == nil { return isOpen }
        if provider != "ibkr" { return isLive || (provider == "kraken" && confirmed == true) }
        // Preserve genuinely manual tracking; server filtering rejects legacy imports.
        if source == "manual", confirmed != true, externalID == nil,
           connectionID == nil, accountID == nil { return isLive }
        guard source == "broker_position_snapshot", confirmed == true,
              let connectionID, !connectionID.isEmpty,
              let accountID, !accountID.isEmpty,
              let instrumentID, !instrumentID.isEmpty,
              let externalID, externalID.hasPrefix("ibkr:\(connectionID):") else { return false }
        return externalID.hasSuffix(":\(instrumentID)")
    }

    static func showsConventionalTradeControls(activitySubtype: String?) -> Bool {
        activitySubtype != "spotHolding"
    }
    static func activityCountLabel(subtypes: [String?]) -> String {
        let count = subtypes.count
        let allSpot = !subtypes.isEmpty && subtypes.allSatisfy { $0 == "spotHolding" }
        if allSpot { return "\(count) \(count == 1 ? "spot holding" : "spot holdings")" }
        return "\(count) \(count == 1 ? "open trade" : "open trades")"
    }

    static func basisLabel(available: Bool, formattedValue: String?) -> String {
        available ? (formattedValue ?? "Cost basis unavailable") : "Cost basis unavailable"
    }

    static func pnlLabel(available: Bool, formattedValue: String?) -> String {
        available ? (formattedValue ?? "P/L unavailable") : "P/L unavailable"
    }

    static func valuationLabel(value: String?, complete: Bool, unpricedCount: Int) -> String {
        guard complete else {
            return "\(value ?? "Priced value unavailable") • \(unpricedCount) asset\(unpricedCount == 1 ? "" : "s") unpriced"
        }
        return value ?? "Portfolio value unavailable"
    }

    static func brokerAccountGroupIdentity(
        provider: String,
        connectionID: String?,
        canonicalAccountID: String?,
        accountGroupKey: String?,
        brokerAccountID: String?
    ) -> String {
        if let canonicalAccountID, let accountID = UUID(uuidString: canonicalAccountID) { return "account|\(accountID.uuidString.lowercased())" }
        let providerKey = provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if providerKey == "ibkr" {
            let account = [canonicalAccountID, brokerAccountID, accountGroupKey]
                .compactMap { $0 }.first { !$0.isEmpty } ?? "ungrouped"
            return "ibkr|\((connectionID ?? "").lowercased())|\(account.lowercased())"
        }
        let identity = [connectionID, canonicalAccountID, accountGroupKey, brokerAccountID]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "ungrouped"
        return "\(providerKey)|\(identity.lowercased())"
    }

    static func summarizePnl(_ values: [Double?]) -> KnownPnlSummary {
        let known = values.compactMap { $0 }
        return KnownPnlSummary(
            knownTotal: known.isEmpty ? nil : known.reduce(0, +),
            unavailableCount: values.count - known.count
        )
    }

    static func uniqueReasoning(_ values: [String?]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            guard let value else { return nil }
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty,
                  seen.insert(clean.lowercased()).inserted else { return nil }
            return clean
        }
    }

    static func compactMoney(_ value: Double) -> String {
        let magnitude = abs(value)
        let sign = value >= 0 ? "+$" : "-$"
        if magnitude >= 1_000_000 {
            return String(format: "%@%.2fM", sign, magnitude / 1_000_000)
        }
        if magnitude >= 1_000 {
            return String(format: "%@%.2fK", sign, magnitude / 1_000)
        }
        return String(format: "%@%.2f", sign, magnitude)
    }
}

struct ManageTradeCapabilities: Equatable {
    let canSetStopLoss: Bool
    let canSetTakeProfit: Bool
    let canUseTrailingStop: Bool
    let canMoveToBreakEven: Bool
    let canPartialClose: Bool
    let canFullClose: Bool
    let canAmendOrder: Bool
    let canCancelOrder: Bool
    let canApplyToRelatedPositions: Bool

    static let aqua = ManageTradeCapabilities(
        canSetStopLoss: true, canSetTakeProfit: true,
        canUseTrailingStop: true, canMoveToBreakEven: true,
        canPartialClose: true, canFullClose: true,
        canAmendOrder: true, canCancelOrder: true,
        canApplyToRelatedPositions: true
    )

    static let krakenPreviewOnly = ManageTradeCapabilities(
        canSetStopLoss: false, canSetTakeProfit: false,
        canUseTrailingStop: false, canMoveToBreakEven: false,
        canPartialClose: false, canFullClose: false,
        canAmendOrder: false, canCancelOrder: false,
        canApplyToRelatedPositions: false
    )

    static let manual = ManageTradeCapabilities(
        canSetStopLoss: false, canSetTakeProfit: false,
        canUseTrailingStop: false, canMoveToBreakEven: false,
        canPartialClose: false, canFullClose: false,
        canAmendOrder: false, canCancelOrder: false,
        canApplyToRelatedPositions: false
    )
}

// Presentation-only policy: never grants broker authorization or changes position eligibility.
enum LaunchAccountingPolicy {
    static func monetaryText(_ amount: Double, currency: String?) -> String {
        if let currency { return amount.formatted(.currency(code: currency)) }
        return amount.formatted(.number.precision(.fractionLength(2)))
    }

    static func ibkrContextAvailable(source: String?, connection: String?, dataState: String?, observedAt: String?) -> Bool {
        source != "manual" && !(connection ?? "").isEmpty
            && ["live", "stale"].contains(dataState ?? "") && !(observedAt ?? "").isEmpty
    }

    static func calendarCacheKey(owner: String, account: String?, scope: String, timezone: String) -> String {
        "\(owner):\(account ?? "all"):\(timezone):\(scope)"
    }

    static func comparableCurrencies(_ currencies: [String?]) -> Bool {
        let known = Set(currencies.compactMap { $0?.uppercased() })
        return !currencies.isEmpty && known.count == 1 && currencies.allSatisfy { $0 != nil }
    }
}
