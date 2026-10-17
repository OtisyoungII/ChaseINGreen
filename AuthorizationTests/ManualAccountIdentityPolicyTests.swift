import XCTest
@testable import ChaseINGreenAuthorization

final class ManualAccountIdentityPolicyTests: XCTestCase {
    func testAddAccountPreservesEveryParentBroker() {
        for broker in ["IBKR", "Kraken", "Aqua", "Coinbase", "Other"] {
            XCTAssertEqual(ManualAccountIdentityPolicy.initialBroker(selected: broker, editing: nil), broker)
        }
        XCTAssertEqual(ManualAccountIdentityPolicy.initialBroker(selected: "Kraken", editing: "IBKR"), "IBKR")
    }

    func testSafeLastFourNormalization() {
        XCTAssertEqual(ManualAccountIdentityPolicy.lastFour(" ab-12 34 "), "1234")
        XCTAssertEqual(ManualAccountIdentityPolicy.lastFour("aBcD"), "ABCD")
        XCTAssertNil(ManualAccountIdentityPolicy.lastFour("12"))
        XCTAssertNil(ManualAccountIdentityPolicy.lastFour(nil))
    }

    func testManualIBKRNeverShowsAgentDiagnostics() {
        XCTAssertFalse(ManualAccountIdentityPolicy.showsConnectionDiagnostics(sourceMode: "manual", connectionMode: nil))
        XCTAssertFalse(ManualAccountIdentityPolicy.showsConnectionDiagnostics(sourceMode: nil, connectionMode: "manual"))
        XCTAssertTrue(ManualAccountIdentityPolicy.showsConnectionDiagnostics(sourceMode: "broker_confirmed", connectionMode: "local_agent"))
        XCTAssertTrue(ManualAccountIdentityPolicy.showsConnectionDiagnostics(sourceMode: "legacy", connectionMode: "legacy_unresolved"))
    }

    func testReadBackMustContainTheExactSavedUUID() throws {
        let savedID = UUID()
        XCTAssertThrowsError(try ManualAccountIdentityPolicy.verifyReadBack(savedID: savedID, listedIDs: []))
        XCTAssertThrowsError(try ManualAccountIdentityPolicy.verifyReadBack(savedID: savedID, listedIDs: [UUID()]))
        XCTAssertNoThrow(try ManualAccountIdentityPolicy.verifyReadBack(savedID: savedID, listedIDs: [UUID(), savedID]))
    }

    func testSaveSucceededRefreshFailedRetainsIdentityAndDistinctMessage() {
        let id = UUID()
        let unsaved = ManualAccountSaveState.unsaved
        let pending = ManualAccountSaveState.savedAwaitingRefresh(id)
        let verified = ManualAccountSaveState.verified(id)
        XCTAssertNil(unsaved.savedID)
        XCTAssertEqual(pending.savedID, id)
        XCTAssertEqual(verified.savedID, id)
        XCTAssertNotEqual(unsaved.failureMessage, pending.failureMessage)
        XCTAssertNotEqual(pending, verified)
    }

    func testCanonicalIdentityGroupsAcrossChangedLegacyLabels() {
        let id = UUID().uuidString
        let a = TradePresentationPolicy.brokerAccountGroupIdentity(provider: "ibkr", connectionID: nil,
            canonicalAccountID: id, accountGroupKey: "ibkr-cash-50", brokerAccountID: nil)
        let b = TradePresentationPolicy.brokerAccountGroupIdentity(provider: "ibkr", connectionID: nil,
            canonicalAccountID: id, accountGroupKey: "ibkr-cash-500", brokerAccountID: nil)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, TradePresentationPolicy.brokerAccountGroupIdentity(provider: "ibkr", connectionID: nil,
            canonicalAccountID: UUID().uuidString, accountGroupKey: "ibkr-cash-500", brokerAccountID: nil))
    }
}
