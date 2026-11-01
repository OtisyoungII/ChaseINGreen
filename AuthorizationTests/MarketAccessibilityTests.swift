import XCTest
@testable import ChaseINGreenAuthorization

final class MarketAccessibilityTests: XCTestCase {
    func testEveryRequestedMinuteIntervalIsTimeBased() {
        let expected: [(String, TimeInterval, String)] = [
            ("1m", 60, "1m"), ("2m", 120, "2m"), ("3m", 180, "3m"),
            ("5m", 300, "5m"), ("15m", 900, "15m"),
            ("30m", 1_800, "30m"), ("45m", 2_700, "45m")
        ]
        for (raw, seconds, display) in expected {
            XCTAssertEqual(MarketBarInterval.parse(raw).basis, .time(seconds: seconds))
            XCTAssertEqual(MarketBarInterval.parse(raw).displayName, display)
        }
    }

    func testEveryRequestedHourIntervalAndAliasesAreTimeBased() {
        let expected: [(String, TimeInterval, String)] = [
            ("1H", 3_600, "1H"), ("2H", 7_200, "2H"),
            ("3H", 10_800, "3H"), ("4H", 14_400, "4H")
        ]
        for (raw, seconds, display) in expected {
            XCTAssertEqual(MarketBarInterval.parse(raw).basis, .time(seconds: seconds))
            XCTAssertEqual(MarketBarInterval.parse(raw).displayName, display)
        }
        XCTAssertEqual(MarketBarInterval.parse("H3").basis, .time(seconds: 10_800))
        XCTAssertEqual(MarketBarInterval.parse("180m").displayName, "3H")
    }

    func testDailyIntervalRemainsSupported() {
        XCTAssertEqual(MarketBarInterval.parse("1D").basis, .time(seconds: 86_400))
        XCTAssertEqual(MarketBarInterval.parse("D1").displayName, "1D")
    }

    func testTickBarsAreActivityBasedAndNeverReceiveClockDuration() {
        let interval = MarketBarInterval.parse("2000-tick")
        XCTAssertEqual(interval.basis, .ticks(count: 2_000))
        XCTAssertEqual(interval.displayName, "2000-tick")
        XCTAssertEqual(interval.activityDescription, "Closes after 2,000 qualifying ticks")
        XCTAssertNil(CandleCloseCountdown.duration(for: "2000-tick"))
    }

    func testTickBarCannotReceiveWallClockBoundary() {
        XCTAssertNil(CandleCloseCountdown.closeDate(
            timeframe: "2000t",
            now: Date(timeIntervalSince1970: 1_800_000_000),
            authoritativeClose: nil,
            usesContinuousUTCBoundaries: true
        ))
    }

    func testUnknownSessionBoundaryRemainsUnavailable() {
        XCTAssertNil(CandleCloseCountdown.closeDate(
            timeframe: "3h",
            now: Date(timeIntervalSince1970: 1_800_000_000),
            authoritativeClose: nil,
            usesContinuousUTCBoundaries: false
        ))
    }

    func testFuturesPointToTickConversionUsesSuppliedMinimumTick() {
        let metadata = FuturesInstrumentMetadata(
            minimumTickPoints: 0.25,
            tickValue: 12.50,
            contractMultiplier: 50,
            initialMargin: nil
        )
        XCTAssertEqual(metadata.pointTickConversion(points: 20), "20 points = 80 ticks")
    }

    func testMissingOrInvalidTickMetadataProducesNoConversion() {
        let missing = FuturesInstrumentMetadata(
            minimumTickPoints: nil,
            tickValue: nil,
            contractMultiplier: nil,
            initialMargin: nil
        )
        let invalid = FuturesInstrumentMetadata(
            minimumTickPoints: 0,
            tickValue: nil,
            contractMultiplier: nil,
            initialMargin: nil
        )
        XCTAssertNil(missing.pointTickConversion(points: 20))
        XCTAssertNil(invalid.pointTickConversion(points: 20))
    }

