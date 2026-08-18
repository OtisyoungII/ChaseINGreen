import Foundation

struct TradeIntelligenceResponse: Decodable {
    let mode: String
    let demo: IntelligenceDemoStatus
    let learningStatus: IntelligenceLearningStatus
    let recommendationPerformance: IntelligencePerformance
    let postRecommendationMovement: IntelligenceMovement
    let grouped: [String: [String: IntelligenceGroup]]
    let failureReasons: [String: IntelligenceRatio]
    let mlReadiness: IntelligenceReadiness
    let privacy: IntelligencePrivacy

    enum CodingKeys: String, CodingKey {
        case mode, demo, grouped, privacy
        case learningStatus = "learning_status"
        case recommendationPerformance = "recommendation_performance"
        case postRecommendationMovement = "post_recommendation_movement"
        case failureReasons = "failure_reasons"
        case mlReadiness = "ml_readiness"
    }
}

struct IntelligenceDemoStatus: Decodable {
    let enabled: Bool
    let label: String?
    let writesProductionData: Bool

    enum CodingKeys: String, CodingKey {
        case enabled, label
        case writesProductionData = "writes_production_data"
    }
}

struct IntelligenceLearningStatus: Decodable {
    let recommendationsRecorded: Int
    let priceObservations: Int
    let evaluatedRecommendations: Int
    let awaitingFollowUp: Int
    let sufficientFollowUp: Int
    let insufficientData: Int
    let actionableRecommendations: Int
    let userResponsesCaptured: Int
    let closedOutcomes: Int
    let firstIntelligenceEvent: String?
    let latestIntelligenceEvent: String?
    let observationCoverage: IntelligenceRatio

    enum CodingKeys: String, CodingKey {
        case recommendationsRecorded = "recommendations_recorded"
        case priceObservations = "price_observations"
        case evaluatedRecommendations = "evaluated_recommendations"
        case awaitingFollowUp = "awaiting_follow_up"
        case sufficientFollowUp = "sufficient_follow_up"
        case insufficientData = "insufficient_data"
        case actionableRecommendations = "actionable_recommendations"
        case userResponsesCaptured = "user_responses_captured"
        case closedOutcomes = "closed_outcomes"
        case firstIntelligenceEvent = "first_intelligence_event"
        case latestIntelligenceEvent = "latest_intelligence_event"
        case observationCoverage = "observation_coverage"
    }
}

struct IntelligenceRatio: Decodable {
    let count: Int
    let denominator: Int
    let percentage: Double?
}

struct IntelligenceResult: Decodable {
    let count: Int
    let percentage: Double?
}

struct IntelligencePerformance: Decodable {
    let sampleSize: Int
    let results: [String: IntelligenceResult]
    let observedHelpRate: Double?
    let observedHurtRate: Double?

    enum CodingKeys: String, CodingKey {
        case results
        case sampleSize = "sample_size"
        case observedHelpRate = "observed_help_rate"
        case observedHurtRate = "observed_hurt_rate"
    }
}

struct IntelligenceMove: Decodable {
    let averageProfitReached: Double?
    let averagePullbackPnl: Double?
    let averageTimeSeconds: Double?

    enum CodingKeys: String, CodingKey {
        case averageProfitReached = "average_profit_reached"
        case averagePullbackPnl = "average_pullback_pnl"
        case averageTimeSeconds = "average_time_seconds"
    }
}

struct IntelligenceMovement: Decodable {
    let sampleSize: Int
    let bestMoveAfterRecommendation: IntelligenceMove
    let worstMoveAfterRecommendation: IntelligenceMove
    let recovery: IntelligenceRatio
    let continuation: IntelligenceRatio
    let entryLossRecovery: IntelligenceRatio
    let profitLossRecovery: IntelligenceRatio
    let newFavorableExtreme: IntelligenceRatio

    enum CodingKeys: String, CodingKey {
        case recovery, continuation
        case sampleSize = "sample_size"
        case bestMoveAfterRecommendation = "best_move_after_recommendation"
        case worstMoveAfterRecommendation = "worst_move_after_recommendation"
        case entryLossRecovery = "entry_loss_recovery"
        case profitLossRecovery = "profit_loss_recovery"
        case newFavorableExtreme = "new_favorable_extreme"
    }
}

struct IntelligenceGroup: Decodable {
    let sampleSize: Int
    let results: [String: IntelligenceResult]
    let observedHelpRate: Double?
    let observedHurtRate: Double?
    let movement: IntelligenceMovement

    enum CodingKeys: String, CodingKey {
        case results, movement
        case sampleSize = "sample_size"
        case observedHelpRate = "observed_help_rate"
        case observedHurtRate = "observed_hurt_rate"
    }
}

struct IntelligenceReadiness: Decodable {
    let state: String
    let observationalOnly: Bool
    let productionMlEnabled: Bool
    let warnings: [String]
    let dataset: IntelligenceDataset

    enum CodingKeys: String, CodingKey {
        case state, warnings, dataset
        case observationalOnly = "observational_only"
        case productionMlEnabled = "production_ml_enabled"
    }
}

struct IntelligenceDataset: Decodable {
    let totalRecommendationEvents: Int
    let evaluableEvents: Int
    let horizonCompleteness: [String: IntelligenceRatio]
    let distinctSymbols: Int
    let distinctDirections: Int
    let distinctRecommendationTypes: Int
    let distinctMarketRegimes: Int
    let distinctSessions: Int
    let classDistribution: [String: IntelligenceResult]

    enum CodingKeys: String, CodingKey {
        case totalRecommendationEvents = "total_recommendation_events"
        case evaluableEvents = "evaluable_events"
        case horizonCompleteness = "horizon_completeness"
        case distinctSymbols = "distinct_symbols"
        case distinctDirections = "distinct_directions"
        case distinctRecommendationTypes = "distinct_recommendation_types"
        case distinctMarketRegimes = "distinct_market_regimes"
        case distinctSessions = "distinct_sessions"
        case classDistribution = "class_distribution"
    }
}

struct IntelligencePrivacy: Decodable {
    let aggregateOnly: Bool
    let privateIdentifiersIncluded: Bool
    let sharedModelExportEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case aggregateOnly = "aggregate_only"
        case privateIdentifiersIncluded = "private_identifiers_included"
        case sharedModelExportEnabled = "shared_model_export_enabled"
    }
}
