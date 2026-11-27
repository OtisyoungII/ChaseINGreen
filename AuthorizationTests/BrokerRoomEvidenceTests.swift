import Foundation
import XCTest
@testable import ChaseINGreenAuthorization

final class BrokerRoomEvidenceTests: XCTestCase {
    func testRefreshPreservesExplicitAccountAndNeverSelectsFirstOfMany() {
        let a = UUID(), b = UUID()
        XCTAssertEqual(BrokerRoomEvidencePolicy.retainedSelection(b, available: [a, b]), b)
        XCTAssertNil(BrokerRoomEvidencePolicy.retainedSelection(nil, available: [a, b]))
        XCTAssertNil(BrokerRoomEvidencePolicy.retainedSelection(UUID(), available: [a, b]))
        XCTAssertEqual(BrokerRoomEvidencePolicy.retainedSelection(nil, available: [a]), a)
        XCTAssertNil(BrokerRoomEvidencePolicy.retainedSelection(a, available: []))
    }
    func testSnapshotFreshFlagCannotOutliveTimestamp() {
        let now = Date(timeIntervalSince1970: 1000)
        let time = ISO8601DateFormatter().string(from: now.addingTimeInterval(-10))
        XCTAssertTrue(BrokerRoomEvidencePolicy.isFresh(observedAt: time, maxAge: 20, providerFresh: true, stale: false, now: now))
        XCTAssertFalse(BrokerRoomEvidencePolicy.isFresh(observedAt: time, maxAge: 5, providerFresh: true, stale: false, now: now))
        XCTAssertFalse(BrokerRoomEvidencePolicy.isFresh(observedAt: time, maxAge: nil, providerFresh: true, stale: false, now: now))
        XCTAssertFalse(BrokerRoomEvidencePolicy.isFresh(observedAt: nil, maxAge: 20, providerFresh: true, stale: false, now: now))
        XCTAssertFalse(BrokerRoomEvidencePolicy.isFresh(observedAt: time, maxAge: 20, providerFresh: true, stale: true, now: now))
        XCTAssertFalse(BrokerRoomEvidencePolicy.isFresh(observedAt: time, maxAge: 20, providerFresh: nil, stale: false, now: now))
        XCTAssertFalse(BrokerRoomEvidencePolicy.isFresh(observedAt: time, maxAge: 20, providerFresh: true, stale: false, now: now.addingTimeInterval(-50)))
    }
    func testManualCapabilityComesFromExplicitSourceNotMissingConnection() {
        XCTAssertTrue(BrokerRoomEvidencePolicy.isManual(sourceMode: "manual", connectionMode: nil))
        XCTAssertTrue(BrokerRoomEvidencePolicy.isManual(sourceMode: nil, connectionMode: "MANUAL"))
        XCTAssertFalse(BrokerRoomEvidencePolicy.isManual(sourceMode: nil, connectionMode: nil))
        XCTAssertFalse(BrokerRoomEvidencePolicy.isManual(sourceMode: "provider", connectionMode: "api"))
    }
}
