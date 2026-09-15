import XCTest
@testable import ChaseINGreenAuthorization

final class ScoreAvailabilityTests: XCTestCase {
    func testUnavailableAndMeasuredZeroRoundTrip() throws {
        for available in [true, false] {
            let json = """
            {"confidence":0,"risk_score":0,"score_availability":{"confidence":\(available),"risk_score":\(available)}}
            """
            let value = try JSONDecoder().decode(TraderOSAIBlock.self, from: Data(json.utf8))
            let roundTrip = try JSONDecoder().decode(TraderOSAIBlock.self, from: JSONEncoder().encode(value))
            XCTAssertEqual(roundTrip.scoreAvailability?["confidence"], available)
            XCTAssertEqual(roundTrip.availableConfidence, available ? 0 : nil)
            XCTAssertEqual(MarketScorePresentation.text(roundTrip.availableConfidence), available ? "0%" : "—")
            XCTAssertEqual(roundTrip.availableRiskScore, available ? 0 : nil)
        }
    }

    func testTypedMechanicsCannotFallBackToQuoteOrMarketScores() throws {
        let json = """
        {"quote_confidence":55,"ai":{"confidence":82,"risk_score":0},
         "market_state":{"risk_score":0,"confidence_score":90},
         "multi_timeframe":{"mechanics":{"version":"market_mechanics_v1",
          "confidence":{"data_confidence":55,"analysis_confidence":null,
           "decision_confidence":null,"decision_authority":"evidence_limited"}}}}
        """
        let value = try JSONDecoder().decode(TraderOSResponse.self, from: Data(json.utf8))
        XCTAssertNil(value.availableMarketConfidence)
        XCTAssertNil(value.availableMarketRisk)
        XCTAssertNil(value.availableMarketProbability)
        XCTAssertEqual(value.multiTimeframe?.mechanics?.confidence?.data_confidence, 55)
    }

    func testLegitimateScoresAndProbabilityZero() throws {
        let json = """
        {"ai":{"confidence":80,"risk_score":0},
         "probability":{"best_probability":0,"score_availability":{"best_probability":true}}}
        """
        let value = try JSONDecoder().decode(TraderOSResponse.self, from: Data(json.utf8))
        XCTAssertEqual(value.availableMarketConfidence, 80)
        XCTAssertEqual(value.availableMarketRisk, 0)
        XCTAssertEqual(MarketScorePresentation.text(value.availableMarketProbability), "0%")
    }
    func testMissingTypedConfidenceAndExplicitVetoCannotFallBack() throws {
        let missing = try JSONDecoder().decode(TraderOSResponse.self, from: Data(#"{"ai":{"confidence":82},"multi_timeframe":{"mechanics":{"version":"market_mechanics_v1"}}}"#.utf8))
        XCTAssertNil(missing.availableMarketConfidence)
        let veto = try JSONDecoder().decode(TraderOSResponse.self, from: Data(#"{"decision":{"confidence":0,"score_availability":{"confidence":false}},"execution_plan":{"confidence":90}}"#.utf8))
        XCTAssertNil(veto.availableMarketConfidence)
    }
}
