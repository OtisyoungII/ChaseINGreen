import XCTest
@testable import ChaseINGreenAuthorization

final class InternalWorkspaceAuthorizationTests: XCTestCase {
    func testSessionCapabilityProfileKeepsGoldAndSecretIndependent() {
        let gold = SessionCapabilityProfile(
            plan: "gold",
            isGold: true,
            isSecret: false,
            isAdmin: false,
            isBanned: false
        )
        XCTAssertTrue(gold.canUseCustomerChartTools)
        XCTAssertFalse(gold.canUseQuantChartWorkbench)
        XCTAssertTrue(gold.hasGold)
        XCTAssertFalse(gold.canAccessBatCave)
        XCTAssertFalse(gold.canUseAdvancedAI)

        let secret = SessionCapabilityProfile(
            plan: "secret",
            isGold: false,
            isSecret: true,
            isAdmin: false,
            isBanned: false
        )
        XCTAssertTrue(secret.canAccessBatCave)
        XCTAssertTrue(secret.canUseAdvancedAI)
    }

    func testCapabilityMatrixPreservesAdminSupersetAndBanOverride() {
        let profiles = [
            "free": SessionCapabilityProfile(plan: "free", isGold: false, isSecret: false, isAdmin: false, isBanned: false),
            "gold": SessionCapabilityProfile(plan: "gold", isGold: true, isSecret: false, isAdmin: false, isBanned: false),
            "secret": SessionCapabilityProfile(plan: "free", isGold: false, isSecret: true, isAdmin: false, isBanned: false),
            "admin": SessionCapabilityProfile(plan: "free", isGold: false, isSecret: false, isAdmin: true, isBanned: false),
            "goldSecret": SessionCapabilityProfile(plan: "gold", isGold: true, isSecret: true, isAdmin: false, isBanned: false),
            "adminSecret": SessionCapabilityProfile(plan: "free", isGold: false, isSecret: true, isAdmin: true, isBanned: false),
            "bannedAdminSecret": SessionCapabilityProfile(plan: "free", isGold: false, isSecret: true, isAdmin: true, isBanned: true)
        ]
        XCTAssertFalse(profiles["free"]!.canUseCustomerChartTools)
        XCTAssertFalse(profiles["bannedAdminSecret"]!.canUseCustomerChartTools)
        XCTAssertFalse(profiles["free"]!.hasGold)
        XCTAssertTrue(profiles["gold"]!.hasGold)
        XCTAssertFalse(profiles["secret"]!.hasGold)
        XCTAssertTrue(profiles["admin"]!.canAccessBatCave)
        XCTAssertTrue(profiles["admin"]!.canUseAdvancedAI)
        XCTAssertTrue(profiles["admin"]!.canUseQuantChartWorkbench)
        XCTAssertTrue(profiles["goldSecret"]!.hasGold)
        XCTAssertTrue(profiles["goldSecret"]!.canAccessBatCave)
        XCTAssertTrue(profiles["adminSecret"]!.canUseQuantChartWorkbench)
        XCTAssertFalse(profiles["bannedAdminSecret"]!.canAccessBatCave)
        XCTAssertFalse(profiles["bannedAdminSecret"]!.canUseAdvancedAI)
        XCTAssertFalse(profiles["bannedAdminSecret"]!.canUseQuantChartWorkbench)
    }
    func testFreeCannotSeeAnyInternalWorkspaceRoute() {
        assertAllRoutesDenied(authorization: authorization())
    }

    func testGoldCannotSeeAnyInternalWorkspaceRoute() {
        assertAllRoutesDenied(authorization: authorization(isGold: true))
    }

    func testGoldDoesNotImplySecret() {
        let gold = authorization(isGold: true)
        XCTAssertTrue(gold.isGold)
        XCTAssertFalse(gold.isSecret)
        XCTAssertFalse(gold.canAccessInternalWorkspace)
    }

    func testSecretExposesOnlyRoutesUsingInternalPolicy() {
        let secret = authorization(isSecret: true)
        for entryPoint in InternalWorkspaceEntryPoint.allCases {
            XCTAssertTrue(
                InternalWorkspaceRoutePolicy.permits(
                    entryPoint,
                    authorization: secret
                )
            )
        }
    }

    func testAdminAuthorizationRemainsIndependent() {
        let admin = authorization(isAdmin: true)
        XCTAssertFalse(admin.isGold)
        XCTAssertFalse(admin.isSecret)
        XCTAssertTrue(admin.canAccessInternalWorkspace)
    }

    func testRevokedSecretAccessDisappears() {
        XCTAssertTrue(authorization(isSecret: true).canAccessInternalWorkspace)
        XCTAssertTrue(
            InternalWorkspaceRoutePolicy.mustReturnToAuthorizedScreen(
                afterRefresh: authorization()
            )
        )
    }

    func testStaleCachedSecretCannotGrantWhileRefreshIsUnknown() {
        XCTAssertFalse(
            InternalWorkspaceRoutePolicy.permits(
                .restoredNavigation,
                authorization: nil
            )
        )
    }

    func testDeepLinkIsDeniedWhenUnauthorized() {
        assertDenied(.deepLink)
    }

    func testNotificationIsDeniedWhenUnauthorized() {
        assertDenied(.notification)
    }

    func testForegroundRefreshDoesNotTemporarilyExposeRoute() {
        XCTAssertFalse(
            InternalWorkspaceRoutePolicy.permits(
                .dashboard,
                authorization: nil
            )
        )
    }

    func testUnauthorizedNavigationReturnsInsteadOfDeadEnding() {
        XCTAssertTrue(
            InternalWorkspaceRoutePolicy.mustReturnToAuthorizedScreen(
                afterRefresh: authorization(isGold: true)
            )
        )
    }

    func testBannedSecretAndAdminAreDenied() {
        XCTAssertFalse(
            authorization(isSecret: true, isAdmin: true, isBanned: true)
                .canAccessInternalWorkspace
        )
    }

    private func assertAllRoutesDenied(
        authorization: InternalWorkspaceAuthorization,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for entryPoint in InternalWorkspaceEntryPoint.allCases {
            XCTAssertFalse(
                InternalWorkspaceRoutePolicy.permits(
                    entryPoint,
                    authorization: authorization
                ),
                "Unexpected access through \(entryPoint)",
                file: file,
                line: line
            )
        }
    }

    private func assertDenied(
        _ entryPoint: InternalWorkspaceEntryPoint,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(
            InternalWorkspaceRoutePolicy.permits(
                entryPoint,
                authorization: authorization()
            ),
            file: file,
            line: line
        )
    }

    private func authorization(
        isGold: Bool = false,
        isSecret: Bool = false,
        isAdmin: Bool = false,
        isBanned: Bool = false
    ) -> InternalWorkspaceAuthorization {
        InternalWorkspaceAuthorization(
            isGold: isGold,
            isSecret: isSecret,
            isAdmin: isAdmin,
            isBanned: isBanned
        )
    }
}
