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
    let liveMonitor: TraderOSLiveMonitorBlock?
    let breakoutRetrace: TraderOSBreakoutBlock?
    let marketState: TraderOSMarketStateBlock?
    let ai: TraderOSAIBlock?
    let decision: TraderOSDecisionBlock?
    let coach: TraderOSCoachBlock?
    let probability: TraderOSProbabilityBlock?
    let executionPlan: TraderOSExecutionPlanBlock?
    let retrace: TraderOSRetraceBlock?
    let quoteResolution: TraderOSQuoteResolutionBlock?
    let execution: TraderOSExecutionContext?
    let quoteSource: String?
    let quoteFreshness: String?
    let quoteConfidence: Int?

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
        case liveMonitor = "live_monitor"
        case breakoutRetrace = "breakout_retrace"
        case marketState = "market_state"
        case ai
        case decision
        case coach
        case probability
        case executionPlan = "execution_plan"
        case retrace
        case quoteResolution = "quote_resolution"
        case execution
        case quoteSource = "quote_source"
        case quoteFreshness = "quote_freshness"
        case quoteConfidence = "quote_confidence"
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

    let supportZoneLow: Double?
    let supportZoneHigh: Double?
    let resistanceZoneLow: Double?
    let resistanceZoneHigh: Double?
    let breakoutAbove: Double?
    let breakdownBelow: Double?
    let longStopIdea: Double?
    let shortStopIdea: Double?
    let longProfitTarget1: Double?
    let longProfitTarget2: Double?
    let shortProfitTarget1: Double?
    let shortProfitTarget2: Double?
    let beginnerSupportLabel: String?
    let beginnerResistanceLabel: String?
    let beginnerBreakoutLabel: String?
    let beginnerBreakdownLabel: String?
    let executionNote: String?

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

        case supportZoneLow = "support_zone_low"
        case supportZoneHigh = "support_zone_high"
        case resistanceZoneLow = "resistance_zone_low"
        case resistanceZoneHigh = "resistance_zone_high"
        case breakoutAbove = "breakout_above"
        case breakdownBelow = "breakdown_below"
        case longStopIdea = "long_stop_idea"
        case shortStopIdea = "short_stop_idea"
        case longProfitTarget1 = "long_profit_target_1"
        case longProfitTarget2 = "long_profit_target_2"
        case shortProfitTarget1 = "short_profit_target_1"
        case shortProfitTarget2 = "short_profit_target_2"
        case beginnerSupportLabel = "beginner_support_label"
        case beginnerResistanceLabel = "beginner_resistance_label"
        case beginnerBreakoutLabel = "beginner_breakout_label"
        case beginnerBreakdownLabel = "beginner_breakdown_label"
        case executionNote = "execution_note"

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
struct TraderOSQuoteResolutionBlock: Codable {
    let symbol: String?
    let requestedSymbol: String?
    let provider: String?
    let broker: String?

    let price: Double?
    let bid: Double?
    let ask: Double?

    let openPrice: Double?
    let high: Double?
    let low: Double?
    let previousClose: Double?
    let percentChange: Double?

    let freshness: String?
    let confidence: Int?
    let sourceRank: Int?
    let warning: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case requestedSymbol = "requested_symbol"
        case provider
        case broker
        case price
        case bid
        case ask
        case openPrice = "open_price"
        case high
        case low
        case previousClose = "previous_close"
        case percentChange = "percent_change"
        case freshness
        case confidence
        case sourceRank = "source_rank"
        case warning
    }
}
struct TraderOSLiveMonitorBlock: Codable {
    let tone: String?
    let summary: String?
    let totalOpenTrades: Int?
    let highPriorityTrades: Int?
    let trades: [TraderOSLiveMonitorTrade]?

    enum CodingKeys: String, CodingKey {
        case tone
        case summary
        case totalOpenTrades = "total_open_trades"
        case highPriorityTrades = "high_priority_trades"
        case trades
    }
}

struct TraderOSLiveMonitorTrade: Codable {
    let tradeId: String?
    let symbol: String?
    let recommendation: String?
    let confidence: Int?
    let urgency: String?
    let managementTone: String?
    let headline: String?
    let summary: String?
    let currentPrice: Double?
    let closePercent: Int?
    let scaleOutPercent: Int?

    enum CodingKeys: String, CodingKey {
        case tradeId = "trade_id"
        case symbol
        case recommendation
        case confidence
        case urgency
        case managementTone = "management_tone"
        case headline
        case summary
        case currentPrice = "current_price"
        case closePercent = "close_percent"
        case scaleOutPercent = "scale_out_percent"
    }
}
struct TraderOSExecutionContext: Codable {
    let success: Bool?
    let mode: String?
    let message: String?
    let portfolioAI: PortfolioAIResponse?
    let selection: AccountSelectionResponse?
    let approval: ExecutionApprovalContext?
    let route: ExecutionRouteContext?

    enum CodingKeys: String, CodingKey {
        case success
        case mode
        case message
        case portfolioAI = "portfolio_ai"
        case selection
        case approval
        case route
    }
}

struct ExecutionApprovalContext: Codable {
    let symbol: String?
    let side: String?
    let quantity: Double?
    let approved: Bool?
    let autoExecutionAllowed: Bool?
    let accountId: String?
    let accountName: String?
    let broker: String?
    let accountClass: String?
    let approvalStatus: String?
    let confidence: Int?
    let riskScore: Int?
    let headline: String?
    let summary: String?
    let reasons: [String]?
    let warnings: [String]?
    let actions: [String]?

    enum CodingKeys: String, CodingKey {
        case symbol
        case side
        case quantity
        case approved
        case autoExecutionAllowed = "auto_execution_allowed"
        case accountId = "account_id"
        case accountName = "account_name"
        case broker
        case accountClass = "account_class"
        case approvalStatus = "approval_status"
        case confidence
        case riskScore = "risk_score"
        case headline
        case summary
        case reasons
        case warnings
        case actions
    }
}

struct ExecutionRouteContext: Codable {
    let symbol: String?
    let side: String?
    let quantity: Double?
    let orderType: String?
    let approvedForRouting: Bool?
    let approvedForAutoExecution: Bool?
    let broker: String?
    let provider: String?
    let accountId: String?
    let accountName: String?
    let accountClass: String?
    let routeStatus: String?
    let confidence: Int?
    let riskScore: Int?
    let headline: String?
    let summary: String?
    let reasons: [String]?
    let warnings: [String]?
    let actions: [String]?

    enum CodingKeys: String, CodingKey {
        case symbol
        case side
        case quantity
        case orderType = "order_type"
        case approvedForRouting = "approved_for_routing"
        case approvedForAutoExecution = "approved_for_auto_execution"
        case broker
        case provider
        case accountId = "account_id"
        case accountName = "account_name"
        case accountClass = "account_class"
        case routeStatus = "route_status"
        case confidence
        case riskScore = "risk_score"
        case headline
        case summary
        case reasons
        case warnings
        case actions
    }
}
