import XCTest
@testable import ChaseINGreenAuthorization

final class ManualExitReviewTests: XCTestCase {
    func testOnlyFreshObservationCanSupplyManualExit() {
        let now = Date()
        let time = ISO8601DateFormatter().string(from: now.addingTimeInterval(-1))
        var v = AcceptedValuation(instrument: "ABTC", price: 7.8, provider: "yahoo", observedAt: time, receivedAt: time, observationKind: "trade")
        XCTAssertEqual(v.manualExitPrice(at: now), 7.8)
        XCTAssertNil(v.manualExitPrice(at: now.addingTimeInterval(121)))
        v.observationKind = "daily_bar"
        XCTAssertNil(v.manualExitPrice(at: now))
        v.observationKind = "trade"
        v.observedAt = nil
        XCTAssertNil(v.manualExitPrice(at: now))
    }
    func testHistoricalConfirmationInvalidatesButPreviewDoesNot() {
        XCTAssertTrue(LedgerTruthPolicy.invalidatesLedger(method: "PATCH", path: "/trades/id/correction"))
        XCTAssertFalse(LedgerTruthPolicy.invalidatesLedger(method: "POST", path: "/trades/id/exit-preview"))
    }
}
