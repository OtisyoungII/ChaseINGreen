import Foundation

struct RobinhoodTradeProposal: Decodable, Identifiable {
    let id: String
    let proposal_hash: String
    let account_suffix: String
    let symbol: String
    let side: String
    let quantity: String
    let order_type: String
    let requested_price: String?
    let estimated_notional: String
    let estimated_fee: String
    let market_reference: String
    let maximum_capital_at_risk: String?
    let risk_note: String
    let protection: String
    let blockers: [String]
    let state: String
    let market_at: String
    let expires_at: String
    let reasoning: String
    let execution_authorized: Bool
    let can_confirm: Bool
    let broker_order_id: String?

    func permitsConfirmation(at now: Date) -> Bool {
        guard can_confirm, execution_authorized, blockers.isEmpty, state == "previewed",
              let expires = Self.date(expires_at) else { return false }
        return now < expires
    }
    static func date(_ value: String) -> Date? {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
    static func blockerText(_ code: String) -> String {
        switch code {
        case "FIRST_LIVE_TEST_NOT_AUTHORIZED": return "First live test has not been authorized. No order can be sent."
        case "INSUFFICIENT_BUYING_POWER": return "Insufficient Robinhood Crypto buying power. Stock holdings are outside this account view."
        case "INSUFFICIENT_CRYPTO_HOLDINGS_NO_SHORTING": return "Not enough available crypto to sell. Short selling is not supported."
        case "PROPOSAL_EXPIRED", "MARKET_EVIDENCE_STALE", "ACCOUNT_EVIDENCE_STALE": return "Evidence expired. Prepare a fresh review before confirming."
        case "ATTACHED_PROTECTION_UNAVAILABLE": return "Attached entry protection is unavailable in this release."
        case "OPEN_ORDER_REQUIRES_RECONCILIATION": return "An existing broker order requires reconciliation."
        case "ALREADY_SUBMITTED_OR_UNRESOLVED": return "Submission already attempted. Check broker readback; never submit again."
        default: return code.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
