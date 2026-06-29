//
//  TraderOS.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import Foundation

struct TraderOSResponse: Codable {
    let success: Bool?
    let userId: String?
    let accountKey: String?
    let symbol: String?
    let status: String?
    let tone: String?
    let headline: String?
    let summary: String?

    let preTradeAI: TraderOSPreTradeAIBlock?
    let multiTimeframe: TraderOSMultiTimeframeBlock?
    let breakoutRetrace: TraderOSBreakoutBlock?
    let marketState: TraderOSMarketStateBlock?
    let ai: TraderOSAIBlock?
    let decision: TraderOSDecisionBlock?
    let coach: TraderOSCoachBlock?
    let probability: TraderOSProbabilityBlock?
    let executionPlan: TraderOSExecutionPlanBlock?
    let retrace: TraderOSRetraceBlock?

    let reasons: [String]?
    let warnings: [String]?
    let actions: [String]?

    enum CodingKeys: String, CodingKey {
        case success
        case userId = "user_id"
        case accountKey = "account_key"
        case symbol
        case status
        case tone
        case headline
        case summary
        case preTradeAI = "pre_trade_ai"
        case multiTimeframe = "multi_timeframe"
        case breakoutRetrace = "breakout_retrace"
        case marketState = "market_state"
        case ai
        case decision
        case coach
        case probability
        case executionPlan = "execution_plan"
        case retrace
        case reasons
        case warnings
        case actions
    }
}

struct TraderOSPreTradeAIBlock: Codable {
    let pressureSummary: String?
    let scenarioSummary: String?
    let waitUrgency: String?
    let doNotChase: Bool?
    let fakeGreenRisk: Bool?
    let downsidePressureRisk: Bool?
    let upsidePressureBuilding: Bool?
    let internalAINote: String?

    enum CodingKeys: String, CodingKey {
        case pressureSummary = "pressure_summary"
        case scenarioSummary = "scenario_summary"
        case waitUrgency = "wait_urgency"
        case doNotChase = "do_not_chase"
        case fakeGreenRisk = "fake_green_risk"
        case downsidePressureRisk = "downside_pressure_risk"
        case upsidePressureBuilding = "upside_pressure_building"
        case internalAINote = "internal_ai_note"
    }
}

struct TraderOSMultiTimeframeBlock: Codable {
    let trend4h: String?
    let trend1h: String?
    let trend15m: String?
    let trend5m: String?
    let trend1m: String?
    let aligned: Bool?
    let alignmentDirection: String?
    let alignmentScore: Int?
    let longAllowed: Bool?
    let shortAllowed: Bool?
    let entryBias: String?
    let waitReason: String?
    let riskScore: Int?
    let confidence: Int?

    enum CodingKeys: String, CodingKey {
        case trend4h = "trend_4h"
        case trend1h = "trend_1h"
        case trend15m = "trend_15m"
        case trend5m = "trend_5m"
        case trend1m = "trend_1m"
        case aligned
        case alignmentDirection = "alignment_direction"
        case alignmentScore = "alignment_score"
        case longAllowed = "long_allowed"
        case shortAllowed = "short_allowed"
        case entryBias = "entry_bias"
        case waitReason = "wait_reason"
        case riskScore = "risk_score"
        case confidence
    }
}

struct TraderOSAIBlock: Codable {
    let finalRecommendation: String?
    let confidence: Int?
    let riskScore: Int?
    let rewardScore: Int?
    let aiMode: String?
    let waitUrgency: String?
    let uiArrow: String?
    let uiColor: String?
    let showDownArrow: Bool?
    let showWaitBanner: Bool?
    let showFakeGreenWarning: Bool?
    let showWaitReady: Bool?
    let headline: String?
    let summary: String?

    enum CodingKeys: String, CodingKey {
        case finalRecommendation = "final_recommendation"
        case confidence
        case riskScore = "risk_score"
        case rewardScore = "reward_score"
        case aiMode = "ai_mode"
        case waitUrgency = "wait_urgency"
        case uiArrow = "ui_arrow"
        case uiColor = "ui_color"
        case showDownArrow = "show_down_arrow"
        case showWaitBanner = "show_wait_banner"
        case showFakeGreenWarning = "show_fake_green_warning"
        case showWaitReady = "show_wait_ready"
        case headline
        case summary
    }
}

struct TraderOSDecisionBlock: Codable {
    let decision: String?
    let confidence: Int?
    let urgency: String?
    let tone: String?
    let entryAllowed: Bool?
    let shouldWait: Bool?
    let shouldAvoid: Bool?
    let title: String?
    let explanation: String?

    enum CodingKeys: String, CodingKey {
        case decision
        case confidence
        case urgency
        case tone
        case entryAllowed = "entry_allowed"
        case shouldWait = "should_wait"
        case shouldAvoid = "should_avoid"
        case title
        case explanation
    }
}

struct TraderOSBreakoutBlock: Codable {
    let status: String?
    let action: String?
    let confidence: Int?
    let directionBias: String?
    let urgency: String?
    let uiArrow: String?
    let uiColor: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case status
        case action
        case confidence
        case directionBias = "direction_bias"
        case urgency
        case uiArrow = "ui_arrow"
        case uiColor = "ui_color"
        case message
    }
}

struct TraderOSMarketStateBlock: Codable {
    let score: Int?
    let color: String?
    let colorLabel: String?
    let colorMeaning: String?
    let phase: String?
    let tradeMode: String?
    let trendDirection: String?
    let trendQuality: String?
    let breakoutQuality: String?
    let momentumScore: Int?
    let structureScore: Int?
    let volatilityScore: Int?
    let confidenceScore: Int?
    let riskScore: Int?
    let pullbackRiskScore: Int?
    let counterMoveOpportunity: String?
    let counterMoveScore: Int?
    let supportStrength: Int?
    let resistanceStrength: Int?
    let headline: String?
    let summary: String?

