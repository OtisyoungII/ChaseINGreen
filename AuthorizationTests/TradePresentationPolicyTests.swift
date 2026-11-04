import XCTest
@testable import ChaseINGreenAuthorization

final class TradePresentationPolicyTests: XCTestCase {
    func testCurrentHoldingValueDoesNotRequireBasisAndExpiresIndependently() {
        let now = Date(timeIntervalSince1970: 1_800_000_010)
        let timestamp = ISO8601DateFormatter().string(from: now.addingTimeInterval(-1))
        let valuation = AcceptedValuation(instrument: "ETH-USD", price: 100, provider: "kraken",
            observedAt: timestamp, receivedAt: timestamp, netPnl: 5)
        let unknownBasis = TradePresentationPolicy.currentHoldingEconomics(isLive: true,
            quantity: 0.5, basisKnown: false, valuation: valuation, now: now)
        XCTAssertEqual(unknownBasis.price, 100)
        XCTAssertEqual(unknownBasis.marketValue, 50)
        XCTAssertNil(unknownBasis.pnl)
        let expired = TradePresentationPolicy.currentHoldingEconomics(isLive: true,
            quantity: 0.5, basisKnown: true, valuation: valuation, now: now.addingTimeInterval(121))
        XCTAssertNil(expired.price)
        XCTAssertNil(expired.marketValue)
        XCTAssertNil(expired.pnl)
    }

    func testHoldingVisibilityAndEconomicsAreIndependent() {
        for live in [true, false] {
            for fresh in [true, false] {
                XCTAssertTrue(TradePresentationPolicy.showsPositionSnapshot(provider: "kraken", isOpen: true,
                    isLive: live, source: "broker_history", confirmed: true,
                    externalID: "kraken-holding:business:BTC", connectionID: "business",
                    accountID: "business-account", instrumentID: "BTCUSD"))
                XCTAssertEqual(TradePresentationPolicy.currentBrokerEconomicsAvailable(
                    isLive: live, valuationIsFresh: fresh), live && fresh)
                let group = TradePresentationPolicy.summarizePnl([nil, nil, nil, nil])
                XCTAssertNil(group.knownTotal)
                XCTAssertEqual(group.unavailableCount, 4)
            }
        }
        XCTAssertFalse(TradePresentationPolicy.showsPositionSnapshot(provider: "kraken", isOpen: false,
            isLive: false, source: "broker_history", confirmed: true, externalID: "old",
            connectionID: "personal", accountID: "old-account", instrumentID: "BTCUSD"))
    }

    func testLastKnownSnapshotCanDisplayWithoutCurrentEconomics() {
        XCTAssertTrue(TradePresentationPolicy.showsPositionSnapshot(provider: "kraken", isOpen: true,
            isLive: false, source: "broker_history", confirmed: true, externalID: "holding",
            connectionID: "test", accountID: "account", instrumentID: "BTCUSD"))
        XCTAssertFalse(TradePresentationPolicy.contributesCurrentPnl(isManual: false, isLive: false, valuationIsFresh: true))
        XCTAssertFalse(TradePresentationPolicy.contributesCurrentPnl(isManual: false, isLive: true, valuationIsFresh: false))
        XCTAssertTrue(TradePresentationPolicy.contributesCurrentPnl(isManual: false, isLive: true, valuationIsFresh: true))
        XCTAssertTrue(TradePresentationPolicy.contributesCurrentPnl(isManual: true, isLive: true, valuationIsFresh: false))
    }

