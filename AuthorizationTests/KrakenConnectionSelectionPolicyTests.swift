import XCTest
@testable import ChaseINGreenAuthorization

final class KrakenConnectionSelectionPolicyTests: XCTestCase {
    func testStaleLegacySelectionIsRejectedWhenMultipleConnectionsAreEligible() {
        let result = KrakenConnectionSelectionPolicy.resolve(
            eligibleConnectionIDs: ["personal", "business"],
            requestedConnectionID: "legacy",
            storedConnectionID: "legacy"
        )
        XCTAssertNil(result.selectedConnectionID)
        XCTAssertTrue(result.requestedSelectionRejected)
        XCTAssertTrue(result.storedSelectionRejected)
    }

    func testExactEligibleSelectionPersistsWithoutAliasResolution() {
        let result = KrakenConnectionSelectionPolicy.resolve(
            eligibleConnectionIDs: ["personal", "business"],
            requestedConnectionID: "business",
            storedConnectionID: "personal"
        )
        XCTAssertEqual(result.selectedConnectionID, "business")
        XCTAssertFalse(result.requestedSelectionRejected)
    }

    func testSingleEligibleConnectionCanResolveSafely() {
        let result = KrakenConnectionSelectionPolicy.resolve(
            eligibleConnectionIDs: ["personal"],
            requestedConnectionID: nil,
            storedConnectionID: "legacy"
        )
        XCTAssertEqual(result.selectedConnectionID, "personal")
        XCTAssertTrue(result.storedSelectionRejected)
    }

    func testStaleUUIDCannotBecomeTraderOSAccountContext() {
        XCTAssertNil(KrakenConnectionSelectionPolicy.accountSpecificContextID(
            eligibleConnectionIDs: ["personal", "business"],
            selectedConnectionID: "legacy",
            rosterValidated: true
        ))
    }

    func testUnvalidatedUUIDCannotBecomeTraderOSAccountContext() {
        XCTAssertNil(KrakenConnectionSelectionPolicy.accountSpecificContextID(
            eligibleConnectionIDs: ["personal"],
            selectedConnectionID: "personal",
            rosterValidated: false
        ))
    }

    func testExactCurrentUUIDCanBecomeTraderOSAccountContext() {
        XCTAssertEqual(KrakenConnectionSelectionPolicy.accountSpecificContextID(
            eligibleConnectionIDs: ["personal", "business"],
            selectedConnectionID: "business",
            rosterValidated: true
        ), "business")
    }
}