    func testFuturesVocabularyUsesFamiliarTerms() {
        XCTAssertEqual(MarketAccessibility.term(.tick, market: .futures), "Tick")
        XCTAssertEqual(MarketAccessibility.term(.contract, market: .futures), "Futures Contract")
        XCTAssertEqual(MarketAccessibility.term(.rth, market: .futures), "Regular Trading Hours (RTH)")
        XCTAssertEqual(MarketAccessibility.term(.eth, market: .futures), "Extended Trading Hours (ETH)")
        XCTAssertEqual(MarketAccessibility.term(.frontMonthContract, market: .futures), "Front-Month Contract")
    }

    func testGeneralVocabularyUsesFamiliarCrossMarketTerms() {
        XCTAssertEqual(MarketAccessibility.term(.realizedPnL), "Realized P&L")
        XCTAssertEqual(MarketAccessibility.term(.unrealizedPnL), "Unrealized P&L")
        XCTAssertEqual(MarketAccessibility.term(.support), "Support")
        XCTAssertEqual(MarketAccessibility.term(.resistance), "Resistance")
        XCTAssertEqual(MarketAccessibility.term(.spread), "Spread")
    }

    func testDescriptiveTimeframeStateDoesNotCreateTradingAuthority() {
        let text = MarketAccessibility.descriptiveState(
            timeframe: "15m",
            direction: "bullish",
            strength: "strong",
            finality: "provisional"
        )
        XCTAssertEqual(text, "15m · BULLISH · STRONG · CONFIRMATION PENDING CLOSE")
        for forbidden in ["BUY", "SELL", "ENTER", "EXIT"] {
            XCTAssertFalse(text.contains(forbidden))
        }
    }

    func testUnavailableStrengthIsOmittedRatherThanFabricated() {
        XCTAssertEqual(
            MarketAccessibility.descriptiveState(
                timeframe: "1h",
                direction: "bearish",
                strength: nil,
                finality: "closed"
            ),
            "1H · BEARISH"
        )
    }

    func testMidnightDoesNotCreateANewAuthoritativeSession() {
        let metadata = sessionMetadata(
            market: .futures,
            identifier: "ES-2026-11-01",
            start: date("2026-10-31T22:00:00Z"),
            end: date("2026-11-01T21:00:00Z"),
            extended: true
        )

        XCTAssertEqual(
            metadata.authoritativeSessionIdentifier(at: date("2026-10-31T23:59:00Z")),
            "ES-2026-11-01"
        )
        XCTAssertEqual(
            metadata.authoritativeSessionIdentifier(at: date("2026-11-01T00:01:00Z")),
            "ES-2026-11-01"
        )
    }

    func testCalendarDateAndAuthoritativeSessionIdentityRemainSeparate() {
        let metadata = sessionMetadata(
            market: .futures,
            identifier: "overnight-42",
            start: date("2026-10-31T22:00:00Z"),
            end: date("2026-11-01T21:00:00Z"),
            extended: true
        )
        let beforeMidnight = MarketSessionContext(
            calendarDate: date("2026-10-31T23:59:00Z"),
            metadata: metadata
        )
        let afterMidnight = MarketSessionContext(
            calendarDate: date("2026-11-01T00:01:00Z"),
            metadata: metadata
        )

        XCTAssertNotEqual(utcDay(beforeMidnight.calendarDate), utcDay(afterMidnight.calendarDate))
        XCTAssertEqual(
            beforeMidnight.authoritativeSessionIdentifier,
            afterMidnight.authoritativeSessionIdentifier
        )
    }

    func testContinuousCryptoDoesNotFabricateClosedOrExtendedSessionLanguage() {
        let metadata = MarketSessionMetadata(
            market: .crypto,
            venueIdentifier: "crypto-venue",
            timezoneIdentifier: "UTC",
            sessionIdentifier: "continuous",
            sessionType: "continuous",
            sessionStart: nil,
            sessionEnd: nil,
            isContinuousTrading: true,
            supportsExtendedHours: false
        )
        let concepts = MarketSessionRelevance.concepts(for: .crypto, metadata: metadata)

        XCTAssertFalse(concepts.contains(.sessionClose))
        XCTAssertFalse(concepts.contains(.preMarket))
        XCTAssertFalse(concepts.contains(.afterHours))
        XCTAssertTrue(concepts.isEmpty)
    }

