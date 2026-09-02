import XCTest
@testable import ChaseINGreenAuthorization

final class TradeHomeRefreshPolicyTests: XCTestCase {
    @MainActor
    func testNewestQuoteViewOwnsLifecycleAfterReconstruction() {
        let first = UUID()
        let replacement = UUID()
        TradeHomeLifecycleOwnership.shared.claim(.quote, token: first)
        TradeHomeLifecycleOwnership.shared.claim(.quote, token: replacement)
        XCTAssertFalse(TradeHomeLifecycleOwnership.shared.owns(.quote, token: first))
        XCTAssertTrue(TradeHomeLifecycleOwnership.shared.owns(.quote, token: replacement))
        TradeHomeLifecycleOwnership.shared.release(.quote, token: replacement)
    }

    @MainActor
    func testQuoteAndAnalysisHaveIndependentSingleOwners() {
        let quote = UUID()
        let analysis = UUID()
        TradeHomeLifecycleOwnership.shared.claim(.quote, token: quote)
        TradeHomeLifecycleOwnership.shared.claim(.analysis, token: analysis)
        XCTAssertTrue(TradeHomeLifecycleOwnership.shared.owns(.quote, token: quote))
        XCTAssertTrue(TradeHomeLifecycleOwnership.shared.owns(.analysis, token: analysis))
        TradeHomeLifecycleOwnership.shared.release(.quote, token: quote)
        TradeHomeLifecycleOwnership.shared.release(.analysis, token: analysis)
    }

    func testVisibleActiveTradeHomeStartsPolling() {
        XCTAssertTrue(TradeHomeRefreshPolicy.shouldStartPolling(isActive: true, isVisible: true))
    }

    func testReconstructionKeepsSameLogicalOwnerIdentity() {
        XCTAssertEqual(
            TradeHomePollingIdentity(symbol: "BZ=F", isActive: true),
            TradeHomePollingIdentity(symbol: "BZ=F", isActive: true)
        )
    }

    func testRepeatedAppearanceDoesNotChangeLogicalIdentity() {
        let first = TradeHomePollingIdentity(symbol: "BTC-USD", isActive: true)
        let second = TradeHomePollingIdentity(symbol: "BTC-USD", isActive: true)
        XCTAssertEqual(first, second)
    }

    func testBackgroundStopsPresentationPolling() {
        XCTAssertFalse(TradeHomeRefreshPolicy.shouldStartPolling(isActive: false, isVisible: true))
    }

    func testDisappearanceStopsPresentationPolling() {
        XCTAssertFalse(TradeHomeRefreshPolicy.shouldStartPolling(isActive: true, isVisible: false))
    }

    func testSymbolChangeCreatesNewPollingIdentity() {
        XCTAssertNotEqual(
            TradeHomePollingIdentity(symbol: "BTC-USD", isActive: true),
            TradeHomePollingIdentity(symbol: "BZ=F", isActive: true)
        )
    }

    func testIdenticalSymbolDoesNotRestartLogicalOwner() {
        XCTAssertEqual(
            TradeHomePollingIdentity(symbol: "XAUUSD", isActive: true),
            TradeHomePollingIdentity(symbol: "XAUUSD", isActive: true)
        )
    }

    func testQuoteTickNeverRunsFullAnalysis() {
        XCTAssertFalse(TradeHomeRefreshPolicy.shouldRunAnalysis(trigger: .quoteTick, isFresh: false))
    }

    func testFreshAppearanceSkipsAnalysis() {
        XCTAssertFalse(TradeHomeRefreshPolicy.shouldRunAnalysis(trigger: .appearance, isFresh: true))
    }

    func testStaleAppearanceRunsAnalysis() {
        XCTAssertTrue(TradeHomeRefreshPolicy.shouldRunAnalysis(trigger: .appearance, isFresh: false))
    }

    func testFreshForegroundSkipsAnalysis() {
        XCTAssertFalse(TradeHomeRefreshPolicy.shouldRunAnalysis(trigger: .foreground, isFresh: true))
    }

    func testStaleForegroundRunsOneCatchUpAnalysis() {
        XCTAssertTrue(TradeHomeRefreshPolicy.shouldRunAnalysis(trigger: .foreground, isFresh: false))
    }

    func testExplicitRefreshForcesAnalysis() {
        XCTAssertTrue(TradeHomeRefreshPolicy.shouldRunAnalysis(trigger: .explicitRefresh, isFresh: true))
    }

    func testSymbolChangeForcesAnalysis() {
        XCTAssertTrue(TradeHomeRefreshPolicy.shouldRunAnalysis(trigger: .symbolChange, isFresh: true))
    }

    func testFreshnessRequiresSameSymbol() {
        XCTAssertFalse(TradeHomeRefreshPolicy.isFresh(
            lastDate: Date(), lastSymbol: "BTC-USD", symbol: "BZ=F", lifetime: 180
        ))
    }

    func testFreshnessAcceptsCaseInsensitiveSameSymbol() {
        XCTAssertTrue(TradeHomeRefreshPolicy.isFresh(
            lastDate: Date(), lastSymbol: "btc-usd", symbol: "BTC-USD", lifetime: 180
        ))
    }

    func testExpiredAnalysisIsNotFresh() {
        XCTAssertFalse(TradeHomeRefreshPolicy.isFresh(
            lastDate: Date(timeIntervalSinceNow: -181),
            lastSymbol: "BZ=F", symbol: "BZ=F", lifetime: 180
        ))
    }

    func testRecentAnalysisIsFresh() {
        XCTAssertTrue(TradeHomeRefreshPolicy.isFresh(
            lastDate: Date(timeIntervalSinceNow: -30),
            lastSymbol: "BZ=F", symbol: "BZ=F", lifetime: 180
        ))
    }

    func testMissingAnalysisTimestampIsStale() {
        XCTAssertFalse(TradeHomeRefreshPolicy.isFresh(
            lastDate: nil, lastSymbol: "BZ=F", symbol: "BZ=F", lifetime: 180
        ))
    }

    func testReopeningStillProducesOneLogicalOwner() {
        let reopened = TradeHomePollingIdentity(symbol: "BZ=F", isActive: true)
        XCTAssertEqual(Set([reopened, reopened]).count, 1)
    }
}