    enum CodingKeys: String, CodingKey {
        case score
        case color
        case colorLabel = "color_label"
        case colorMeaning = "color_meaning"
        case phase
        case tradeMode = "trade_mode"
        case trendDirection = "trend_direction"
        case trendQuality = "trend_quality"
        case breakoutQuality = "breakout_quality"
        case momentumScore = "momentum_score"
        case structureScore = "structure_score"
        case volatilityScore = "volatility_score"
        case confidenceScore = "confidence_score"
        case riskScore = "risk_score"
        case pullbackRiskScore = "pullback_risk_score"
        case counterMoveOpportunity = "counter_move_opportunity"
        case counterMoveScore = "counter_move_score"
        case supportStrength = "support_strength"
        case resistanceStrength = "resistance_strength"
        case headline
        case summary
    }
}

struct TraderOSCoachBlock: Codable {
    let tone: String?
    let priority: String?
    let title: String?
    let message: String?
    let disciplineScore: Int?
    let patienceScore: Int?
    let riskControlScore: Int?
    let executionScore: Int?
    let summary: String?

    enum CodingKeys: String, CodingKey {
        case tone
        case priority
        case title
        case message
        case disciplineScore = "discipline_score"
        case patienceScore = "patience_score"
        case riskControlScore = "risk_control_score"
        case executionScore = "execution_score"
        case summary
    }
}

struct TraderOSProbabilityBlock: Codable {
    let bestTrade: String?
    let bestProbability: Int?
    let callProbability: Int?
    let putProbability: Int?
    let callContinuationProbability: Int?
    let putContinuationProbability: Int?
    let callBounceProbability: Int?
    let putRetraceProbability: Int?
    let waitProbability: Int?
    let waitReadyProbability: Int?
    let downsidePressureProbability: Int?
    let upsidePressureProbability: Int?
    let gapFillProbability: Int?
    let trendContinuationProbability: Int?
    let trendFailureProbability: Int?
    let fakeBreakoutProbability: Int?
    let fakeBreakdownProbability: Int?
    let reversalProbability: Int?
    let chopProbability: Int?
    let executionStyle: String?
    let tradeSizeSuggestion: String?
    let headline: String?
    let summary: String?

    enum CodingKeys: String, CodingKey {
        case bestTrade = "best_trade"
        case bestProbability = "best_probability"
        case callProbability = "call_probability"
        case putProbability = "put_probability"
        case callContinuationProbability = "call_continuation_probability"
        case putContinuationProbability = "put_continuation_probability"
        case callBounceProbability = "call_bounce_probability"
        case putRetraceProbability = "put_retrace_probability"
        case waitProbability = "wait_probability"
        case waitReadyProbability = "wait_ready_probability"
        case downsidePressureProbability = "downside_pressure_probability"
        case upsidePressureProbability = "upside_pressure_probability"
        case gapFillProbability = "gap_fill_probability"
        case trendContinuationProbability = "trend_continuation_probability"
        case trendFailureProbability = "trend_failure_probability"
        case fakeBreakoutProbability = "fake_breakout_probability"
        case fakeBreakdownProbability = "fake_breakdown_probability"
        case reversalProbability = "reversal_probability"
        case chopProbability = "chop_probability"
        case executionStyle = "execution_style"
        case tradeSizeSuggestion = "trade_size_suggestion"
        case headline
        case summary
    }
}

struct TraderOSExecutionPlanBlock: Codable {
    let shouldTrade: Bool?
    let tradeType: String?
    let side: String?
    let sizeProfile: String?
    let executionStyle: String?
    let entryCondition: String?
    let invalidation: String?
    let targetPlan: String?
    let stopPlan: String?
    let confidence: Int?
    let riskScore: Int?
    let priority: String?
    let tone: String?
    let headline: String?
    let summary: String?
    let reasons: [String]?
    let warnings: [String]?
    let actions: [String]?

    enum CodingKeys: String, CodingKey {
        case shouldTrade = "should_trade"
        case tradeType = "trade_type"
        case side
        case sizeProfile = "size_profile"
        case executionStyle = "execution_style"
        case entryCondition = "entry_condition"
        case invalidation
        case targetPlan = "target_plan"
        case stopPlan = "stop_plan"
        case confidence
        case riskScore = "risk_score"
        case priority
        case tone
        case headline
        case summary
        case reasons
        case warnings
        case actions
    }
}

struct TraderOSRetraceBlock: Codable {
    let active: Bool?
    let direction: String?
    let type: String?
    let score: Int?
    let pullbackRisk: Int?
    let continuationAfterRetrace: Int?
    let expectedMove: String?
    let sizeProfile: String?
    let entryCondition: String?
    let invalidation: String?
    let targetPlan: String?
    let headline: String?
    let summary: String?
    let reasons: [String]?
    let warnings: [String]?
    let actions: [String]?

    enum CodingKeys: String, CodingKey {
        case active
        case direction
        case type
        case score
        case pullbackRisk = "pullback_risk"
        case continuationAfterRetrace = "continuation_after_retrace"
        case expectedMove = "expected_move"
        case sizeProfile = "size_profile"
        case entryCondition = "entry_condition"
        case invalidation
        case targetPlan = "target_plan"
        case headline
        case summary
        case reasons
        case warnings
        case actions
    }
}
