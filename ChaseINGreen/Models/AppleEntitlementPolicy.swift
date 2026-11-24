import Foundation

/// One typed contract shared by the StoreKit coordinator and deterministic tests.
/// These values mirror the authenticated FastAPI `/me` router; they grant no access.
enum AppleSubscriptionContract {
    static let contextPath = "/me/apple-subscription/context"
    static let syncPath = "/me/apple-subscription/sync"
    static let profilePath = "/me"
    static let monthlyProductID = "chaseingreen_gold_monthly"
    static let yearlyProductID = "chaseingreen_gold_yearly"
    static let productIDs = [monthlyProductID, yearlyProductID]

    struct ContextResponse: Decodable, Equatable {
        let app_account_token: UUID
    }

    struct SyncRequest: Encodable, Equatable {
        let signed_transaction: String?
    }

    struct SyncResponse: Decodable, Equatable {
        let success: Bool
        let subscription: SubscriptionStatus

        struct SubscriptionStatus: Decodable, Equatable {
            let status: String
            let environment: String?
        }
    }
}

/// Local StoreKit evidence is purchase UX only. Server capabilities come from `/me`.
enum AppleEntitlementPolicy {
    static func accepts(verified: Bool, revoked: Bool, expiration: Date?,
                        transactionAccount: UUID?, signedInAccount: UUID?, now: Date = Date()) -> Bool {
        guard verified, !revoked, let expiration, expiration > now,
              let signedInAccount, transactionAccount == signedInAccount else { return false }
        return true
    }

    static func showsGold(serverVerified: Bool, serverGold: Bool) -> Bool {
        serverVerified && serverGold
    }
}

/// Invalidates in-flight entitlement work when credentials or account change.
struct EntitlementSessionEpoch {
    private(set) var generation: UInt64 = 0
    mutating func advance() { generation &+= 1 }
    func accepts(_ candidate: UInt64) -> Bool { candidate == generation }
}

/// Prevents repeated taps from creating overlapping StoreKit operations.
struct SubscriptionOperationGate {
    private(set) var operation: String?
    mutating func begin(_ candidate: String) -> Bool {
        guard operation == nil else { return false }
        operation = candidate
        return true
    }
    mutating func finish(_ candidate: String) {
        if operation == candidate { operation = nil }
    }
}

/// Presentation only. Never grants capabilities or infers an Apple purchase from a role.
struct SubscriptionAccountPresentation: Equatable {
    struct Verified: Equatable {
        let plan: String
        let gold: Bool
        let admin: Bool
        let secret: Bool
        let banned: Bool
        var internalAccess: Bool { admin || secret }
        var label: String {
            if banned { return "Account access restricted" }
            if admin { return "Internal access — Admin" }
            if secret { return "Internal access — Secret" }
            return gold ? "Gold" : "Free"
        }
    }
    private(set) var lastVerified: Verified?
    private(set) var current = false
    private(set) var loading = true

    mutating func begin() { loading = true; current = false }
    mutating func fail() { loading = false; current = false }
    mutating func accept(plan: String?, gold: Bool, admin: Bool, secret: Bool, banned: Bool) throws {
        guard let plan = plan?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              ["free", "gold", "premium", "admin", "secret"].contains(plan),
              admin || secret || ((plan == "gold" || plan == "premium") == gold) else {
            fail()
            throw CocoaError(.coderReadCorrupt)
        }
        lastVerified = Verified(plan: plan, gold: gold, admin: admin, secret: secret, banned: banned)
        current = true
        loading = false
    }
    var title: String {
        if current, let lastVerified { return "Current Plan: \(lastVerified.label)" }
        if let lastVerified { return "Last verified: \(lastVerified.label)" }
        return loading ? "Current Plan: Checking…" : "Current Plan: Unavailable"
    }
    var explanation: String {
        guard current, let state = lastVerified else {
            return loading ? "Checking authenticated account access." : "Account verification is unavailable. This is not a verified Free plan."
        }
        if state.banned { return "Contact account support. Purchasing does not remove an account restriction." }
        if state.internalAccess {
            return state.gold ? "Gold-equivalent product access is included through internal authority. This is not proof of a paid Apple subscription."
                : "Internal tools are authorized separately. The server does not currently grant Gold product access."
        }
        return state.gold ? "Gold product access is verified by Chase. Apple billing status is shown separately."
            : "Chase currently grants Free product access. Apple billing verification is shown separately."
    }
    func mayPurchase(contextReady: Bool, localGold: Bool) -> Bool {
        guard current, let state = lastVerified else { return false }
        return contextReady && !localGold && !state.gold && !state.internalAccess && !state.banned
    }
}
