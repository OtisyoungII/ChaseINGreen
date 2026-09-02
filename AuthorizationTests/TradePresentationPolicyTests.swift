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

    func testSameConnectionDoesNotSplitWhenAccountMetadataVaries() {
        let first = TradePresentationPolicy.brokerAccountGroupIdentity(
            provider: "kraken", connectionID: "connection-1",
            canonicalAccountID: "BTC-wallet", accountGroupKey: nil,
            brokerAccountID: nil
        )
        let second = TradePresentationPolicy.brokerAccountGroupIdentity(
            provider: "Kraken", connectionID: "connection-1",
            canonicalAccountID: "ETH-wallet", accountGroupKey: nil,
            brokerAccountID: nil
        )
        XCTAssertEqual(first, second)
    }

    func testDifferentConnectionsNeverCollapseBecauseNamesMatch() {
        let first = TradePresentationPolicy.brokerAccountGroupIdentity(
            provider: "kraken", connectionID: "connection-1",
            canonicalAccountID: nil, accountGroupKey: "Otis Personal",
            brokerAccountID: nil
        )
        let second = TradePresentationPolicy.brokerAccountGroupIdentity(
            provider: "kraken", connectionID: "connection-2",
            canonicalAccountID: nil, accountGroupKey: "Otis Personal",
            brokerAccountID: nil
        )
        XCTAssertNotEqual(first, second)
    }

    func testKrakenManagementCapabilitiesCannotExecute() {
        let capabilities = ManageTradeCapabilities.krakenPreviewOnly
        XCTAssertFalse(capabilities.canSetStopLoss)
        XCTAssertFalse(capabilities.canSetTakeProfit)
        XCTAssertFalse(capabilities.canUseTrailingStop)
        XCTAssertFalse(capabilities.canPartialClose)
        XCTAssertFalse(capabilities.canFullClose)
        XCTAssertFalse(capabilities.canAmendOrder)
        XCTAssertFalse(capabilities.canCancelOrder)
    }

    func testCommonCapabilitiesPreserveAquaManagement() {
        let capabilities = ManageTradeCapabilities.aqua
        XCTAssertTrue(capabilities.canSetStopLoss)
        XCTAssertTrue(capabilities.canSetTakeProfit)
        XCTAssertTrue(capabilities.canUseTrailingStop)
        XCTAssertTrue(capabilities.canMoveToBreakEven)
        XCTAssertTrue(capabilities.canPartialClose)
        XCTAssertTrue(capabilities.canFullClose)
        XCTAssertTrue(capabilities.canApplyToRelatedPositions)
    }
}
