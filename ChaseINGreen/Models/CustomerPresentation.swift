import Foundation

/// Converts machine contracts into stable customer language without changing
/// the underlying API values used for decisions, authorization, or execution.
enum CustomerPresentation {
    struct Copy: Equatable {
        let title: String
        let explanation: String?
    }

    static func patternType(_ raw: String?) -> Copy {
        switch normalized(raw) {
        case "double_top": return Copy(title: "Double Top", explanation: "Price is testing a prior resistance area.")
        case "double_bottom": return Copy(title: "Double Bottom", explanation: "Price is testing a prior support area.")
        case "head_and_shoulders": return Copy(title: "Head and Shoulders", explanation: "Price is forming a potential reversal structure.")
        case "inverse_head_and_shoulders": return Copy(title: "Inverse Head and Shoulders", explanation: "Price is forming a potential recovery structure.")
        case "rounding_top": return Copy(title: "Rounding Top", explanation: "Price is forming a gradual distribution curve.")
        case "rounding_bottom": return Copy(title: "Rounding Bottom", explanation: "Price is forming a gradual recovery curve.")
        case "cup_and_handle": return Copy(title: "Cup and Handle", explanation: "A rounded recovery is followed by a controlled pullback.")
        case "inverse_cup_and_handle": return Copy(title: "Inverse Cup and Handle", explanation: "A rounded decline is followed by a controlled rebound.")
        case "bull_flag": return Copy(title: "Bull Flag Developing", explanation: "Price is consolidating after a strong advance; continuation is not yet confirmed.")
        case "bear_flag": return Copy(title: "Bear Flag Developing", explanation: "Price is consolidating after a strong decline; continuation is not yet confirmed.")
        case "bull_pennant": return Copy(title: "Bull Pennant Developing", explanation: "Price is compressing after an advance; continuation is not yet confirmed.")
        case "bear_pennant": return Copy(title: "Bear Pennant Developing", explanation: "Price is compressing after a decline; continuation is not yet confirmed.")
        case "ascending_triangle": return Copy(title: "Ascending Triangle Developing", explanation: "Price is pressing against resistance with rising support.")
        case "descending_triangle": return Copy(title: "Descending Triangle Developing", explanation: "Price is pressing against support with falling resistance.")
        case "bullish_rectangle": return Copy(title: "Bullish Rectangle Developing", explanation: "Price is consolidating after an advance.")
        case "bearish_rectangle": return Copy(title: "Bearish Rectangle Developing", explanation: "Price is consolidating after a decline.")
        case "bullish_wedge", "bullish_triangle": return Copy(title: "Bullish Compression Developing", explanation: "Price is compressing into a potentially bullish structure.")
        case "bearish_wedge", "bearish_triangle": return Copy(title: "Bearish Compression Developing", explanation: "Price is compressing into a potentially bearish structure.")
        case "high_tight_flag": return Copy(title: "High Tight Flag Developing", explanation: "A strong advance is followed by a tight consolidation.")
        case "low_tight_flag": return Copy(title: "Low Tight Flag Developing", explanation: "A strong decline is followed by a tight consolidation.")
        case "bullish_three_push": return Copy(title: "Three-Push Advance", explanation: "Price has advanced in three distinct pushes.")
        case "bearish_three_push": return Copy(title: "Three-Push Decline", explanation: "Price has declined in three distinct pushes.")
        case "structure_pattern": return Copy(title: "Market Structure", explanation: "Price structure is being evaluated across recent candles.")
        case "resistance_rejection": return Copy(title: "Resistance Rejection", explanation: "Price tested resistance and moved away from it.")
        case "support_rejection": return Copy(title: "Support Rejection", explanation: "Price tested support and moved away from it.")
        case "breakout": return Copy(title: "Breakout", explanation: "Price moved above an established level; acceptance determines whether it holds.")
        case "breakdown": return Copy(title: "Breakdown", explanation: "Price moved below an established level; acceptance determines whether it holds.")
        case "doji": return Copy(title: "Doji", explanation: "Buyers and sellers finished this candle near balance.")
        case "long_legged_doji": return Copy(title: "Long-Legged Doji", explanation: "Price moved widely in both directions and finished near balance.")
        case "dragonfly_doji": return Copy(title: "Dragonfly Doji", explanation: "Selling pressure was rejected before the candle closed.")
        case "gravestone_doji": return Copy(title: "Gravestone Doji", explanation: "Buying pressure was rejected before the candle closed.")
        case "hammer": return Copy(title: "Hammer", explanation: "Price rejected a meaningful move lower.")
        case "inverted_hammer": return Copy(title: "Inverted Hammer", explanation: "Buyers tested higher prices after selling pressure.")
        case "hanging_man": return Copy(title: "Hanging Man", explanation: "Selling pressure appeared after an advance.")
        case "shooting_star": return Copy(title: "Shooting Star", explanation: "Price pushed higher but could not hold the move.")
        case "spinning_top": return Copy(title: "Spinning Top", explanation: "Neither side controlled the candle decisively.")
        case "bullish_marubozu", "bearish_marubozu": return Copy(title: "Strong Full-Body Candle", explanation: "Price moved decisively through most of the candle range.")
        case "long_upper_wick_rejection": return Copy(title: "Upper-Wick Rejection", explanation: "Higher prices were rejected before the close.")
        case "long_lower_wick_rejection": return Copy(title: "Lower-Wick Rejection", explanation: "Lower prices were rejected before the close.")
        case "bullish_engulfing": return Copy(title: "Bullish Engulfing", explanation: "The latest bullish body overtook the prior bearish body.")
        case "bearish_engulfing": return Copy(title: "Bearish Engulfing", explanation: "The latest bearish body overtook the prior bullish body.")
        case "bullish_harami": return Copy(title: "Bullish Harami", explanation: "A smaller bullish body formed inside the prior bearish body.")
        case "bearish_harami": return Copy(title: "Bearish Harami", explanation: "A smaller bearish body formed inside the prior bullish body.")
        case "piercing_line": return Copy(title: "Piercing Line", explanation: "Buyers recovered more than half of the prior bearish body.")
        case "dark_cloud_cover": return Copy(title: "Dark Cloud Cover", explanation: "Sellers retraced more than half of the prior bullish body.")
        case "tweezer_top": return Copy(title: "Tweezer Top", explanation: "Two candles rejected a similar high.")
        case "tweezer_bottom": return Copy(title: "Tweezer Bottom", explanation: "Two candles rejected a similar low.")
        case "inside_bar": return Copy(title: "Inside Bar", explanation: "The latest candle remained inside the prior range.")
        case "outside_bar": return Copy(title: "Outside Bar", explanation: "The latest candle expanded beyond the prior range.")
        case "morning_star", "morning_doji_star": return Copy(title: "Morning Star", explanation: "Selling pressure paused and buyers recovered part of the decline.")
        case "evening_star", "evening_doji_star": return Copy(title: "Evening Star", explanation: "Buying pressure paused and sellers retraced part of the advance.")
        case "three_white_soldiers": return Copy(title: "Three White Soldiers", explanation: "Three strong candles advanced in sequence.")
        case "three_black_crows": return Copy(title: "Three Black Crows", explanation: "Three strong candles declined in sequence.")
        case "three_inside_up", "three_outside_up": return Copy(title: "Three-Candle Bullish Reversal", explanation: "A three-candle structure shows improving buying pressure.")
        case "three_inside_down", "three_outside_down": return Copy(title: "Three-Candle Bearish Reversal", explanation: "A three-candle structure shows increasing selling pressure.")
        case "rising_three_methods": return Copy(title: "Rising Three Methods", explanation: "A controlled pause remained inside a strong advance before continuation.")
        case "falling_three_methods": return Copy(title: "Falling Three Methods", explanation: "A controlled pause remained inside a strong decline before continuation.")
        case "volume_climax": return Copy(title: "Volume Climax", explanation: "Activity is unusually high compared with recent candles.")
        case "volume_expansion": return Copy(title: "Volume Expanding", explanation: "Activity increased relative to recent candles.")
        case "volume_dry_up": return Copy(title: "Volume Drying Up", explanation: "Activity contracted relative to recent candles.")
        case "volume_divergence": return Copy(title: "Volume Divergence", explanation: "Price extended while participation weakened.")
        case "volume_evidence_unavailable": return Copy(title: "Volume Evidence Unavailable", explanation: "This provider does not supply enough trustworthy volume history.")
        case "volatility_expansion", "expansion": return Copy(title: "Range Expanding", explanation: "The latest price range is larger than recent behavior.")
        case "volatility_compression", "compression": return Copy(title: "Range Compressing", explanation: "The latest price range is smaller than recent behavior.")
        case "abnormal_wick": return Copy(title: "Unusually Large Wick", explanation: "The rejection wick is large relative to recent candle ranges.")
        case "consolidation", "range": return Copy(title: "Consolidation", explanation: "Price is moving within a contained area.")
        case "higher_high": return Copy(title: "Higher High", explanation: "Price extended above the prior high.")
        case "higher_low": return Copy(title: "Higher Low", explanation: "The latest pullback held above the prior low.")
        case "lower_high": return Copy(title: "Lower High", explanation: "The latest advance stopped below the prior high.")
        case "lower_low": return Copy(title: "Lower Low", explanation: "Price extended below the prior low.")
        case "no_meaningful_pattern": return Copy(title: "No Meaningful Pattern", explanation: "Recent candles do not support a strong named pattern.")
        default: return Copy(title: "Market Pattern", explanation: "Additional market context is being evaluated.")
        }
    }

