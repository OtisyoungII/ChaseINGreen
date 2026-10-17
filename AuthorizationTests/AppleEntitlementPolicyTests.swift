import XCTest
@testable import ChaseINGreenAuthorization

final class AppleEntitlementPolicyTests: XCTestCase {
    private let owner = UUID()
    private func accepts(verified: Bool = true, revoked: Bool = false,
                         expiration: Date? = Date().addingTimeInterval(3600), account: UUID?) -> Bool {
        AppleEntitlementPolicy.accepts(verified: verified, revoked: revoked, expiration: expiration,
                                      transactionAccount: account, signedInAccount: owner)
    }
    func testVerifiedBoundPurchaseAndRestore() { XCTAssertTrue(accepts(account: owner)) }
    func testAccountSwitchCannotInheritPurchase() { XCTAssertFalse(accepts(account: UUID())) }
    func testLegacyUnboundRestoreCannotGrant() { XCTAssertFalse(accepts(account: nil)) }
    func testUnverifiedCancelledPendingDoNotGrant() {
        XCTAssertFalse(accepts(verified: false, account: owner))
        XCTAssertFalse(accepts(expiration: nil, account: owner))
    }
    func testExpiredAndRevokedDoNotGrant() {
        XCTAssertFalse(accepts(revoked: true, account: owner))
        XCTAssertFalse(accepts(expiration: .distantPast, account: owner))
    }
    func testLogoutAndAccountChangeRejectInFlightResults() {
        var epoch = EntitlementSessionEpoch()
        let goldUserRequest = epoch.generation
        epoch.advance() // logout
        XCTAssertFalse(epoch.accepts(goldUserRequest))
        epoch.advance() // Free user login
        XCTAssertFalse(epoch.accepts(goldUserRequest))
        XCTAssertTrue(epoch.accepts(epoch.generation))
    }
    func testCachedGoldCannotReplaceServerVerification() {
        XCTAssertFalse(AppleEntitlementPolicy.showsGold(serverVerified: false, serverGold: true))
        XCTAssertFalse(AppleEntitlementPolicy.showsGold(serverVerified: true, serverGold: false))
        XCTAssertTrue(AppleEntitlementPolicy.showsGold(serverVerified: true, serverGold: true))
    }
    func testSubscriptionOperationsCannotOverlap() {
        var gate = SubscriptionOperationGate()
        XCTAssertTrue(gate.begin("purchase"))
        XCTAssertFalse(gate.begin("purchase"))
        XCTAssertFalse(gate.begin("restore"))
        gate.finish("restore")
        XCTAssertFalse(gate.begin("restore"))
        gate.finish("purchase")
        XCTAssertTrue(gate.begin("restore"))
    }

    func testBuild13SubscriptionContractMatchesBackendRoutesAndApprovedProducts() throws {
        XCTAssertEqual(AppleSubscriptionContract.contextPath, "/me/apple-subscription/context")
        XCTAssertEqual(AppleSubscriptionContract.syncPath, "/me/apple-subscription/sync")
        XCTAssertEqual(AppleSubscriptionContract.profilePath, "/me")
        XCTAssertEqual(AppleSubscriptionContract.productIDs, [
            "chaseingreen_gold_monthly", "chaseingreen_gold_yearly"
        ])
        let token = UUID()
        let context = try JSONDecoder().decode(
            AppleSubscriptionContract.ContextResponse.self,
            from: Data("{\"app_account_token\":\"\(token.uuidString)\"}".utf8)
        )
        XCTAssertEqual(context.app_account_token, token)
        let sync = try JSONDecoder().decode(
            AppleSubscriptionContract.SyncResponse.self,
            from: Data("{\"success\":true,\"subscription\":{\"status\":\"active\",\"environment\":\"Production\"}}".utf8)
        )
        XCTAssertTrue(sync.success)
        XCTAssertEqual(sync.subscription.status, "active")
    }

    func testSyncRequestContainsOnlySignedTransactionEvidence() throws {
        let data = try JSONEncoder().encode(
            AppleSubscriptionContract.SyncRequest(signed_transaction: "signed-evidence")
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object.keys.sorted(), ["signed_transaction"])
        XCTAssertEqual(object["signed_transaction"] as? String, "signed-evidence")
    }
}
