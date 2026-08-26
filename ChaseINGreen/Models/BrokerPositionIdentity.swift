import Foundation

/// Stable UI identity for broker-position-scoped operations. Symbols are not
/// identities: the same instrument can exist at multiple providers/accounts.
struct BrokerPositionIdentity: Hashable, Sendable {
    let provider: String
    let accountID: String
    let positionID: String

    init(
        provider: String?,
        accountID: String?,
        positionID: String?,
        fallbackTradeID: String
    ) {
        self.provider = Self.normalized(provider, fallback: "unknown-provider")
        self.accountID = Self.normalized(accountID, fallback: "unknown-account")
        self.positionID = Self.normalized(positionID, fallback: fallbackTradeID)
    }

    var rawValue: String {
        [provider, accountID, positionID].joined(separator: "|")
    }

    private static func normalized(
        _ value: String?,
        fallback: String
    ) -> String {
        let clean = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return clean?.isEmpty == false ? clean! : fallback.lowercased()
    }
}
