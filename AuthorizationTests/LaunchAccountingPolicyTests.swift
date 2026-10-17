import XCTest
@testable import ChaseINGreenAuthorization

final class LaunchAccountingPolicyTests: XCTestCase {
    func testManualIBKRIsNotPrivateMarketDataEvenWithStaleMetadata() {
        XCTAssertFalse(LaunchAccountingPolicy.ibkrContextAvailable(source: "manual", connection: "synthetic", dataState: "live", observedAt: "2026-10-12"))
    }
    func testBrokerSnapshotAvailabilityAndMissingEvidence() {
        for state in ["live", "stale"] {
            XCTAssertTrue(LaunchAccountingPolicy.ibkrContextAvailable(source: "broker_confirmed", connection: "synthetic", dataState: state, observedAt: "2026-10-12"))
        }
        XCTAssertFalse(LaunchAccountingPolicy.ibkrContextAvailable(source: nil, connection: nil, dataState: "live", observedAt: "2026-10-12"))
        XCTAssertFalse(LaunchAccountingPolicy.ibkrContextAvailable(source: "broker_confirmed", connection: "synthetic", dataState: "never_synchronized", observedAt: nil))
    }
    func testCalendarTimezoneIsPartOfDayAndMonthCacheIdentity() {
        for scope in ["2026-10-11", "month:2026-10", "all"] {
            let utc = LaunchAccountingPolicy.calendarCacheKey(owner: "owner", account: "a", scope: scope, timezone: "UTC")
            let detroit = LaunchAccountingPolicy.calendarCacheKey(owner: "owner", account: "a", scope: scope, timezone: "America/Detroit")
            XCTAssertNotEqual(utc, detroit)
            XCTAssertNotEqual(utc, LaunchAccountingPolicy.calendarCacheKey(owner: "other", account: "a", scope: scope, timezone: "UTC"))
        }
    }
    func testMixedOrUnknownCurrencyDoesNotBecomeOneTotal() {
        XCTAssertTrue(LaunchAccountingPolicy.comparableCurrencies(["USD", "usd"]))
        XCTAssertFalse(LaunchAccountingPolicy.comparableCurrencies(["USD", "EUR"]))
        XCTAssertFalse(LaunchAccountingPolicy.comparableCurrencies(["USD", nil]))
        XCTAssertFalse(LaunchAccountingPolicy.comparableCurrencies([]))
    }
}