    static func marketState(_ raw: String?) -> Copy {
        switch normalized(raw) {
        case "confirmed", "rejection_confirmed_at_level":
            return Copy(title: "Confirmed", explanation: "Closed market evidence supports this observation.")
        case "continuing": return Copy(title: "Continuing", explanation: "The observed structure remains active.")
        case "candidate", "developing", "provisional": return Copy(title: "Developing", explanation: "This observation may change as new candles close.")
        case "testing": return Copy(title: "Testing a Level", explanation: "Price is testing the structure, but confirmation is still pending.")
        case "failed": return Copy(title: "Pattern Failed", explanation: "Later price action did not support the developing structure.")
        case "invalidated", "failed_break": return Copy(title: "No Longer Active", explanation: "Later market evidence no longer supports this observation.")
        case "mixed_transition_pending", "pending", "unknown", "":
            return Copy(title: "Market State Updating", explanation: "More market evidence is needed.")
        default: return Copy(title: "Market State Updating", explanation: "Additional market context is being evaluated.")
        }
    }

    static func tradeDecision(_ raw: String?) -> String {
        switch normalized(raw) {
        case "enter", "entry_allowed", "qualified_entry": return "Entry Conditions Met"
        case "wait", "hold", "mixed_transition_pending": return "Wait for More Evidence"
        case "avoid", "blocked", "entry_blocked": return "Entry Conditions Not Met"
        case "manage", "manage_position": return "Review Open Position"
        default: return "Trade Plan Updating"
        }
    }

