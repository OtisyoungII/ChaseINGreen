import XCTest
@testable import ChaseINGreenAuthorization

final class TradePathIntelligenceTests: XCTestCase {
    func testMAEAndMFERemainDistinct() {
        let entry = price(100, at: 0)
        let mae = TradePathExcursion.measure(
            kind: .maximumAdverseExcursion,
            direction: .long,
            entry: entry,
            extreme: price(90, at: 1)
        )
        let mfe = TradePathExcursion.measure(
            kind: .maximumFavorableExcursion,
            direction: .long,
            entry: entry,
            extreme: price(125, at: 2)
        )

        XCTAssertEqual(mae?.kind, .maximumAdverseExcursion)
        XCTAssertEqual(mae?.absolutePrice, 10)
        XCTAssertEqual(mae?.percentage, 10)
        XCTAssertEqual(mfe?.kind, .maximumFavorableExcursion)
        XCTAssertEqual(mfe?.absolutePrice, 25)
        XCTAssertEqual(mfe?.percentage, 25)
    }

    func testMissingAuthoritativePathEvidenceDoesNotFabricateExcursion() {
        let observational = TradePathPriceObservation(
            price: 90,
            timestamp: nil,
            authority: .observational,
            evidence: nil
        )
        XCTAssertNil(TradePathExcursion.measure(
            kind: .maximumAdverseExcursion,
            direction: .long,
            entry: price(100, at: 0),
            extreme: observational
        ))
        XCTAssertNil(TradePathExcursion.measure(
            kind: .maximumAdverseExcursion,
            direction: .long,
            entry: nil,
            extreme: price(90, at: 1)
        ))
    }

    func testMonetaryExcursionRequiresAuthoritativeEconomics() {
        let withoutEconomics = TradePathExcursion.measure(
            kind: .maximumAdverseExcursion,
            direction: .long,
            entry: price(100, at: 0),
            extreme: price(95, at: 1)
        )
        let withEconomics = TradePathExcursion.measure(
            kind: .maximumAdverseExcursion,
            direction: .long,
            entry: price(100, at: 0),
            extreme: price(95, at: 1),
            economics: TradePathInstrumentEconomics(
                quantity: 2,
                monetaryValuePerPriceUnit: 50,
                currencyCode: "USD"
            )
        )

        XCTAssertNil(withoutEconomics?.monetary)
        XCTAssertEqual(withEconomics?.monetary, 500)
        XCTAssertEqual(withEconomics?.currencyCode, "USD")
    }

    func testThesisSuccessDoesNotImplyGoodEntryOrAccountCompatibility() {
        let assessment = TradePathAssessment(
            thesisOutcome: .succeeded,
            entryQuality: .unfavorable,
            pathQuality: .adverseBeforeFavorable,
            accountCompatibility: .incompatible
        )

        XCTAssertEqual(assessment.thesisOutcome, .succeeded)
        XCTAssertEqual(assessment.entryQuality, .unfavorable)
        XCTAssertEqual(assessment.pathQuality, .adverseBeforeFavorable)
        XCTAssertEqual(assessment.accountCompatibility, .incompatible)
    }

    func testLargeAdverseExcursionDoesNotAutomaticallyInvalidateThesis() {
        let assessment = TradePathAssessment(
            thesisOutcome: .succeeded,
            entryQuality: .unknown,
            pathQuality: .adverseBeforeFavorable,
            accountCompatibility: .unknown
        )
        let mae = TradePathExcursion.measure(
            kind: .maximumAdverseExcursion,
            direction: .long,
            entry: price(100, at: 0),
            extreme: price(50, at: 1)
        )

        XCTAssertEqual(mae?.absolutePrice, 50)
        XCTAssertEqual(assessment.thesisOutcome, .succeeded)
    }

    func testExitThenExpansionIsFactualAndNeverHindsightJudgment() {
        let observation = ExitBeforeExpansionObservation.observed(
            entryIdentifier: "entry-a",
            exit: price(101, at: 2),
            subsequentExpansion: price(120, at: 3)
        )

        XCTAssertNotNil(observation)
        XCTAssertEqual(observation?.classifiesExitAsMistake, false)
        XCTAssertEqual(observation?.impliesTraderShouldHaveHeld, false)
        XCTAssertEqual(observation?.authorizesReopening, false)
        XCTAssertNil(ExitBeforeExpansionObservation.observed(
            entryIdentifier: "entry-a",
            exit: price(101, at: 3),
            subsequentExpansion: price(120, at: 2)
        ))
    }

