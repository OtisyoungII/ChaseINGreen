import Foundation
import XCTest
@testable import ChaseINGreenAuthorization

final class OpportunityScreenerTests: XCTestCase {
    private func fixture() throws -> ScreenerResponse {
        let url = Bundle.module.url(forResource: "opportunity_screener_contract", withExtension: "json", subdirectory: "Fixtures")!
        return try ScreenerResponse.decode(Data(contentsOf: url))
    }
    func testBackendContractAndTypedNavigation() throws {
        let generation = try XCTUnwrap(try fixture().generation)
        XCTAssertEqual(generation.universeCount, 9)
        XCTAssertEqual(generation.scoringPolicy, "movement-ema-structure-v1")
        let nq = try XCTUnwrap(generation.candidates.first { $0.instrument.symbol == "NQ=F" })
        XCTAssertEqual(nq.instrument.navigationSymbol, "NQ=F")
        XCTAssertEqual(nq.instrument.instrumentType, "continuous_future")
        XCTAssertNotNil(nq.instrument.contractIdentity)
        let dow = try XCTUnwrap(generation.candidates.first { $0.instrument.symbol == "^DJI" })
        XCTAssertEqual(dow.instrument.navigationSymbol, "^DJI")
        XCTAssertEqual(dow.instrument.instrumentType, "cash_index")
        let crypto = try XCTUnwrap(generation.candidates.first { $0.instrument.symbol == "BTC-USD" })
        XCTAssertEqual(crypto.instrument.provider, "kraken")
        XCTAssertEqual(crypto.instrument.navigationSymbol, "BTC-USD")
        XCTAssertEqual(crypto.instrument.providerSymbol, "XXBTZUSD")
        XCTAssertTrue(generation.candidates.allSatisfy { !$0.executionAuthority && $0.instrument.supportedNavigation })
    }
    func testFiltersReasonsAndMissingScores() throws {
        let generation = try XCTUnwrap(try fixture().generation)
        XCTAssertEqual(generation.filtered(asset: "CRYPTO", direction: "BOTH").count, 2)
        XCTAssertTrue(generation.filtered(asset: "ALL", direction: "SHORT").allSatisfy { $0.direction == "SHORT" })
        XCTAssertTrue(generation.candidates.contains { $0.score == nil })
        XCTAssertTrue(generation.candidates.allSatisfy { $0.displayReasons.count <= 4 })
        XCTAssertEqual(ScreenerCandidate.reasonLabel("SHORT_MOMENTUM"), "Bearish momentum")
        XCTAssertEqual(ScreenerCandidate.reasonLabel("UNKNOWN"), "Additional evidence unavailable")
    }
    func testExpiryDoesNotRequireNetworkRefresh() throws {
        let generation = try XCTUnwrap(try fixture().generation)
        XCTAssertFalse(generation.isExpired(at: Date(timeIntervalSince1970: 0)))
        XCTAssertTrue(generation.isExpired(at: Date.distantFuture))
    }
    func testUnavailableGeneration() throws {
        let response = try ScreenerResponse.decode(Data(#"{"status":"unavailable","generation":null}"#.utf8))
        XCTAssertNil(response.generation)
    }
}

final class OpportunityRelativePerformanceTests: XCTestCase {
    private func fixtureData() throws -> Data {
        let url = Bundle.module.url(forResource: "opportunity_relative_performance_contract", withExtension: "json", subdirectory: "Fixtures")!
        return try Data(contentsOf: url)
    }
    private func fixture() throws -> ScreenerGeneration {
        try XCTUnwrap(try ScreenerResponse.decode(fixtureData()).generation)
    }
    func testAdditiveBackendEvidenceAndReplayFields() throws {
        let generation = try fixture()
        let nvda = try XCTUnwrap(generation.candidates.first { $0.instrument.symbol == "NVDA" })
        let evidence = try XCTUnwrap(nvda.relativePerformance)
        XCTAssertEqual(evidence.status, "AVAILABLE")
        XCTAssertEqual(evidence.benchmark?.canonicalId, "yahoo:^GSPC:cash_index")
        XCTAssertEqual(evidence.benchmarkPolicyVersion, "bounded-benchmarks-v1")
        XCTAssertEqual(evidence.calculationVersion, "synchronized-close-return-v1")
        XCTAssertEqual(evidence.alignmentToleranceSeconds, 0)
        XCTAssertEqual(evidence.neutralTolerancePercentagePoints, 0.05)
        XCTAssertEqual(evidence.coverage, "complete")
        XCTAssertEqual(evidence.instrumentWindow?.startAt, evidence.benchmarkWindow?.startAt)
        XCTAssertEqual(evidence.instrumentWindow?.endAt, evidence.benchmarkWindow?.endAt)
        XCTAssertNotNil(evidence.informationAvailableAt)
        XCTAssertNotNil(evidence.expiresAt)
        XCTAssertTrue(nvda.displayReasons.first!.contains("Outperforming S&P 500"))
        XCTAssertTrue(nvda.displayReasons.first!.contains("since first regular 15m close"))
        XCTAssertLessThanOrEqual(nvda.displayReasons.count, 4)
        XCTAssertEqual(nvda.displayReasons(stale: true).first, "Relative performance is stale")
        XCTAssertFalse(nvda.executionAuthority)
    }
    func testCryptoAndUnsupportedFuturesRemainDistinct() throws {
        let generation = try fixture()
        let eth = try XCTUnwrap(generation.candidates.first { $0.instrument.symbol == "ETH-USD" })
        XCTAssertEqual(eth.relativePerformance?.benchmark?.providerSymbol, "XXBTZUSD")
        XCTAssertEqual(eth.relativePerformance?.instrumentWindow?.sessionPolicy, "crypto-utc-rolling-60m-closed-15m-v1")
        XCTAssertTrue(eth.displayReasons.first!.contains("closed 60m · UTC"))
        let nq = try XCTUnwrap(generation.candidates.first { $0.instrument.symbol == "NQ=F" })
        XCTAssertEqual(nq.relativePerformance?.status, "UNAVAILABLE")
        XCTAssertEqual(nq.relativePerformance?.benchmark?.instrumentType, "continuous_future")
        XCTAssertNil(nq.relativePerformance?.relativeReturnPercentagePoints)
        XCTAssertEqual(nq.instrument.navigationSymbol, "NQ=F")
        let oil = try XCTUnwrap(generation.candidates.first { $0.instrument.symbol == "CL=F" })
        XCTAssertEqual(oil.relativePerformance?.status, "NOT_APPLICABLE")
    }
    func testOldResponseHasNoAdditiveEvidenceRequirement() throws {
        let url = Bundle.module.url(forResource: "opportunity_screener_contract", withExtension: "json", subdirectory: "Fixtures")!
        let generation = try XCTUnwrap(try ScreenerResponse.decode(Data(contentsOf: url)).generation)
        XCTAssertTrue(generation.candidates.allSatisfy { $0.relativePerformance == nil })
        XCTAssertTrue(generation.candidates.allSatisfy { $0.displayReasons == Array($0.reasons.prefix(4)).map(ScreenerCandidate.reasonLabel) })
    }
    func testRiskWarningsAreNotDisplacedByRelativeReason() throws {
        var raw = try JSONSerialization.jsonObject(with: fixtureData()) as! [String: Any]
        var gen = raw["generation"] as! [String: Any]
        var candidates = gen["candidates"] as! [[String: Any]]
        candidates[0]["reasons"] = ["LONG_MOMENTUM", "LONG_STRUCTURE", "BREAKOUT_CONFIRMED", "EXTENDED_FROM_STRUCTURE"]
        gen["candidates"] = candidates
        raw["generation"] = gen
        let candidate = try ScreenerResponse.decode(JSONSerialization.data(withJSONObject: raw)).generation!.candidates[0]
        XCTAssertTrue(candidate.displayReasons.contains("Extended from structure"))
        XCTAssertEqual(candidate.displayReasons.count, 4)
    }
    func testStatusAndInterpretationNeverBecomeTradeDirection() throws {
        let raw = try JSONSerialization.jsonObject(with: fixtureData()) as! [String: Any]
        let gen = raw["generation"] as! [String: Any]
        var candidates = gen["candidates"] as! [[String: Any]]
        let index = candidates.firstIndex { ($0["instrument"] as! [String: Any])["symbol"] as? String == "NVDA" }!
        let originalDirection = candidates[index]["direction"] as! String
        let originalScore = candidates[index]["score"] as! Double
        for (status, interpretation, value, expected) in [
            ("AVAILABLE", "UNDERPERFORMING", -1.6, "Underperforming S&P 500"),
            ("AVAILABLE", "NEUTRAL", 0.02, "Tracking S&P 500"),
            ("STALE", "OUTPERFORMING", 1.6, "Relative performance is stale"),
            ("UNAVAILABLE", "OUTPERFORMING", 1.6, "Relative performance unavailable"),
            ("CONFLICTED", "OUTPERFORMING", 1.6, "Relative performance unavailable"),
            ("FUTURE_STATUS", "OUTPERFORMING", 1.6, "Relative performance unavailable")
        ] {
            var changed = raw
            var updatedGen = gen
            var evidence = candidates[index]["relative_performance"] as! [String: Any]
            evidence["status"] = status
            evidence["interpretation"] = interpretation
            evidence["relative_return_percentage_points"] = value
            candidates[index]["relative_performance"] = evidence
            updatedGen["candidates"] = candidates
            changed["generation"] = updatedGen
            let parsed = try ScreenerResponse.decode(JSONSerialization.data(withJSONObject: changed)).generation!.candidates[index]
            XCTAssertTrue(parsed.displayReasons.first!.hasPrefix(expected))
            XCTAssertEqual(parsed.direction, originalDirection)
            XCTAssertEqual(parsed.score, originalScore)
        }
    }
}
