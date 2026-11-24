import XCTest
@testable import ChaseINGreenAuthorization

final class SubscriptionAccountPresentationTests: XCTestCase {
    func testLoadingAndFailureNeverManufactureFree() {
        var p = SubscriptionAccountPresentation()
        XCTAssertEqual(p.title, "Current Plan: Checking…")
        p.fail()
        XCTAssertEqual(p.title, "Current Plan: Unavailable")
        XCTAssertFalse(p.mayPurchase(contextReady: true, localGold: false))
    }
    func testVerifiedFreeAndPurchaseReadinessAreSeparate() throws {
        var p = SubscriptionAccountPresentation()
        try p.accept(plan: "free", gold: false, admin: false, secret: false, banned: false)
        XCTAssertEqual(p.title, "Current Plan: Free")
        XCTAssertFalse(p.mayPurchase(contextReady: false, localGold: false))
        XCTAssertTrue(p.mayPurchase(contextReady: true, localGold: false))
        XCTAssertFalse(p.mayPurchase(contextReady: true, localGold: true))
    }
    func testMonthlyAndYearlyVerifiedGoldDoNotInviteDuplicatePurchase() throws {
        for _ in AppleSubscriptionContract.productIDs {
            var p = SubscriptionAccountPresentation()
            try p.accept(plan: "gold", gold: true, admin: false, secret: false, banned: false)
            XCTAssertEqual(p.title, "Current Plan: Gold")
            XCTAssertFalse(p.mayPurchase(contextReady: true, localGold: false))
            XCTAssertFalse(p.lastVerified!.internalAccess)
        }
    }
    func testUnavailablePreservesLastVerifiedGoldWithoutGrantingAccess() throws {
        var p = SubscriptionAccountPresentation()
        try p.accept(plan: "gold", gold: true, admin: false, secret: false, banned: false)
        p.begin(); p.fail()
        XCTAssertEqual(p.title, "Last verified: Gold")
        XCTAssertFalse(p.current)
        XCTAssertFalse(p.mayPurchase(contextReady: true, localGold: false))
    }
    func testAuthoritativeExpiryReplacesCachedGold() throws {
        var p = SubscriptionAccountPresentation()
        try p.accept(plan: "gold", gold: true, admin: false, secret: false, banned: false)
        p.begin()
        try p.accept(plan: "free", gold: false, admin: false, secret: false, banned: false)
        XCTAssertEqual(p.title, "Current Plan: Free")
    }
    func testRestoreAndAuthoritativeGoldReplaceCachedFree() throws {
        var p = SubscriptionAccountPresentation()
        try p.accept(plan: "free", gold: false, admin: false, secret: false, banned: false)
        p.begin()
        try p.accept(plan: "gold", gold: true, admin: false, secret: false, banned: false)
        XCTAssertEqual(p.title, "Current Plan: Gold")
    }
    func testInternalAuthorityDoesNotClaimApplePurchase() throws {
        var p = SubscriptionAccountPresentation()
        try p.accept(plan: "admin", gold: true, admin: true, secret: true, banned: false)
        XCTAssertEqual(p.title, "Current Plan: Internal access — Admin")
        XCTAssertTrue(p.explanation.contains("not proof of a paid Apple subscription"))
        XCTAssertFalse(p.mayPurchase(contextReady: true, localGold: false))
        try p.accept(plan: "free", gold: false, admin: false, secret: true, banned: false)
        XCTAssertEqual(p.title, "Current Plan: Internal access — Secret")
        XCTAssertTrue(p.explanation.contains("does not currently grant Gold"))
    }
    func testMissingMalformedAndContradictoryPlanAreExplicitlyUnavailable() {
        for plan: String? in [nil, "", "garbage", "gold"] {
            var p = SubscriptionAccountPresentation()
            XCTAssertThrowsError(try p.accept(plan: plan, gold: false, admin: false, secret: false, banned: false))
            XCTAssertEqual(p.title, "Current Plan: Unavailable")
        }
    }
    func testBannedAccountCannotPurchaseItsWayOut() throws {
        var p = SubscriptionAccountPresentation()
        try p.accept(plan: "gold", gold: true, admin: false, secret: false, banned: true)
        XCTAssertFalse(p.mayPurchase(contextReady: true, localGold: false))
        XCTAssertEqual(p.title, "Current Plan: Account access restricted")
    }
    func testGoldCapabilitiesNeverImplyInternalAuthority() {
        let p = SessionCapabilityProfile(plan: "gold", isGold: true, isSecret: false, isAdmin: false, isBanned: false)
        XCTAssertTrue(p.hasGold)
        XCTAssertFalse(p.canAccessBatCave)
    }
}
