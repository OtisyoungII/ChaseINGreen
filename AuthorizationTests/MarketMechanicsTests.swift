import Foundation
import XCTest
@testable import ChaseINGreenAuthorization

final class MarketMechanicsTests: XCTestCase {
    func testDynamicCollectionAndIndependentConfidenceDecode() throws {
        let payload: [String: Any] = [
            "confidence": 82,
            "mechanics": [
                "version": "market_mechanics_v1",
                "timeframes": ["1w", "1d", "4h", "1h", "30m", "15m", "5m", "1m"].map {
                    ["timeframe": $0, "direction": "bearish", "quality": "degraded"]
                },
                "primary_directional_structure": "bearish",
                "entry_safety": "unknown", "long_permission": false, "short_permission": false,
                "confidence": ["data_quality": "degraded", "data_confidence": 55,
                               "decision_authority": "evidence_limited"]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let value = try JSONDecoder().decode(TraderOSMultiTimeframeBlock.self, from: data)
        XCTAssertEqual(value.mechanics?.timeframes?.count, 8)
        XCTAssertEqual(value.mechanics?.confidence?.data_confidence, 55)
        XCTAssertNil(value.mechanics?.confidence?.decision_confidence)
        XCTAssertEqual(value.mechanics?.long_permission, false)
    }

    func testLegacyPayloadRemainsDecodableWithoutInventingMechanics() throws {
        let value = try JSONDecoder().decode(TraderOSMultiTimeframeBlock.self, from: Data("{\"trend_4h\":\"bullish\",\"confidence\":82}".utf8))
        XCTAssertEqual(value.trend4h, "bullish")
        XCTAssertNil(value.mechanics)
    }

    func testMechanicsBlockDoesNotBecomeGreenFromLegacyPermission() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "market_decision_contract", withExtension: "json", subdirectory: "Fixtures"))
        let rows = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
        let fixture = try XCTUnwrap(rows.first { ($0["name"] as? String) == "long_vocabulary" })
        var pretrade = try XCTUnwrap(fixture["pre_trade"] as? [String: Any])
        var semantics = try XCTUnwrap(pretrade["market_semantics"] as? [String: Any])
        semantics["mechanics"] = ["version": "market_mechanics_v1", "entry_safety": "pullback_risk", "long_permission": false, "short_permission": false]
        pretrade["market_semantics"] = semantics
        let decoded = try JSONDecoder().decode(PreTradeContextResponse.self, from: JSONSerialization.data(withJSONObject: pretrade))
        let value = MarketDecisionPresentationPolicy.preTrade(decoded)
        XCTAssertEqual(value.direction, .bullish)
        XCTAssertFalse(value.entryConfirmed)
        XCTAssertTrue(value.action.contains("PULLBACK RISK"))
    }
}
