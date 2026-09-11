import Foundation
import XCTest
@testable import ChaseINGreenAuthorization

final class MarketDecisionPresentationTests: XCTestCase {
    private struct Fixture: Decodable {
        let name: String
        let traderOS: TraderOSResponse
        let preTrade: PreTradeContextResponse
        enum CodingKeys: String, CodingKey {
            case name
            case traderOS = "trader_os", preTrade = "pre_trade"
        }
    }
    private func fixtures() throws -> [Fixture] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "market_decision_contract", withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
    }
    func testSharedPythonResponsesDecodeAndPreserveIndependentAxes() throws {
        let rows = try fixtures()
        XCTAssertEqual(rows.count, 18)
        for row in rows where row.name != "legacy" {
            let semantics = try XCTUnwrap(row.traderOS.marketSemantics, row.name)
            let regime = row.traderOS.marketState?.regimeAssessment
            XCTAssertEqual(regime?.broaderTrend, semantics.regimeAssessment?.broaderTrend, row.name)
            XCTAssertEqual(regime?.currentRegime, semantics.regimeAssessment?.currentRegime, row.name)
            XCTAssertEqual(regime?.entryCondition, semantics.regimeAssessment?.entryCondition, row.name)
            XCTAssertEqual(semantics.entryAllowed, row.traderOS.decision?.entryAllowed, row.name)
            XCTAssertEqual(semantics.shouldTrade, row.traderOS.executionPlan?.shouldTrade, row.name)
            XCTAssertEqual(semantics.riskScore, row.traderOS.marketState?.riskScore, row.name)
            XCTAssertEqual(row.preTrade.marketSemantics?.entryAllowed, row.preTrade.canEnter, row.name)
        }
    }
    func testBullishExtendedWaitAndWarningProseCannotCreateBearishEvidence() throws {
        for row in try fixtures() where ["bullish_extended", "poor_entry", "ai_opposition", "direction_only"].contains(row.name) {
            for result in [MarketDecisionPresentationPolicy.traderOS(row.traderOS), MarketDecisionPresentationPolicy.preTrade(row.preTrade)] {
                XCTAssertEqual(result.direction, .bullish, row.name)
                XCTAssertEqual(result.action, "WAIT", row.name)
                XCTAssertFalse(result.entryConfirmed, row.name)
            }
        }
        for row in try fixtures() where ["do_not_chase", "pullback_warning"].contains(row.name) {
            for result in [MarketDecisionPresentationPolicy.traderOS(row.traderOS), MarketDecisionPresentationPolicy.preTrade(row.preTrade)] {
                XCTAssertEqual(result.direction, .bullish)
                XCTAssertEqual(result.action, "LONG ENTRY WATCH")
            }
        }
    }
    func testBackendPermittedShortAndLongRemainCapable() throws {
        for row in try fixtures() where ["permitted_short", "short_vocabulary", "long_vocabulary"].contains(row.name) {
            let short = row.name != "long_vocabulary"
            for result in [MarketDecisionPresentationPolicy.traderOS(row.traderOS), MarketDecisionPresentationPolicy.preTrade(row.preTrade)] {
                XCTAssertEqual(result.direction, short ? .bearish : .bullish)
                XCTAssertEqual(result.action, short ? "SHORT ENTRY WATCH" : "LONG ENTRY WATCH")
                XCTAssertTrue(result.entryConfirmed)
            }
        }
    }
    func testPermissionSideDoesNotRewriteDirectionalThesis() throws {
        let row = try XCTUnwrap(fixtures().first { $0.name == "permission_does_not_rewrite_direction" })
        let result = MarketDecisionPresentationPolicy.traderOS(row.traderOS)
        XCTAssertEqual(result.direction, .bullish)
        XCTAssertEqual(result.action, "SHORT ENTRY WATCH")
    }
    func testUnconfirmedEvidenceCannotPromoteAnEntry() throws {
        for row in try fixtures() where ["unavailable", "degraded", "provisional", "unknown", "older_closed_with_developing_tail"].contains(row.name) {
            for result in [MarketDecisionPresentationPolicy.traderOS(row.traderOS), MarketDecisionPresentationPolicy.preTrade(row.preTrade)] {
                XCTAssertFalse(result.entryConfirmed, row.name)
                XCTAssertEqual(result.action, "NO CONFIRMED ACTION", row.name)
                XCTAssertEqual(result.evidenceStatus, row.name == "older_closed_with_developing_tail" ? "degraded" : row.name)
            }
        }
    }
    func testClosedTimestampAndPathVersusLatestChangeRemainDistinct() throws {
        let row = try XCTUnwrap(fixtures().first { $0.name == "older_closed_with_developing_tail" })
        let evidence = try XCTUnwrap(row.traderOS.marketSemantics?.evidence)
        XCTAssertEqual(evidence.confirmationThrough, "2026-09-10T12:00:00+00:00")
        let h4 = try XCTUnwrap(evidence.timeframes?["4h"])
        XCTAssertEqual(h4.effectiveTimeframe, "4h")
        XCTAssertEqual(h4.sourceTimeframe, "1h")
        XCTAssertEqual(h4.pathDirection, "bullish")
        XCTAssertEqual(h4.latestChangeDirection, "bearish")
        XCTAssertEqual(h4.provisionalCount, 1)
        XCTAssertEqual(MarketDecisionPresentationPolicy.traderOS(row.traderOS).confirmationThrough, evidence.confirmationThrough)
    }
    func testLegacyResponsesDecodeWithUnknownEvidence() throws {
        let row = try XCTUnwrap(fixtures().first { $0.name == "legacy" })
        XCTAssertNil(row.traderOS.marketSemantics)
        XCTAssertNil(row.preTrade.marketSemantics)
        for result in [MarketDecisionPresentationPolicy.traderOS(row.traderOS), MarketDecisionPresentationPolicy.preTrade(row.preTrade)] {
            XCTAssertEqual(result.direction, .bullish)
            XCTAssertFalse(result.entryConfirmed)
            XCTAssertEqual(result.evidenceStatus, "unknown")
        }
        XCTAssertEqual(MarketDecisionPresentationPolicy.traderOS(nil).direction, .unknown)
    }
    func testBothDecisionPlanConflictsAreConservative() throws {
        for row in try fixtures() where ["decision_plan_conflict", "reverse_conflict"].contains(row.name) {
            let result = MarketDecisionPresentationPolicy.traderOS(row.traderOS)
            XCTAssertEqual(result.action, "WAIT — DECISION / PLAN CONFLICT")
            XCTAssertFalse(result.entryConfirmed)
        }
    }
    func testDirectionVocabularyIsExplicit() {
        for word in ["long", "bullish", "buy", "up", "call", " LONG "] {
            XCTAssertEqual(MarketDecisionPresentationPolicy.direction(word), .bullish)
        }
        for word in ["short", "bearish", "sell", "down", "put"] {
            XCTAssertEqual(MarketDecisionPresentationPolicy.direction(word), .bearish)
        }
        XCTAssertEqual(MarketDecisionPresentationPolicy.direction("pullback do not chase SELL"), .unknown)
        XCTAssertEqual(MarketDecisionPresentationPolicy.direction(nil), .unknown)
    }
}
