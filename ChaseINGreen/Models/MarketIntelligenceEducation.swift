import Foundation

/// Educational copy for observations produced by the existing market-pattern engine.
/// This registry never evaluates candles or grants decision authority.
struct MarketIntelligenceEducation: Equatable, Identifiable {
    enum Family: String, Equatable {
        case candlestick = "Candlestick"
        case structure = "Market Structure"
        case volume = "Volume"
        case volatility = "Volatility"
    }

    struct Context: Equatable {
        let state: String
        let finality: String
        let dataStatus: String
        let isAuthoritativeEvidence: Bool

        var whyItMattersHere: String? {
            if isAuthoritativeEvidence {
                return "Chase observed this pattern in closed, available market data for the selected timeframe."
            }
            if finality != "closed" || dataStatus != "available" || state == "developing" {
                return "Chase is treating this as developing or limited evidence that may change with later market data."
            }
            return nil
        }
    }

    let id: String
    let displayName: String
    let family: Family
    let definition: String
    let typicalInterpretation: String
    let caution: String
    let confirmation: String?
    let invalidation: String?

    static func explanation(for identifier: String?) -> MarketIntelligenceEducation? {
        guard let identifier else { return nil }
        return registry[identifier.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)]
    }

    static let implementedCustomerVisibleIdentifiers: Set<String> = Set(registry.keys)

    private static func item(
        _ id: String, _ name: String, _ family: Family, _ definition: String,
        _ interpretation: String, confirmation: String? = nil, invalidation: String? = nil
    ) -> MarketIntelligenceEducation {
        .init(id: id, displayName: name, family: family, definition: definition,
              typicalInterpretation: interpretation,
              caution: "This is market evidence, not an automatic trade signal.",
              confirmation: confirmation, invalidation: invalidation)
    }

    private static let registry: [String: MarketIntelligenceEducation] = {
        let candle: [(String, String, String, String)] = [
            ("doji", "Doji", "A candle whose open and close are very close together.", "Neither buyers nor sellers clearly controlled the close."),
            ("long_legged_doji", "Long-Legged Doji", "A near-balance close after wide movement in both directions.", "Strong two-way movement ended without clear control."),
            ("dragonfly_doji", "Dragonfly Doji", "A near-balance close with a long lower wick.", "Lower prices were rejected before the candle closed."),
            ("gravestone_doji", "Gravestone Doji", "A near-balance close with a long upper wick.", "Higher prices were rejected before the candle closed."),
            ("hammer", "Hammer", "A small body with a long lower wick.", "Price rejected a meaningful move lower; location and follow-through determine significance."),
            ("inverted_hammer", "Inverted Hammer", "A small body with a long upper wick after declining prices.", "Buyers tested higher prices, but follow-through is still needed."),
            ("hanging_man", "Hanging Man", "A small body with a long lower wick after advancing prices.", "Selling pressure appeared during an advance, without independently proving reversal."),
            ("shooting_star", "Shooting Star", "A small body with a long upper wick after advancing prices.", "Higher prices were rejected, without independently proving bearish reversal."),
            ("spinning_top", "Spinning Top", "A small body with wicks on both sides.", "Neither side controlled the candle decisively."),
            ("bullish_marubozu", "Bullish Marubozu", "A strong bullish body with little or no wick.", "Buyers controlled most of the candle period."),
            ("bearish_marubozu", "Bearish Marubozu", "A strong bearish body with little or no wick.", "Sellers controlled most of the candle period."),
            ("long_upper_wick_rejection", "Upper-Wick Rejection", "A candle with an unusually dominant upper wick.", "Higher prices were rejected before the close."),
            ("long_lower_wick_rejection", "Lower-Wick Rejection", "A candle with an unusually dominant lower wick.", "Lower prices were rejected before the close."),
            ("bullish_engulfing", "Bullish Engulfing", "A bullish body that surrounds the prior bearish body.", "Buying responded more strongly than in the prior candle; location and follow-through matter."),
            ("bearish_engulfing", "Bearish Engulfing", "A bearish body that surrounds the prior bullish body.", "Selling responded more strongly than in the prior candle; location and follow-through matter."),
            ("bullish_harami", "Bullish Harami", "A smaller bullish body inside the prior bearish body.", "Selling momentum paused and buying pressure appeared."),
            ("bearish_harami", "Bearish Harami", "A smaller bearish body inside the prior bullish body.", "Buying momentum paused and selling pressure appeared."),
            ("piercing_line", "Piercing Line", "A bullish candle that recovers more than half of the prior bearish body.", "Buyers reclaimed a meaningful part of the prior decline."),
            ("dark_cloud_cover", "Dark Cloud Cover", "A bearish candle that retraces more than half of the prior bullish body.", "Sellers reclaimed a meaningful part of the prior advance."),
            ("tweezer_top", "Tweezer Top", "Two candles that reject a similar high.", "A price area resisted two nearby attempts."),
            ("tweezer_bottom", "Tweezer Bottom", "Two candles that reject a similar low.", "A price area supported two nearby attempts."),
            ("inside_bar", "Inside Bar", "A candle contained within the prior candle's range.", "Price range contracted and direction remains unresolved."),
            ("outside_bar", "Outside Bar", "A candle that extends beyond both sides of the prior range.", "Price expanded sharply in both range and participation."),
            ("morning_star", "Morning Star", "A three-candle sequence where selling pauses and buyers recover.", "Buying pressure improved after a decline."),
            ("evening_star", "Evening Star", "A three-candle sequence where buying pauses and sellers respond.", "Selling pressure increased after an advance."),
            ("morning_doji_star", "Morning Doji Star", "A Morning Star sequence with a near-balance middle candle.", "Indecision during a decline was followed by buying recovery."),
            ("evening_doji_star", "Evening Doji Star", "An Evening Star sequence with a near-balance middle candle.", "Indecision during an advance was followed by selling pressure."),
            ("three_white_soldiers", "Three White Soldiers", "Three strong bullish candles advancing in sequence.", "Buying persisted across several candles, though extension risk may remain."),
            ("three_black_crows", "Three Black Crows", "Three strong bearish candles declining in sequence.", "Selling persisted across several candles, though extension risk may remain."),
            ("three_inside_up", "Three Inside Up", "An inside-body pause followed by a bullish recovery candle.", "Buying follow-through improved after a bearish move."),
            ("three_inside_down", "Three Inside Down", "An inside-body pause followed by a bearish decline candle.", "Selling follow-through increased after a bullish move."),
            ("three_outside_up", "Three Outside Up", "A bullish outside response followed by another higher close.", "Buying strength persisted after overtaking the prior range."),
            ("three_outside_down", "Three Outside Down", "A bearish outside response followed by another lower close.", "Selling strength persisted after overtaking the prior range."),
            ("rising_three_methods", "Rising Three Methods", "A strong advance, contained pause, and renewed move higher.", "The pause remained contained before bullish continuation."),
            ("falling_three_methods", "Falling Three Methods", "A strong decline, contained pause, and renewed move lower.", "The pause remained contained before bearish continuation."),
            ("no_meaningful_pattern", "No Meaningful Pattern", "Recent candles do not meet a named-pattern rule.", "Chase is avoiding a stronger label when the evidence is weak.")
        ]
        var values = Dictionary(uniqueKeysWithValues: candle.map {
            ($0.0, item($0.0, $0.1, .candlestick, $0.2, $0.3,
                      confirmation: "Later closed candles and surrounding structure can strengthen the observation.",
                      invalidation: "Contrary follow-through or a changed structure can weaken it."))
        })
        let others: [MarketIntelligenceEducation] = [
            item("double_top", "Double Top", .structure, "Two tests of a similar resistance area separated by a pullback.", "Repeated resistance can warn of weakening upside pressure, but two highs alone are not confirmation.", confirmation: "The existing lifecycle requires confirmed acceptance through the neckline.", invalidation: "A sustained reclaim above resistance weakens or invalidates the structure."),
            item("double_bottom", "Double Bottom", .structure, "Two tests of a similar support area separated by a rally.", "Repeated support can show improving demand, but two lows alone are not confirmation.", confirmation: "The existing lifecycle requires confirmed acceptance above the neckline.", invalidation: "A sustained break below support weakens or invalidates the structure."),
            item("breakout", "Breakout", .structure, "Price moved above an established level.", "The move matters only if price gains acceptance above that level.", confirmation: "Persistent closed evidence above the level strengthens acceptance.", invalidation: "A failed hold or reclaim below the level weakens the breakout."),
            item("breakdown", "Breakdown", .structure, "Price moved below an established level.", "The move matters only if price gains acceptance below that level.", confirmation: "Persistent closed evidence below the level strengthens acceptance.", invalidation: "A failed hold or reclaim above the level weakens the breakdown."),
            item("resistance_rejection", "Resistance Rejection", .structure, "Price tested resistance and moved away from it.", "The rejection is observational and does not independently establish a reversal."),
            item("support_rejection", "Support Rejection", .structure, "Price tested support and moved away from it.", "The rejection is observational and does not independently establish a reversal."),
            item("expansion", "Range Expansion", .structure, "The latest range is materially larger than recent ranges.", "Movement increased, while direction and durability still depend on context."),
            item("compression", "Compression", .structure, "Recent price range contracted relative to normal behavior.", "Energy is contracting; compression alone does not predict expansion direction."),
            item("consolidation", "Consolidation", .structure, "Price is moving inside a contained recent area.", "Neither side has established a durable move outside the range."),
            item("higher_high", "Higher High", .structure, "Price extended above the prior high.", "This supports bullish structure only when the surrounding sequence agrees."),
            item("higher_low", "Higher Low", .structure, "A pullback held above the prior low.", "This supports bullish structure only in appropriate structural context."),
            item("lower_high", "Lower High", .structure, "An advance stopped below the prior high.", "This supports bearish structure only when the surrounding sequence agrees."),
            item("lower_low", "Lower Low", .structure, "Price extended below the prior low.", "This supports bearish structure only when the surrounding sequence agrees."),
            item("volume_climax", "Volume Climax", .volume, "Participation is unusually high compared with recent candles.", "It can accompany continuation or exhaustion; price context determines which."),
            item("volume_expansion", "Volume Expansion", .volume, "Participation increased relative to recent candles.", "Stronger participation can support the current move but does not establish direction by itself."),
            item("volume_dry_up", "Volume Dry-Up", .volume, "Participation contracted relative to recent candles.", "Lower participation can occur during pauses, consolidation, or weakening conviction."),
            item("volume_divergence", "Volume Divergence", .volume, "Price extended while participation weakened.", "The move has less participation, but divergence alone does not time a reversal."),
            item("volume_evidence_unavailable", "Volume Evidence Unavailable", .volume, "The provider lacks enough trustworthy volume history.", "Chase is withholding a volume conclusion rather than substituting unreliable evidence."),
            item("volatility_expansion", "Volatility Expansion", .volatility, "The latest candle range is much larger than recent ranges.", "Movement intensity increased; direction still comes from separate evidence."),
            item("volatility_compression", "Volatility Compression", .volatility, "The latest candle range is much smaller than recent ranges.", "Range contraction does not predict the direction of a later expansion."),
            item("abnormal_wick", "Abnormal Wick", .volatility, "A rejection wick is unusually large relative to recent ranges.", "The candle shows rejection, but later closed evidence determines whether it matters.")
        ]
        for value in others { values[value.id] = value }
        return values
    }()
}