    func testSnapshotExpiresWithoutRefreshOrRestart() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let received = ISO8601DateFormatter().string(from: now)
        XCTAssertTrue(TradePresentationPolicy.currentSnapshotFresh(serverFresh: true, receivedAt: received, maxAge: 900, now: now))
        XCTAssertFalse(TradePresentationPolicy.currentSnapshotFresh(serverFresh: true, receivedAt: received, maxAge: 900, now: now.addingTimeInterval(901)))
        XCTAssertFalse(TradePresentationPolicy.currentSnapshotFresh(serverFresh: false, receivedAt: received, maxAge: 900, now: now))
    }
    func testSpotHoldingsAreNotCalledOpenTrades() {
        XCTAssertEqual(
            TradePresentationPolicy.activityCountLabel(
                subtypes: ["spotHolding", "spotHolding"]
            ),
            "2 spot holdings"
        )
    }

    func testSpotHoldingSuppressesConventionalTradeControls() {
        XCTAssertFalse(
            TradePresentationPolicy.showsConventionalTradeControls(
                activitySubtype: "spotHolding"
            )
        )
        XCTAssertTrue(
            TradePresentationPolicy.showsConventionalTradeControls(
                activitySubtype: "marginPosition"
            )
        )
    }

    func testUnknownBasisAndPnlNeverBecomeZero() {
        XCTAssertEqual(
            TradePresentationPolicy.basisLabel(available: false, formattedValue: "$0.00"),
            "Cost basis unavailable"
        )
        XCTAssertEqual(
            TradePresentationPolicy.pnlLabel(available: false, formattedValue: "$0.00"),
            "P/L unavailable"
        )
    }

    func testPartialValuationNamesUnpricedAssets() {
        XCTAssertEqual(
            TradePresentationPolicy.valuationLabel(
                value: "$104.85", complete: false, unpricedCount: 1
            ),
            "$104.85 • 1 asset unpriced"
        )
    }

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

extension TradePresentationPolicyTests {
    func testIBKRAccountsBehindSameConnectionRemainSeparate() {
        let first = TradePresentationPolicy.brokerAccountGroupIdentity(provider: "ibkr",
            connectionID: "mac", canonicalAccountID: "account-a", accountGroupKey: nil, brokerAccountID: "native-a")
        let second = TradePresentationPolicy.brokerAccountGroupIdentity(provider: "ibkr",
            connectionID: "mac", canonicalAccountID: "account-b", accountGroupKey: nil, brokerAccountID: "native-b")
        XCTAssertNotEqual(first, second)
    }

    func testStaleIBKRSnapshotRemainsDisplayableWithoutBeingLive() {
        XCTAssertTrue(TradePresentationPolicy.showsPositionSnapshot(provider: "ibkr", isOpen: true,
            isLive: false, source: "broker_position_snapshot", confirmed: true,
            externalID: "ibkr:mac:account:123", connectionID: "mac", accountID: "account", instrumentID: "123"))
    }

    func testLegacyAndClosedIBKRRowsAreNotResurrected() {
        XCTAssertFalse(TradePresentationPolicy.showsPositionSnapshot(provider: "ibkr", isOpen: true,
            isLive: false, source: "legacy", confirmed: false,
            externalID: nil, connectionID: nil, accountID: "legacy", instrumentID: nil))
        XCTAssertFalse(TradePresentationPolicy.showsPositionSnapshot(provider: "ibkr", isOpen: false,
            isLive: false, source: "broker_position_snapshot", confirmed: true,
            externalID: "ibkr:mac:account:123", connectionID: "mac", accountID: "account", instrumentID: "123"))
    }

    func testStaleAquaRemainsExcludedAndManualUsersStillWork() {
        XCTAssertFalse(TradePresentationPolicy.showsPositionSnapshot(provider: "match_trader", isOpen: true,
            isLive: false, source: "broker_history", confirmed: true,
            externalID: "old", connectionID: nil, accountID: nil, instrumentID: nil))
        XCTAssertTrue(TradePresentationPolicy.showsPositionSnapshot(provider: "manual", isOpen: true,
            isLive: true, source: "manual", confirmed: false,
            externalID: nil, connectionID: nil, accountID: nil, instrumentID: nil))
    }
}


extension TradePresentationPolicyTests {
    func testGenuinelyManualIBKRTrackingStillDisplaysWithoutConnection() {
        XCTAssertTrue(TradePresentationPolicy.showsPositionSnapshot(provider: "ibkr", isOpen: true,
            isLive: true, source: "manual", confirmed: false,
            externalID: nil, connectionID: nil, accountID: nil, instrumentID: nil))
    }
}
