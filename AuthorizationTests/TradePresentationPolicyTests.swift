import XCTest
@testable import ChaseINGreenAuthorization

final class TradePresentationPolicyTests: XCTestCase {
    func testKnownPnlRemainsVisibleAlongsideUnavailablePositions() {
        let result = TradePresentationPolicy.summarizePnl([125.50, nil, -25.25, nil])
        XCTAssertEqual(result.knownTotal, 100.25)
        XCTAssertEqual(result.unavailableCount, 2)
    }

    func testAllUnknownPnlDoesNotBecomeZero() {
        let result = TradePresentationPolicy.summarizePnl([nil, nil])
        XCTAssertNil(result.knownTotal)
        XCTAssertEqual(result.unavailableCount, 2)
    }

    func testOpportunityReasoningKeepsDistinctItemsAndRemovesTrueDuplicates() {
        XCTAssertEqual(
            TradePresentationPolicy.uniqueReasoning([
                "Entry zone reached",
                "Momentum confirmation pending",
                "entry zone reached",
                "Reduce size near resistance",
            ]),
            [
                "Entry zone reached",
                "Momentum confirmation pending",
                "Reduce size near resistance",
            ]
        )
    }

    func testCompactMoneyPreservesNegativeSign() {
        XCTAssertEqual(TradePresentationPolicy.compactMoney(1_234), "+$1.23K")
        XCTAssertEqual(TradePresentationPolicy.compactMoney(-1_234_567), "-$1.23M")
    }
}
