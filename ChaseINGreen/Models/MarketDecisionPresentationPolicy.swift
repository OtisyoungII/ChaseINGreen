import Foundation

struct MarketRegimeAssessment: Codable {
    let symbol: String?
    let broaderTrend: String?
    let currentRegime: String?
    let entryCondition: String?
    let confidence: Int?
    let timeframeAgreement: String?
    let momentumState: String?
    let structureState: String?
    let volatilityState: String?
    let rangeState: String?
    let breakoutState: String?
    let directionalEfficiency: Double?
    let reasonCodes: [String]?
    let warnings: [String]?
    let updatedAt: String?
    let sourceFreshness: String?
    enum CodingKeys: String, CodingKey {
        case symbol, confidence, warnings
        case broaderTrend = "broader_trend", currentRegime = "current_regime", entryCondition = "entry_condition"
        case timeframeAgreement = "timeframe_agreement", momentumState = "momentum_state", structureState = "structure_state"
        case volatilityState = "volatility_state", rangeState = "range_state", breakoutState = "breakout_state"
        case directionalEfficiency = "directional_efficiency", reasonCodes = "reason_codes"
        case updatedAt = "updated_at", sourceFreshness = "source_freshness"
    }
}

struct MarketTimeframeEvidence: Codable {
    let effectiveTimeframe: String?
    let sourceTimeframe: String?
    let provider: String?
    let dataStatus: String?
    let finality: String?
    let confirmationEligible: Bool?
    let confirmationThrough: String?
    let pathDirection: String?
    let latestChangeDirection: String?
    let provisionalCount: Int?
    let fallbackUsed: Bool?
    enum CodingKeys: String, CodingKey {
        case provider, finality
        case effectiveTimeframe = "effective_timeframe", sourceTimeframe = "source_timeframe"
        case dataStatus = "data_status", confirmationEligible = "confirmation_eligible"
        case confirmationThrough = "confirmation_through", pathDirection = "path_direction"
        case latestChangeDirection = "latest_change_direction", provisionalCount = "provisional_count", fallbackUsed = "fallback_used"
    }
}

struct MarketEvidenceContext: Codable {
    let status: String?
    let confirmed: Bool?
    let confirmationThrough: String?
    let timeframes: [String: MarketTimeframeEvidence]?
    enum CodingKeys: String, CodingKey {
        case status, confirmed, timeframes
        case confirmationThrough = "confirmation_through"
    }
}

struct MarketDecisionSemantics: Codable {
    let version: String?
    let directionalThesis: String?
    let directionSource: String?
    let regimeAssessment: MarketRegimeAssessment?
    let entryQuality: String?
    let entryGrade: Int?
    let permissionSource: String?
    let entrySide: String?
    let entryAllowed: Bool?
    let shouldTrade: Bool?
    let shouldWait: Bool?
    let shouldAvoid: Bool?
    let riskScore: Int?
    let evidence: MarketEvidenceContext?
    enum CodingKeys: String, CodingKey {
        case version, evidence
        case directionalThesis = "directional_thesis", directionSource = "direction_source"
        case regimeAssessment = "regime_assessment", entryQuality = "entry_quality", entryGrade = "entry_grade"
        case permissionSource = "permission_source", entrySide = "entry_side", entryAllowed = "entry_allowed"
        case shouldTrade = "should_trade", shouldWait = "should_wait", shouldAvoid = "should_avoid", riskScore = "risk_score"
    }
}

/// Presentation only. This policy never authorizes broker execution.
struct MarketDecisionPresentationPolicy {
    enum Direction: String { case bullish, bearish, mixed, unknown }
    struct Presentation {
        let direction: Direction
        let action: String
        let entryQuality: String
        let regime: String
        let entryCondition: String
        let evidenceStatus: String
        let confirmationThrough: String?
        let entryConfirmed: Bool
    }
    static func direction(_ value: String?) -> Direction {
        switch value?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "bullish", "long", "buy", "up", "call": return .bullish
        case "bearish", "short", "sell", "down", "put": return .bearish
        case "mixed", "neutral", "sideways": return .mixed
        default: return .unknown
        }
    }
    static func preTrade(_ value: PreTradeContextResponse) -> Presentation {
        project(value.marketSemantics, legacyDirection: value.directionSignal,
                quality: value.setupQuality, allowed: value.canEnter, trade: nil,
                wait: !value.canEnter, avoid: nil, side: value.setupBias, requiresPlan: false)
    }
    static func traderOS(_ value: TraderOSResponse?) -> Presentation {
        project(value?.marketSemantics,
                legacyDirection: value?.marketState?.regimeAssessment?.broaderTrend ?? value?.marketState?.trendDirection,
                quality: nil, allowed: value?.decision?.entryAllowed, trade: value?.executionPlan?.shouldTrade,
                wait: value?.decision?.shouldWait, avoid: value?.decision?.shouldAvoid,
                side: value?.executionPlan?.side, requiresPlan: true,
                legacyRegime: value?.marketState?.regimeAssessment)
    }
    private static func validTimestamp(_ value: String?) -> Bool {
        guard let value else { return false }
        let formatter = ISO8601DateFormatter()
        if formatter.date(from: value) != nil { return true }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: value) != nil
    }
    private static func project(_ semantics: MarketDecisionSemantics?, legacyDirection: String?,
                                quality: String?, allowed: Bool?, trade: Bool?, wait: Bool?, avoid: Bool?,
                                side: String?, requiresPlan: Bool, legacyRegime: MarketRegimeAssessment? = nil) -> Presentation {
        let s = semantics?.version == "market_semantics_v1" ? semantics : nil
        let thesis = direction(s?.directionalThesis ?? legacyDirection)
        let evidence = s?.evidence
        let confirmed = evidence?.confirmed == true && evidence?.status == "available"
            && validTimestamp(evidence?.confirmationThrough)
        let sideDirection = direction(side)
        let conflict = (requiresPlan && allowed != nil && trade != nil && allowed != trade)
            || (s?.entryAllowed != nil && s?.entryAllowed != allowed)
            || (requiresPlan && s?.shouldTrade != nil && s?.shouldTrade != trade)
            || (s?.entrySide != nil && direction(s?.entrySide) != sideDirection)
            || (allowed == true && (wait == true || avoid == true || s?.shouldWait == true || s?.shouldAvoid == true))
        var action = "WAIT"
        var entryConfirmed = false
        if conflict { action = "WAIT — DECISION / PLAN CONFLICT" }
        else if avoid == true || s?.shouldAvoid == true { action = "NEW ENTRY BLOCKED" }
        else if allowed == true && (!requiresPlan || trade == true) {
            if !confirmed { action = "NO CONFIRMED ACTION" }
            else if sideDirection == .bullish { action = "LONG ENTRY WATCH"; entryConfirmed = true }
            else if sideDirection == .bearish { action = "SHORT ENTRY WATCH"; entryConfirmed = true }
            else { action = "NO CONFIRMED ACTION" }
        } else if allowed == nil { action = "NO CONFIRMED ACTION" }
        return Presentation(direction: thesis, action: action,
                            entryQuality: s?.entryQuality ?? quality ?? "unavailable",
                            regime: s?.regimeAssessment?.currentRegime ?? legacyRegime?.currentRegime ?? "unknown",
                            entryCondition: s?.regimeAssessment?.entryCondition ?? legacyRegime?.entryCondition ?? "unavailable",
                            evidenceStatus: evidence?.status ?? "unknown",
                            confirmationThrough: evidence?.confirmationThrough,
                            entryConfirmed: entryConfirmed)
    }
}
