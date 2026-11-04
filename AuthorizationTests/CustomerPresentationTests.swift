import XCTest
@testable import ChaseINGreenAuthorization

final class CustomerPresentationTests: XCTestCase {
    func testKnownMachineStatesUseExplicitHumanCopy() {
        XCTAssertEqual(CustomerPresentation.marketState("rejection_confirmed_at_level").title, "Confirmed")
        XCTAssertEqual(CustomerPresentation.tradeDecision("mixed_transition_pending"), "Wait for More Evidence")
        XCTAssertEqual(CustomerPresentation.protectionState("saved_awaiting_refresh"), "Protection Verification Pending")
        XCTAssertEqual(CustomerPresentation.patternType("double_top").title, "Double Top")
    }

    func testUnknownFallbackNeverEchoesMachineInput() {
        let raw = "future_internal_state_code"
        let values = [
            CustomerPresentation.marketState(raw).title,
            CustomerPresentation.marketReason(raw),
            CustomerPresentation.tradeDecision(raw),
            CustomerPresentation.protectionState(raw),
            CustomerPresentation.scenario(raw)
        ]
        XCTAssertTrue(values.allSatisfy { !$0.contains("_") && !$0.contains(raw) })
    }

    func testCustomerLabelsContainNoSnakeCase() {
        let values = [
            CustomerPresentation.freshness("broker_snapshot_stale"),
            CustomerPresentation.evidenceConfidence("history_unknown"),
            CustomerPresentation.readiness("dataset_not_ready")
        ]
        XCTAssertTrue(values.allSatisfy { !$0.contains("_") })
    }

    func testEveryPublicPresentationCategoryRejectsMachineLanguage() {
        let raw = "future_internal_state_code"
        let values = [
            CustomerPresentation.patternType(raw).title,
            CustomerPresentation.marketState(raw).title,
            CustomerPresentation.tradeDecision(raw), CustomerPresentation.marketReason(raw),
            CustomerPresentation.protectionState(raw), CustomerPresentation.evidenceConfidence(raw),
            CustomerPresentation.freshness(raw), CustomerPresentation.readiness(raw),
            CustomerPresentation.scenario(raw), CustomerPresentation.patternAnnotation(raw),
            CustomerPresentation.direction(raw), CustomerPresentation.regime(raw),
            CustomerPresentation.entryCondition(raw), CustomerPresentation.pathPressure(raw),
            CustomerPresentation.entrySafety(raw), CustomerPresentation.dataQuality(raw),
            CustomerPresentation.decisionAuthority(raw), CustomerPresentation.conviction(raw),
            CustomerPresentation.narrative("Wait because future_internal_state_code", fallback: "More Evidence Needed")
        ]
        XCTAssertTrue(values.allSatisfy { !$0.contains("_") && !$0.contains(raw) })
    }

    func testNarrativePreservesHumanCopyAndRejectsEmbeddedMachineTokens() {
        XCTAssertEqual(CustomerPresentation.narrative("Price is holding above support.", fallback: "Fallback"),
                       "Price is holding above support.")
        XCTAssertEqual(CustomerPresentation.narrative("Wait: mixed_transition_pending", fallback: "More Evidence Needed"),
                       "More Evidence Needed")
    }

    func testPatternVocabularyUsesIntentionalTraderLanguage() {
        let expected = [
            "shooting_star": "Shooting Star", "hammer": "Hammer",
            "bullish_engulfing": "Bullish Engulfing", "bearish_harami": "Bearish Harami",
            "morning_doji_star": "Morning Star", "three_black_crows": "Three Black Crows",
            "volume_dry_up": "Volume Drying Up", "volatility_compression": "Range Compressing",
            "no_meaningful_pattern": "No Meaningful Pattern"
        ]
        for (machine, human) in expected {
            let copy = CustomerPresentation.patternType(machine)
            XCTAssertEqual(copy.title, human)
            XCTAssertFalse(copy.title.contains("_"))
        }
        XCTAssertEqual(CustomerPresentation.patternType("future_pattern_code").title, "Market Pattern")
        XCTAssertEqual(CustomerPresentation.marketState("testing").title, "Testing a Level")
        XCTAssertEqual(CustomerPresentation.marketState("failed").title, "Pattern Failed")
    }
}
