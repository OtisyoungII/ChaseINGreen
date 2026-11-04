import XCTest
@testable import ChaseINGreenAuthorization

final class MarketIntelligenceEducationTests: XCTestCase {
    private let detectedIdentifiers: Set<String> = [
        "doji", "long_legged_doji", "dragonfly_doji", "gravestone_doji",
        "hammer", "inverted_hammer", "hanging_man", "shooting_star", "spinning_top",
        "bullish_marubozu", "bearish_marubozu", "long_upper_wick_rejection", "long_lower_wick_rejection",
        "bullish_engulfing", "bearish_engulfing", "bullish_harami", "bearish_harami",
        "piercing_line", "dark_cloud_cover", "tweezer_top", "tweezer_bottom", "inside_bar", "outside_bar",
        "morning_star", "evening_star", "morning_doji_star", "evening_doji_star",
        "three_white_soldiers", "three_black_crows", "three_inside_up", "three_inside_down",
        "three_outside_up", "three_outside_down", "rising_three_methods", "falling_three_methods",
        "double_top", "double_bottom", "breakout", "breakdown", "resistance_rejection", "support_rejection",
        "expansion", "compression", "consolidation", "higher_high", "higher_low", "lower_high", "lower_low",
        "volume_climax", "volume_expansion", "volume_dry_up", "volume_divergence", "volume_evidence_unavailable",
        "volatility_expansion", "volatility_compression", "abnormal_wick", "no_meaningful_pattern"
    ]

    func testEveryImplementedDetectorConceptHasEducation() {
        XCTAssertEqual(MarketIntelligenceEducation.implementedCustomerVisibleIdentifiers, detectedIdentifiers)
        for identifier in detectedIdentifiers {
            let value = MarketIntelligenceEducation.explanation(for: identifier)
            XCTAssertNotNil(value, identifier)
            XCTAssertFalse(value?.displayName.contains("_") ?? true)
            XCTAssertFalse(value?.definition.isEmpty ?? true)
            XCTAssertFalse(value?.typicalInterpretation.isEmpty ?? true)
        }
    }

    func testUnknownIdentifierFailsClosedWithoutInventedCopy() {
        XCTAssertNil(MarketIntelligenceEducation.explanation(for: "unknown_pattern_name"))
    }

    func testEducationNeverClaimsAutomaticTradingAuthority() {
        for identifier in detectedIdentifiers {
            let value = try! XCTUnwrap(MarketIntelligenceEducation.explanation(for: identifier))
            let text = [value.definition, value.typicalInterpretation, value.caution,
                        value.confirmation ?? "", value.invalidation ?? ""].joined(separator: " ").lowercased()
            XCTAssertFalse(text.contains("buy signal"), identifier)
            XCTAssertFalse(text.contains("sell signal"), identifier)
            XCTAssertTrue(value.caution.contains("not an automatic trade signal"), identifier)
        }
    }

    func testContextUsesOnlySuppliedAuthorityAndAvailability() {
        let developing = MarketIntelligenceEducation.Context(
            state: "confirmed", finality: "closed", dataStatus: "degraded", isAuthoritativeEvidence: false
        )
        XCTAssertEqual(developing.whyItMattersHere,
                       "Chase is treating this as developing or limited evidence that may change with later market data.")
        let authoritative = MarketIntelligenceEducation.Context(
            state: "confirmed", finality: "closed", dataStatus: "available", isAuthoritativeEvidence: true
        )
        XCTAssertEqual(authoritative.whyItMattersHere,
                       "Chase observed this pattern in closed, available market data for the selected timeframe.")
    }
}
