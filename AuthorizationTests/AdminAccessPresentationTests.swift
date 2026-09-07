import XCTest
@testable import ChaseINGreenAuthorization

final class AdminAccessPresentationTests: XCTestCase {
    func testFreeSecretKeepsIndependentBadgesAndAccent() {
        let user = makeUser(plan: "free", isGold: false, isSecret: true)
        XCTAssertEqual(user.adminBadges, [.free, .secret])
        XCTAssertEqual(user.rosterAccent, .secret)
    }

    func testGoldSecretShowsBothBadges() {
        let user = makeUser(plan: "gold", isGold: true, isSecret: true)
        XCTAssertEqual(user.adminBadges, [.gold, .secret])
    }

    func testAdminSecretShowsAuthorityAndPrivateAccess() {
        let user = makeUser(plan: "admin", isGold: true, isSecret: true, isAdmin: true)
        XCTAssertEqual(user.adminBadges, [.admin, .secret])
        XCTAssertEqual(user.rosterAccent, .admin)
    }

    func testAppleMissingEmailUsesAliasThenStableSubject() {
        let aliased = makeUser(
            subject: "apple|000123456789",
            email: nil,
            alias: "Apple Tester"
        )
        XCTAssertEqual(aliased.identityProvider, "apple")
        XCTAssertEqual(aliased.bestAdminIdentity, "Apple Tester")
        XCTAssertTrue(aliased.adminBadges.contains(.apple))

        let anonymous = makeUser(
            subject: "apple|000123456789012345",
            email: nil,
            alias: nil
        )
        XCTAssertEqual(anonymous.bestAdminIdentity, "…456789012345")
    }

    func testTesterBadgeRequiresRealTesterMetadata() {
        XCTAssertFalse(makeUser(isSecret: true).adminBadges.contains(.tester))
        XCTAssertTrue(makeUser(isSecret: false, testerGroup: "beta-a").adminBadges.contains(.tester))
    }

    func testBannedStateIsIndependentAndHighestRowAccent() {
        let user = makeUser(plan: "gold", isGold: true, isSecret: true, isBanned: true)
        XCTAssertEqual(user.adminBadges, [.gold, .secret, .banned])
        XCTAssertEqual(user.rosterAccent, .banned)
    }

    private func makeUser(
        subject: String = "auth0|tester",
        email: String? = "tester@example.com",
        alias: String? = nil,
        plan: String = "free",
        isGold: Bool = false,
        isSecret: Bool = false,
        isAdmin: Bool = false,
        isBanned: Bool = false,
        testerGroup: String? = nil
    ) -> AdminUserResponse {
        AdminUserResponse(
            id: UUID(), auth0UserId: subject, email: email, alias: alias,
            plan: plan, isPremium: isGold, isGold: isGold,
            isSecret: isSecret, isAdmin: isAdmin,
            adminPlanOverride: nil, appleSubscriptionActive: false,
            appleSubscriptionProductId: nil, appleSubscriptionExpiresAt: nil,
            testerGroup: testerGroup, appVersionLabel: nil, notes: nil,
            isBanned: isBanned, createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z"
        )
    }
}
