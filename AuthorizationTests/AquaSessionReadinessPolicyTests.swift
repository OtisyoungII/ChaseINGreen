import XCTest
@testable import ChaseINGreenAuthorization

final class AquaSessionReadinessPolicyTests: XCTestCase {
    func testRefreshRequiredRosterIsVisibleButNotExecutable() {
        XCTAssertFalse(AquaSessionReadinessPolicy.isReady(
            hasConnection: true,
            connected: true,
            authenticated: false,
            savedRosterAvailable: true,
            status: "refresh_required",
            refreshExpired: false
        ))
    }

    func testAuthenticatedConnectedSessionIsReady() {
        XCTAssertTrue(AquaSessionReadinessPolicy.isReady(
            hasConnection: true,
            connected: true,
            authenticated: true,
            savedRosterAvailable: true,
            status: "connected",
            refreshExpired: false
        ))
    }

    func testReconnectRequiredIsNeverReady() {
        XCTAssertFalse(AquaSessionReadinessPolicy.isReady(
            hasConnection: true,
            connected: true,
            authenticated: true,
            savedRosterAvailable: true,
            status: "reconnect_required",
            refreshExpired: false
        ))
    }

    func testNoUsablePersistedConnectionIsNotReady() {
        XCTAssertFalse(AquaSessionReadinessPolicy.isReady(
            hasConnection: false,
            connected: true,
            authenticated: true,
            savedRosterAvailable: true,
            status: "connected",
            refreshExpired: false
        ))
    }

    func testExplicitUnauthenticatedWithoutRecoverableRosterIsNotReady() {
        XCTAssertFalse(AquaSessionReadinessPolicy.isReady(
            hasConnection: true,
            connected: true,
            authenticated: false,
            savedRosterAvailable: false,
            status: "refresh_required",
            refreshExpired: false
        ))
    }
}
