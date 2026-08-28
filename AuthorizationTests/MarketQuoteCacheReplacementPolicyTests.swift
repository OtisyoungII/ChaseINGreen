import XCTest
@testable import ChaseINGreenAuthorization

final class MarketQuoteCacheReplacementPolicyTests: XCTestCase {
    private let older = Date(timeIntervalSince1970: 100)
    private let newer = Date(timeIntervalSince1970: 200)

    func testCachedBitcoinSurvivesUnavailableRefresh() {
        XCTAssertEqual(decision(existing: 64_000, incoming: nil), .retainExistingUnavailable)
    }

    func testUnavailableBitcoinWithoutCachedPriceRemainsUnavailable() {
        XCTAssertEqual(decision(existing: nil, incoming: nil), .acceptIncoming)
    }

    func testCachedEquitySurvivesUnavailableRefresh() {
        XCTAssertEqual(decision(existing: 220, incoming: nil), .retainExistingUnavailable)
    }

    func testCachedFutureSurvivesUnavailableRefresh() {
        XCTAssertEqual(decision(existing: 5_200, incoming: nil), .retainExistingUnavailable)
    }

    func testOlderIncomingQuoteCannotReplaceNewerCache() {
        XCTAssertEqual(
            MarketQuoteCacheReplacementPolicy.decision(
                existingPrice: 102,
                existingObservedAt: newer,
                incomingPrice: 101,
                incomingObservedAt: older
            ),
            .retainExistingNewer
        )
    }

    func testNewerValidQuoteReplacesOlderCache() {
        XCTAssertEqual(
            MarketQuoteCacheReplacementPolicy.decision(
                existingPrice: 101,
                existingObservedAt: older,
                incomingPrice: 102,
                incomingObservedAt: newer
            ),
            .acceptIncoming
        )
    }

    func testWatchlistConsumerRetainsValidRowOnUnavailableRefresh() {
        XCTAssertEqual(decision(existing: 64_000, incoming: nil), .retainExistingUnavailable)
    }

    func testLiveMarketConsumerRetainsValidPriceOnUnavailableRefresh() {
        XCTAssertEqual(decision(existing: 220, incoming: nil), .retainExistingUnavailable)
    }

    func testMarketDetailConsumerRetainsValidPriceOnUnavailableRefresh() {
        XCTAssertEqual(decision(existing: 5_200, incoming: nil), .retainExistingUnavailable)
    }

    private func decision(
        existing: Double?,
        incoming: Double?
    ) -> MarketQuoteCacheReplacementDecision {
        MarketQuoteCacheReplacementPolicy.decision(
            existingPrice: existing,
            existingObservedAt: older,
            incomingPrice: incoming,
            incomingObservedAt: newer
        )
    }
}
