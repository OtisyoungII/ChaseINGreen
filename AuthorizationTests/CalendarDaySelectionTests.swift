import XCTest
@testable import ChaseINGreenAuthorization

final class CalendarDaySelectionTests: XCTestCase {
    func testLoadedAndCachedDayBothPresentAfterClosing() {
        var selection = CalendarDaySelection<[String]>()
        let first = selection.begin("2026-09-30")
        selection.complete(["manual trade", "broker fill"], request: first)
        XCTAssertEqual(selection.date, "2026-09-30")
        XCTAssertEqual(selection.detail?.count, 2)
        let cached = selection.detail!
        selection.clear()
        let reopened = selection.begin("2026-09-30")
        selection.complete(cached, request: reopened)
        XCTAssertEqual(selection.detail, cached)
    }

    func testEmptyDayHasPresentationIdentity() {
        var selection = CalendarDaySelection<[String]>()
        let request = selection.begin("2026-09-29")
        selection.complete([], request: request)
        XCTAssertEqual(selection.date, "2026-09-29")
        XCTAssertEqual(selection.detail, [])
    }

    func testSupersededCompletionAndCancellationCannotEraseNewDay() {
        var selection = CalendarDaySelection<String>()
        let older = selection.begin("2026-09-29")
        let newer = selection.begin("2026-09-30")
        selection.complete("new", request: newer)
        selection.complete("old", request: older)
        selection.cancel(request: older)
        XCTAssertEqual(selection.date, "2026-09-30")
        XCTAssertEqual(selection.detail, "new")
    }

    func testCurrentCancellationPreservesPreviouslyLoadedDay() {
        var selection = CalendarDaySelection<String>()
        let first = selection.begin("2026-09-29")
        selection.complete("loaded", request: first)
        let next = selection.begin("2026-09-30")
        XCTAssertNil(selection.detail) // Never show yesterday under today's title.
        selection.cancel(request: next)
        XCTAssertEqual(selection.date, "2026-09-29")
        XCTAssertEqual(selection.detail, "loaded")
    }

    func testDismissedDayCannotReopenOnLateCompletion() {
        var selection = CalendarDaySelection<String>()
        let request = selection.begin("2026-09-30")
        selection.clear()
        selection.complete("late", request: request)
        XCTAssertNil(selection.date)
        XCTAssertNil(selection.detail)
    }

    func testURLSessionCancellationIsNotFailure() {
        XCTAssertTrue(CalendarDaySelection<String>.isCancellation(URLError(.cancelled)))
        XCTAssertTrue(CalendarDaySelection<String>.isCancellation(CancellationError()))
        XCTAssertFalse(CalendarDaySelection<String>.isCancellation(URLError(.timedOut)))
    }
}
