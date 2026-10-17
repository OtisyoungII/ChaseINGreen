import XCTest
@testable import ChaseINGreenAuthorization

final class LedgerTruthPolicyTests: XCTestCase {
    func testAllLedgerMutationsInvalidateButQuoteRefreshDoesNotLoop() {
        for path in ["/trades", "/trades/id/reduce", "/trades/id/close", "/trades/id/correction", "/trades/id/reopen", "/broker-accounts/manual-sync", "/broker-accounts/id?scope=owned"] {
            XCTAssertTrue(LedgerTruthPolicy.invalidatesLedger(method: "POST", path: path))
            XCTAssertFalse(LedgerTruthPolicy.invalidatesLedger(method: "GET", path: path))
        }
        XCTAssertFalse(LedgerTruthPolicy.invalidatesLedger(method: "POST", path: "/trades/open/marks"))
        XCTAssertFalse(LedgerTruthPolicy.invalidatesLedger(method: "POST", path: "/trade-tools/log"))
    }

    func testManualAccountIsEligibleWithoutConnectionForEveryBrand() {
        for brand in ["ibkr", "kraken", "fidelity", "aqua", "match_trader"] {
            XCTAssertTrue(LedgerTruthPolicy.activeAccount(isActive: true, participation: "active", status: "active"))
            XCTAssertTrue(TradePresentationPolicy.showsPositionSnapshot(provider: brand,
                isOpen: true, isLive: false, source: "manual", confirmed: false,
                externalID: nil, connectionID: nil, accountID: UUID().uuidString, instrumentID: nil))
        }
    }

    func testInactiveIgnoredAndTerminalAccountsStayExcluded() {
        XCTAssertFalse(LedgerTruthPolicy.activeAccount(isActive: false, participation: "active", status: nil))
        XCTAssertFalse(LedgerTruthPolicy.activeAccount(isActive: true, participation: "ignored", status: "active"))
        XCTAssertFalse(LedgerTruthPolicy.activeAccount(isActive: true, participation: "active", status: "closed"))
        XCTAssertFalse(TradePresentationPolicy.showsPositionSnapshot(provider: "ibkr",
            isOpen: false, isLive: true, source: "manual", confirmed: false,
            externalID: nil, connectionID: nil, accountID: "manual", instrumentID: nil))
    }

    func testCanonicalGroupingAndUnpricedValues() {
        let id = UUID().uuidString
        func key(_ provider: String, _ alias: String) -> String {
            TradePresentationPolicy.brokerAccountGroupIdentity(provider: provider, connectionID: nil,
                canonicalAccountID: id, accountGroupKey: alias, brokerAccountID: alias)
        }
        XCTAssertEqual(key("IBKR", "old-alias"), key("manual", "new-alias"))
        let summary = TradePresentationPolicy.summarizePnl([40, nil])
        XCTAssertEqual(summary.knownTotal, 40)
        XCTAssertEqual(summary.unavailableCount, 1)
    }

    func testDayCacheExpiresAndFutureDatesAreNotFresh() {
        let now = Date(timeIntervalSince1970: 1000)
        XCTAssertTrue(LedgerTruthPolicy.fresh(savedAt: now.addingTimeInterval(-29), now: now))
        XCTAssertFalse(LedgerTruthPolicy.fresh(savedAt: now.addingTimeInterval(-30), now: now))
        XCTAssertFalse(LedgerTruthPolicy.fresh(savedAt: now.addingTimeInterval(1), now: now))
    }

    func testRapidSummaryScopeChangesRejectOldCompletion() {
        var generation = LedgerRequestGeneration()
        let month = generation.begin()
        let account = generation.begin()
        let newestMonth = generation.begin()
        XCTAssertFalse(generation.accepts(month))
        XCTAssertFalse(generation.accepts(account))
        XCTAssertTrue(generation.accepts(newestMonth))
    }

    func testMutationRejectsOldCacheRevision() async {
        await MainActor.run {
            let warmedCacheRevision = LedgerTruthRevision.current
            LedgerTruthRevision.advance()
            XCTAssertNotEqual(warmedCacheRevision, LedgerTruthRevision.current)
            let createdTradeRevision = LedgerTruthRevision.current
            LedgerTruthRevision.advance()
            XCTAssertNotEqual(createdTradeRevision, LedgerTruthRevision.current)
        }
    }
}