    static func marketReason(_ raw: String?) -> String {
        switch normalized(raw) {
        case "insufficient_closed_candles": return "More closed candles are needed."
        case "market_data_unavailable", "data_unavailable": return "Current market data is unavailable."
        case "market_data_degraded", "degraded_evidence": return "Some market evidence is delayed or incomplete."
        case "confirmation_pending", "mixed_transition_pending": return "Confirmation is still developing."
        case "risk_reward_unfavorable": return "The current reward does not justify the measured risk."
        case "entry_permission_denied", "entry_blocked": return "Current conditions do not support an entry."
        case "": return "Additional market context is being evaluated."
        default: return "Additional market context is being evaluated."
        }
    }

    static func protectionState(_ raw: String?) -> String {
        switch normalized(raw) {
        case "protected", "active", "verified": return "Protection Active"
        case "saved_awaiting_refresh", "verification_pending", "pending": return "Protection Verification Pending"
        case "manual": return "Manual Protection"
        case "unprotected", "missing": return "Protection Not Confirmed"
        default: return "Protection Status Unavailable"
        }
    }

    static func evidenceConfidence(_ raw: String?) -> String {
        switch normalized(raw) {
        case "high", "strong": return "Strong History"
        case "medium", "moderate": return "Moderate History"
        case "low", "limited": return "Limited History"
        case "unavailable", "unknown", "": return "History Unavailable"
        default: return "History Unavailable"
        }
    }

    static func freshness(_ raw: String?) -> String {
        switch normalized(raw) {
        case "fresh", "live", "current": return "Current"
        case "stale", "delayed": return "Delayed"
        case "unavailable", "unknown", "": return "Status Unavailable"
        default: return "Status Unavailable"
        }
    }

    static func readiness(_ raw: String?) -> String {
        switch normalized(raw) {
        case "ready", "sufficient": return "Research Dataset Ready"
        case "building", "limited", "insufficient": return "Research Dataset Building"
        default: return "Dataset Status Unavailable"
        }
    }

    static func scenario(_ raw: String?) -> String {
        switch normalized(raw) {
        case "bullish_breakout": return "Bullish Breakout"
        case "bearish_breakdown": return "Bearish Breakdown"
        case "range_bound", "consolidation": return "Range-Bound Market"
        case "reversal_watch": return "Potential Reversal"
        default: return "Market Scenario Updating"
        }
    }

