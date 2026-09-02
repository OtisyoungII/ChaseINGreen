import Foundation

struct KnownPnlSummary: Equatable {
    let knownTotal: Double?
    let unavailableCount: Int
}

enum TradePresentationPolicy {
    static func brokerAccountGroupIdentity(
        provider: String,
        connectionID: String?,
        canonicalAccountID: String?,
        accountGroupKey: String?,
        brokerAccountID: String?
    ) -> String {
        let providerKey = provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
