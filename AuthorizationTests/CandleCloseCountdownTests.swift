import XCTest
@testable import ChaseINGreenAuthorization

final class CandleCloseCountdownTests: XCTestCase {
    private func date(_ value: String) -> Date {
        try! XCTUnwrap(CandleCloseCountdown.parseISO8601(value))
    }

    private func remaining(_ timeframe: String, at now: String) -> TimeInterval {
        let now = date(now)
        let close = CandleCloseCountdown.closeDate(
            timeframe: timeframe,
            now: now,
            authoritativeClose: nil,
            usesContinuousUTCBoundaries: true
        )!
        return CandleCloseCountdown.remaining(until: close, now: now)
    }

    func testOneMinuteBoundary() {
        XCTAssertEqual(remaining("1m", at: "2026-10-31T14:42:10Z"), 50)
    }

    func testFiveMinuteBoundary() {
        XCTAssertEqual(remaining("5m", at: "2026-10-31T14:42:10Z"), 170)
    }

    func testFifteenMinuteBoundary() {
        XCTAssertEqual(remaining("15m", at: "2026-10-31T14:42:10Z"), 170)
    }

    func testThirtyMinuteBoundary() {
        XCTAssertEqual(remaining("30m", at: "2026-10-31T14:42:10Z"), 1_070)
    }

    func testNewMinuteBoundaries() {
        XCTAssertEqual(remaining("2m", at: "2026-10-31T14:42:10Z"), 110)
        XCTAssertEqual(remaining("3m", at: "2026-10-31T14:42:10Z"), 170)
        XCTAssertEqual(remaining("45m", at: "2026-10-31T14:42:10Z"), 1_070)
    }

    func testOneHourBoundary() {
        XCTAssertEqual(remaining("1h", at: "2026-10-31T14:42:10Z"), 1_070)
    }

    func testFourHourBoundary() {
        XCTAssertEqual(remaining("4h", at: "2026-10-31T14:42:10Z"), 4_670)
    }

    func testNewHourBoundaries() {
        XCTAssertEqual(remaining("2h", at: "2026-10-31T14:42:10Z"), 4_670)
        XCTAssertEqual(remaining("3h", at: "2026-10-31T14:42:10Z"), 1_070)
    }

    func testDailyBoundary() {
        XCTAssertEqual(remaining("1d", at: "2026-10-31T14:42:10Z"), 33_470)
    }

    func testExactAuthoritativeBoundaryShowsZeroThenRollsForward() {
        let boundary = date("2026-10-31T14:45:00Z")
        XCTAssertEqual(CandleCloseCountdown.remaining(until: boundary, now: boundary), 0)
        XCTAssertEqual(
            remaining("15m", at: "2026-10-31T14:45:01Z"),
            899
        )
    }

    func testRemainingNeverBecomesNegative() {
        XCTAssertEqual(
            CandleCloseCountdown.remaining(
                until: date("2026-10-31T14:44:59Z"),
                now: date("2026-10-31T14:45:01Z")
            ),
            0
        )
    }

    func testFormattingBelowOneHour() {
        XCTAssertEqual(CandleCloseCountdown.formatted(222), "03:42")
    }

    func testFormattingAtOrAboveOneHour() {
        XCTAssertEqual(CandleCloseCountdown.formatted(9_522), "02:38:42")
        XCTAssertEqual(CandleCloseCountdown.formatted(3_600), "01:00:00")
    }

    func testOpeningMidCandleUsesBoundaryInsteadOfFullDuration() {
        XCTAssertEqual(remaining("15m", at: "2026-10-31T14:42:10Z"), 170)
    }

    func testForegroundRecalculationUsesCurrentDate() {
        XCTAssertEqual(remaining("5m", at: "2026-10-31T14:42:10Z"), 170)
        XCTAssertEqual(remaining("5m", at: "2026-10-31T14:44:50Z"), 10)
    }

    func testAuthoritativeCloseWinsOverUTCReconstruction() {
        let now = date("2026-10-31T14:42:10Z")
        let authoritative = date("2026-10-31T14:47:00Z")
        XCTAssertEqual(
            CandleCloseCountdown.closeDate(
                timeframe: "5m",
                now: now,
                authoritativeClose: authoritative,
                usesContinuousUTCBoundaries: true
            ),
            authoritative
        )
    }

    func testSessionInstrumentWithoutAuthoritativeBoundaryIsUnavailable() {
        XCTAssertNil(CandleCloseCountdown.closeDate(
            timeframe: "15m",
            now: date("2026-10-31T14:42:10Z"),
            authoritativeClose: nil,
            usesContinuousUTCBoundaries: false
        ))
    }
}
