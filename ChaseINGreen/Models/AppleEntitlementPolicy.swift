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
