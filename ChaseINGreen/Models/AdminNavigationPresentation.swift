import Foundation

enum AdminNavigationPresentation {
    static func money(_ value: Double?, currency: String? = "USD") -> String {
        guard let value, value.isFinite else { return "Unavailable" }
        guard let currency, currency.count == 3 else { return value.formatted(.number.precision(.fractionLength(2))) + " · currency unknown" }
        return value.formatted(.currency(code: currency))
    }
    static func quantity(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "Unavailable" }
        return value.formatted(.number.precision(.fractionLength(0...8)))
    }
    static func time(_ raw: String?) -> String {
        guard let date = OperationsPresentation.date(raw) else { return "Time unavailable" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
    static func account(_ a: OperationsAccount) -> String {
        let provider = a.provider == "ibkr" ? "IBKR" : a.provider.capitalized
        let ownership = a.ownership.lowercased() == "business" ? "Business" : a.ownership.lowercased() == "personal" ? "Personal" : "Ownership unknown"
        return "\(provider) \(ownership)" + (a.native_account.map { " · …\($0.suffix(4))" } ?? " · Identity unavailable")
    }
    static func openHoldings(_ a: OperationsAccount) -> [OperationsHolding] {
        a.holdings.filter { $0.quantity.map { $0 != 0 } ?? true }
    }
    static func observationSummary(_ a: OperationsAccount, snapshot: String, now: Date = Date()) -> String {
        guard status(a, snapshot: snapshot, now: now) == "OBSERVING" else {
            return "Last-known positions · current broker truth unavailable · new risk blocked"
        }
        return a.observation_note ?? "Current snapshot · intervening activity unknown · new risk blocked"
    }
    static func positionCount(_ a: OperationsAccount, snapshot: String) -> String {
        let qualifier = status(a, snapshot: snapshot) == "OBSERVING" ? "observed open" : "last-known"
        return "\(openHoldings(a).count) \(qualifier) positions"
    }
    static func status(_ a: OperationsAccount, snapshot: String, now: Date = Date()) -> String {
        if a.status.contains("REAUTH") { return "REAUTH / RECONCILE REQUIRED" }
        guard OperationsPresentation.currentSnapshot(snapshot, now: now) else { return "STALE" }
        return a.status.replacingOccurrences(of: "_", with: " ")
    }
}
