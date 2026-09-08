import XCTest
@testable import ChaseINGreenAuthorization

final class KrakenConnectionSyncPolicyTests: XCTestCase {
    func testSyncStateIsKeyedByExactConnection() {
        var tracker = KrakenConnectionSyncTracker()
        XCTAssertTrue(tracker.begin(
            connectionID: "personal",
            eligibleConnectionIDs: ["personal", "business"]
        ))
        tracker.complete(connectionID: "personal")
        XCTAssertEqual(tracker.state(for: "personal", hasLastSync: true), .fresh)
        XCTAssertEqual(tracker.state(for: "business", hasLastSync: false), .connected)
    }

    func testPersonalSuccessDoesNotSuppressBusinessSync() {
        var tracker = KrakenConnectionSyncTracker()
        XCTAssertTrue(tracker.begin(
            connectionID: "personal",
            eligibleConnectionIDs: ["personal", "business"]
        ))
        tracker.complete(connectionID: "personal")
        XCTAssertTrue(tracker.begin(
            connectionID: "business",
            eligibleConnectionIDs: ["personal", "business"]
        ))
        XCTAssertEqual(tracker.state(for: "business", hasLastSync: false), .syncing)
    }

    func testRenderLoopCannotRepeatConnectionSync() {
        var tracker = KrakenConnectionSyncTracker()
        XCTAssertTrue(tracker.begin(
            connectionID: "business", eligibleConnectionIDs: ["business"]
        ))
        tracker.complete(connectionID: "business")
        XCTAssertFalse(tracker.begin(
            connectionID: "business", eligibleConnectionIDs: ["business"]
        ))
        XCTAssertTrue(tracker.begin(
            connectionID: "business", eligibleConnectionIDs: ["business"], force: true
        ))
    }

    func testFailureDoesNotModifyOtherConnection() {
        var tracker = KrakenConnectionSyncTracker()
        XCTAssertTrue(tracker.begin(
            connectionID: "business",
            eligibleConnectionIDs: ["personal", "business"]
        ))
        tracker.fail(connectionID: "business")
        XCTAssertEqual(tracker.state(for: "business", hasLastSync: true), .failed)
        XCTAssertEqual(tracker.state(for: "personal", hasLastSync: true), .lastKnown)
    }

    func testIneligibleOrAlreadyInflightConnectionCannotStart() {
        var tracker = KrakenConnectionSyncTracker()
        XCTAssertFalse(tracker.begin(
            connectionID: "legacy", eligibleConnectionIDs: ["personal"]
        ))
        XCTAssertTrue(tracker.begin(
            connectionID: "personal", eligibleConnectionIDs: ["personal"]
        ))
        XCTAssertFalse(tracker.begin(
            connectionID: "personal", eligibleConnectionIDs: ["personal"], force: true
        ))
    }
}