    static func patternAnnotation(_ raw: String?) -> String {
        switch normalized(raw) {
        case "first_high", "resistance": return "Resistance"
        case "neckline", "support": return "Support"
        case "second_test": return "Second Test"
        case "second_rejection", "rejection": return "Rejection"
        case "confirmation": return "Confirmation"
        case "invalidation": return "Invalidation"
        default: return "Pattern Level"
        }
    }

    static func direction(_ raw: String?) -> String {
        switch normalized(raw) {
        case "bullish", "long", "buy", "up", "call": return "Bullish"
        case "bearish", "short", "sell", "down", "put": return "Bearish"
        case "mixed", "neutral", "sideways": return "Direction Still Developing"
        default: return "Direction Unavailable"
        }
    }

    static func regime(_ raw: String?) -> String {
        switch normalized(raw) {
        case "trending", "trend": return "Trending Market"
        case "bullish_trend": return "Bullish Trend"
        case "bearish_trend": return "Bearish Trend"
        case "range", "range_bound", "sideways", "consolidation": return "Range-Bound Market"
        case "transition", "mixed", "mixed_transition_pending": return "Market Direction Is Developing"
        default: return "Market Regime Unavailable"
        }
    }

    static func entryCondition(_ raw: String?) -> String {
        switch normalized(raw) {
        case "favorable", "entry_favorable", "safe": return "Entry Location Is Favorable"
        case "extended", "chase_risk", "pullback_risk": return "Price Is Extended; Wait for a Safer Location"
        case "confirmation_pending", "mixed_transition_pending", "wait": return "More Confirmation Is Needed"
        case "blocked", "unsafe": return "Current Entry Location Is Not Supported"
        default: return narrative(raw, fallback: "Entry Conditions Are Still Being Evaluated")
        }
    }

    static func pathPressure(_ raw: String?) -> String {
        switch normalized(raw) {
        case "favorable", "supportive", "increasing_favorable": return "Pressure Supports the Current Direction"
        case "adverse", "adverse_developing", "increasing_adverse": return "Opposing Pressure Is Increasing"
        case "mixed", "mixed_transition_pending": return "Pressure Is Mixed"
        case "stable", "neutral": return "Pressure Is Stable"
        default: return "Pressure Is Still Being Evaluated"
        }
    }

    static func entrySafety(_ raw: String?) -> String {
        switch normalized(raw) {
        case "safe", "favorable": return "Entry Location Is Supported"
        case "pullback_risk", "extended", "chase_risk": return "Wait for a Safer Entry Location"
        case "blocked", "unsafe": return "Current Entry Location Is Not Supported"
        case "mixed_transition_pending", "confirmation_pending": return "Wait for More Evidence"
        default: return "Entry Safety Is Still Being Evaluated"
        }
    }

    static func dataQuality(_ raw: String?) -> String {
        switch normalized(raw) {
        case "available", "fresh", "complete": return "Current Evidence Available"
        case "degraded", "fallback": return "Evidence Is Limited"
        case "provisional", "developing": return "Evidence Is Still Developing"
        case "stale", "delayed": return "Evidence Is Delayed"
        case "unavailable", "unknown", "": return "Evidence Unavailable"
        default: return "Evidence Status Unavailable"
        }
    }

    static func decisionAuthority(_ raw: String?) -> String {
        switch normalized(raw) {
        case "authoritative", "decision_ready": return "Decision Evidence Available"
        case "evidence_limited", "observational", "research_only": return "Observation Only — More Evidence Needed"
        case "unavailable", "unknown", "": return "Decision Evidence Unavailable"
        default: return "Decision Evidence Is Still Being Evaluated"
        }
    }

    static func conviction(_ raw: String?) -> String {
        switch normalized(raw) {
        case "high", "strong": return "Strong Evidence"
        case "medium", "moderate": return "Moderate Evidence"
        case "low", "weak": return "Limited Evidence"
        default: return "Evidence Strength Unavailable"
        }
    }

    static func narrative(_ raw: String?, fallback: String) -> String {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty, !containsMachineToken(raw) else { return fallback }
        return raw
    }

    private static func containsMachineToken(_ value: String) -> Bool {
        value.indices.contains { index in
            guard value[index] == "_", index != value.startIndex else { return false }
            let next = value.index(after: index)
            guard next != value.endIndex else { return false }
            return value[value.index(before: index)].isLetter || value[value.index(before: index)].isNumber
                ? value[next].isLetter || value[next].isNumber
                : false
        }
    }

    private static func normalized(_ raw: String?) -> String {
        (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
