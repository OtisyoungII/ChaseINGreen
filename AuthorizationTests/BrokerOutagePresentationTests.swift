import XCTest
@testable import ChaseINGreenAuthorization

final class BrokerOutagePresentationTests: XCTestCase {
    func testRecoveryAndStaleCacheDoNotInventCurrentTruth() throws {
        let raw = #"{"id":"fixture","label":"Personal","provider":"ibkr","ownership":"personal","connection_suffix":"fixture","status":"OBSERVING","connection_status":"persisted","authentication":"UNKNOWN","binding_verified":true,"metrics":[],"asset_balances":[],"risk":[],"holdings":[{"symbol":"TEST","quantity":13,"state":"OBSERVED","protection":"UNKNOWN"}],"orders_status":"UNKNOWN","protection":"UNKNOWN","restrictions":"UNKNOWN","eligibility":"LOCKED","reason":"fixture","observation_note":"Reconciled after 11h 41m gap · intervening activity unknown · new risk blocked"}"#
        let account = try JSONDecoder().decode(OperationsAccount.self, from: Data(raw.utf8))
        let now = Date()
        let stamp = ISO8601DateFormatter().string(from: now)
        XCTAssertTrue(AdminNavigationPresentation.observationSummary(account, snapshot: stamp, now: now).contains("11h 41m"))
        XCTAssertTrue(AdminNavigationPresentation.observationSummary(account, snapshot: "invalid", now: now).contains("truth unavailable"))
        XCTAssertTrue(AdminNavigationPresentation.positionCount(account, snapshot: "invalid").contains("last-known"))
        let reauth = try JSONDecoder().decode(OperationsAccount.self, from: Data(raw.replacingOccurrences(of: "\"status\":\"OBSERVING\"", with: "\"status\":\"REAUTH OR RECONCILE REQUIRED\"").utf8))
        XCTAssertEqual(AdminNavigationPresentation.status(reauth, snapshot: "invalid"), "REAUTH / RECONCILE REQUIRED")
        XCTAssertEqual(account.holdings.first?.quantity, 13)
    }
}
