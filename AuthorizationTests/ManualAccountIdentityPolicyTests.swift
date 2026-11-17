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

final class ManualAccountRemovalPolicyTests: XCTestCase {
    func testOnlyManualRecordsCanExposeRemoval() {
        XCTAssertTrue(ManualAccountIdentityPolicy.canRemove(sourceMode: "manual", lastManualUpdate: nil, connectionID: nil, connectionMode: "manual", status: "active"))
        XCTAssertTrue(ManualAccountIdentityPolicy.canRemove(sourceMode: nil, lastManualUpdate: "2026-08-26", connectionID: nil, connectionMode: "manual", status: "legacy_unresolved"))
        for mode in ["local_agent", "official_trader_api", "api"] {
            XCTAssertFalse(ManualAccountIdentityPolicy.canRemove(sourceMode: "manual", lastManualUpdate: "date", connectionID: "connection", connectionMode: mode, status: "active"))
        }
        XCTAssertFalse(ManualAccountIdentityPolicy.canRemove(sourceMode: "broker_confirmed", lastManualUpdate: "date", connectionID: nil, connectionMode: "manual", status: "active"))
        XCTAssertFalse(ManualAccountIdentityPolicy.canRemove(sourceMode: nil, lastManualUpdate: nil, connectionID: nil, connectionMode: "manual", status: "active"))
        XCTAssertFalse(ManualAccountIdentityPolicy.canRemove(sourceMode: "manual", lastManualUpdate: nil, connectionID: nil, connectionMode: "manual", status: "deleted"))
    }
    func testConfirmationNamesChaseRecordAndPreservesHistory() {
        let message = ManualAccountIdentityPolicy.removalMessage(name: "Cash")
        XCTAssertTrue(message.contains("Cash"))
        XCTAssertTrue(message.contains("Historical records are retained"))
        XCTAssertTrue(message.contains("does not contact a broker"))
        XCTAssertTrue(LedgerTruthPolicy.invalidatesLedger(method: "DELETE", path: "/broker-accounts/id"))
    }
}