    func testMultipleEntriesRetainIndependentExcursionsStopsAndEvidence() {
        let first = entry(
            id: "a",
            price: 100,
            mae: excursion(.maximumAdverseExcursion, entry: 100, extreme: 90),
            mfe: excursion(.maximumFavorableExcursion, entry: 100, extreme: 120),
            stop: 88,
            timeframe: "15m"
        )
        let second = entry(
            id: "b",
            price: 95,
            mae: excursion(.maximumAdverseExcursion, entry: 95, extreme: 92),
            mfe: excursion(.maximumFavorableExcursion, entry: 95, extreme: 125),
            stop: 91,
            timeframe: "1H"
        )
        let group = GroupedTradePathRecord(
            thesisIdentifier: "thesis-1",
            entries: [first, second],
            combinedExposure: 2,
            authoritativeAverageEntryPrice: 97.5,
            aggregateMAE: nil,
            aggregateMFE: nil,
            thesisOutcome: .active,
            accountImpact: nil
        )

        XCTAssertEqual(group.entries.map(\.entryPrice), [100, 95])
        XCTAssertEqual(group.entries.map(\.mae?.absolutePrice), [10, 3])
        XCTAssertEqual(group.entries.map(\.mfe?.absolutePrice), [20, 30])
        XCTAssertEqual(group.entries.map(\.stopInvalidation?.stopPrice), [88, 91])
        XCTAssertEqual(group.entries.map(\.entryEvidence?.timeframe), ["15m", "1H"])
        XCTAssertEqual(group.authoritativeAverageEntryPrice, 97.5)
    }

    func testTimeframeEvidenceIsOptionalAndNeverSynthesized() {
        let record = entry(
            id: "no-evidence",
            price: 100,
            mae: nil,
            mfe: nil,
            stop: nil,
            timeframe: nil
        )

        XCTAssertNil(record.entryEvidence)
        XCTAssertNil(record.mae)
        XCTAssertNil(record.mfe)
        XCTAssertNil(record.stopInvalidation)
    }

    func testDomainModelsNeverGrantTradingOrExecutionAuthority() {
        let assessment = TradePathAssessment(
            thesisOutcome: .succeeded,
            entryQuality: .favorable,
            pathQuality: .orderly,
            accountCompatibility: .compatible
        )
        let record = entry(
            id: "a",
            price: 100,
            mae: nil,
            mfe: nil,
            stop: nil,
            timeframe: nil
        )
        let group = GroupedTradePathRecord(
            thesisIdentifier: "thesis",
            entries: [record],
            combinedExposure: nil,
            authoritativeAverageEntryPrice: nil,
            aggregateMAE: nil,
            aggregateMFE: nil,
            thesisOutcome: .unknown,
            accountImpact: nil
        )

        XCTAssertFalse(assessment.decisionAuthority)
        XCTAssertFalse(assessment.automaticExecution)
        XCTAssertFalse(record.decisionAuthority)
        XCTAssertFalse(record.automaticExecution)
        XCTAssertFalse(group.decisionAuthority)
        XCTAssertFalse(group.automaticExecution)
    }

    private func price(_ value: Double, at seconds: TimeInterval) -> TradePathPriceObservation {
        TradePathPriceObservation(
            price: value,
            timestamp: Date(timeIntervalSince1970: seconds),
            authority: .authoritative,
            evidence: nil
        )
    }

    private func excursion(
        _ kind: ExcursionKind,
        entry: Double,
        extreme: Double
    ) -> TradePathExcursion? {
        TradePathExcursion.measure(
            kind: kind,
            direction: .long,
            entry: price(entry, at: 0),
            extreme: price(extreme, at: 1)
        )
    }

    private func entry(
        id: String,
        price: Double,
        mae: TradePathExcursion?,
        mfe: TradePathExcursion?,
        stop: Double?,
        timeframe: String?
    ) -> TradeEntryPathRecord {
        let evidence = timeframe.map {
            TradePathEvidenceSnapshot(
                timeframe: $0,
                directionalState: nil,
                confirmationState: nil,
                candleCloseProximity: nil,
                sessionIdentifier: nil,
                observedAt: nil,
                authority: .authoritative
            )
        }
        return TradeEntryPathRecord(
            id: id,
            thesisIdentifier: "thesis-1",
            entryTimestamp: Date(timeIntervalSince1970: 0),
            entryPrice: price,
            size: 1,
            rationale: nil,
            riskBudget: nil,
            stopInvalidation: stop.map {
                EntryStopInvalidationMetadata(
                    stopPrice: $0,
                    invalidationPrice: nil,
                    rationale: nil,
                    evidence: evidence
                )
            },
            mae: mae,
            mfe: mfe,
            entryEvidence: evidence,
            realizedOutcome: nil
        )
    }
}
