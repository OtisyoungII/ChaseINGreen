import Foundation

extension Notification.Name {
    static let ledgerTruthDidChange = Notification.Name("ledgerTruthDidChange")
}

@MainActor
enum LedgerTruthRevision {
    private(set) static var current = UUID()
    static func advance() { current = UUID() }
}

struct LedgerRequestGeneration {
    private(set) var current = UUID()
    mutating func begin() -> UUID { current = UUID(); return current }
    func accepts(_ request: UUID) -> Bool { current == request }
}

enum LedgerTruthPolicy {
    static func invalidatesLedger(method: String, path: String) -> Bool {
        let route = path.split(separator: "?", maxSplits: 1).first.map(String.init) ?? path
        return ["POST", "PATCH", "PUT", "DELETE"].contains(method.uppercased())
            && (route == "/trades" || route.hasPrefix("/trades/")
                || route == "/broker-accounts" || route.hasPrefix("/broker-accounts/"))
            && route != "/trades/open/marks"
            && !route.hasSuffix("/exit-preview")
    }

    static func fresh(savedAt: Date, now: Date = Date(), lifetime: TimeInterval = 30) -> Bool {
        let age = now.timeIntervalSince(savedAt)
        return age >= 0 && age < lifetime
    }
    static func activeAccount(isActive: Bool, participation: String?, status: String?) -> Bool {
        let terminal = ["closed", "failed", "breached", "disabled", "inactive", "terminated", "passed", "deleted"]
        return isActive && (participation?.lowercased() ?? "active") == "active"
            && !terminal.contains((status ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}