    func testFuturesCanExposeRTHETHOvernightAndDistinctSessionLevels() {
        let metadata = sessionMetadata(
            market: .futures,
            identifier: "ES-overnight",
            start: date("2026-10-31T22:00:00Z"),
            end: date("2026-11-01T21:00:00Z"),
            extended: true
        )
        let concepts = MarketSessionRelevance.concepts(for: .futures, metadata: metadata)

        XCTAssertTrue(concepts.isSuperset(of: [.rth, .eth, .overnightSession]))
        XCTAssertTrue(concepts.isSuperset(of: [
            .currentSessionHigh, .currentSessionLow,
            .priorSessionHigh, .priorSessionLow
        ]))
    }

    func testEquitiesExposeOnlySupportedSessionFamilies() {
        let regularOnly = sessionMetadata(
            market: .equities,
            identifier: "NYSE-regular",
            start: date("2026-11-02T14:30:00Z"),
            end: date("2026-11-02T21:00:00Z"),
            extended: false
        )
        let extended = sessionMetadata(
            market: .equities,
            identifier: "NYSE-full-day",
            start: date("2026-11-02T09:00:00Z"),
            end: date("2026-11-03T01:00:00Z"),
            extended: true
        )

        let regularConcepts = MarketSessionRelevance.concepts(for: .equities, metadata: regularOnly)
        XCTAssertTrue(regularConcepts.contains(.regularSession))
        XCTAssertFalse(regularConcepts.contains(.preMarket))
        XCTAssertFalse(regularConcepts.contains(.afterHours))

        let extendedConcepts = MarketSessionRelevance.concepts(for: .equities, metadata: extended)
        XCTAssertTrue(extendedConcepts.isSuperset(of: [
            .regularSession, .extendedSession, .preMarket, .afterHours
        ]))
    }

    func testMissingSessionMetadataCannotFabricateBoundariesOrLevels() {
        let context = MarketSessionContext(
            calendarDate: date("2026-11-01T00:01:00Z"),
            metadata: nil
        )
        let emptyMetadata = MarketSessionMetadata(
            market: .equities,
            venueIdentifier: nil,
            timezoneIdentifier: nil,
            sessionIdentifier: nil,
            sessionType: nil,
            sessionStart: nil,
            sessionEnd: nil,
            isContinuousTrading: nil,
            supportsExtendedHours: nil
        )

        XCTAssertNil(context.authoritativeSessionIdentifier)
        XCTAssertTrue(MarketSessionRelevance.concepts(for: .equities, metadata: nil).isEmpty)
        XCTAssertTrue(MarketSessionRelevance.concepts(for: .equities, metadata: emptyMetadata).isEmpty)
    }

    func testCurrentSessionHighAndPriorSessionHighTakenAreDistinctFacts() {
        let current = SessionLevelObservation(
            reference: .currentSessionHigh,
            relationship: .established,
            price: 105,
            sessionIdentifier: "current"
        )
        let priorTaken = SessionLevelObservation(
            reference: .priorSessionHigh,
            relationship: .taken,
            price: 100,
            sessionIdentifier: "prior"
        )

        XCTAssertNotEqual(current.reference, priorTaken.reference)
        XCTAssertNotEqual(current.sessionIdentifier, priorTaken.sessionIdentifier)
        XCTAssertEqual(priorTaken.relationship, .taken)
    }

    func testPositionSessionExplanationsNeverCreateTradingAuthority() {
        let descriptions = [
            PositionSessionEvent.regularSessionEndedWhilePositionOpen,
            .extendedTradingContinued,
            .overnightReversalReducedUnrealizedProfit
        ].map(\.customerDescription)

        for description in descriptions {
            let words = Set(description.lowercased().split { !$0.isLetter }.map(String.init))
            XCTAssertTrue(words.isDisjoint(with: ["buy", "sell", "enter", "exit", "hold", "close"]))
        }
    }

    private func sessionMetadata(
        market: MarketAccessibility.Market,
        identifier: String,
        start: Date,
        end: Date,
        extended: Bool
    ) -> MarketSessionMetadata {
        MarketSessionMetadata(
            market: market,
            venueIdentifier: market == .futures ? "CME" : "NYSE",
            timezoneIdentifier: "America/New_York",
            sessionIdentifier: identifier,
            sessionType: "regular",
            sessionStart: start,
            sessionEnd: end,
            isContinuousTrading: false,
            supportsExtendedHours: extended
        )
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func utcDay(_ date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.component(.day, from: date)
    }
}
