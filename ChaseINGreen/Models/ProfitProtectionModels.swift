import Foundation

struct ProfitProtectionSettings: Codable {
    var givebackWarningPercent: Double
    var minimumProfitBeforeProtection: Double
    var preferredProfitLockPercent: Double
    var aggressiveness: String
    var autoRaiseEnabled: Bool
    var protectionMode: String?

    enum CodingKeys: String, CodingKey {
        case aggressiveness
        case givebackWarningPercent = "giveback_warning_percent"
        case minimumProfitBeforeProtection = "minimum_profit_before_protection"
        case preferredProfitLockPercent = "preferred_profit_lock_percent"
        case autoRaiseEnabled = "auto_raise_enabled"
        case protectionMode = "protection_mode"
    }
}

struct ProfitProtectionRecommendationRequest: Encodable {
    let tradeId: UUID
    let currentPrice: Double?
    let currentPnl: Double?
    let peakProfit: Double?

    enum CodingKeys: String, CodingKey {
        case tradeId = "trade_id"
        case currentPrice = "current_price"
        case currentPnl = "current_pnl"
        case peakProfit = "peak_profit"
    }
}

struct ProfitProtectionRecommendationResponse: Decodable {
    let eventId: UUID
    let recommendation: ProfitProtectionRecommendation
    let shadowIntelligence: ProtectionShadowIntelligence
    let disclaimer: String

    enum CodingKeys: String, CodingKey {
        case recommendation, disclaimer
        case eventId = "event_id"
        case shadowIntelligence = "shadow_intelligence"
    }
}

struct ProfitProtectionRecommendation: Decodable {
    let protectionState: String
    let currentProtection: Double?
    let recommendedProtection: Double
    let why: [String]
    let bestProfitReached: Double
    let currentProfit: Double
    let profitGivenBack: Double
    let profitGivenBackPercent: Double
    let profitLockedIfHit: Double?
    let profitLockedIsApproximate: Bool
    let distanceFromCurrentPrice: Double
    let protectionUrgency: String
    let confidence: Double
    let targetIntelligence: String
    let actionable: Bool?
    let breakEvenEarned: Bool?
    let earnedDistanceRequired: Double?
    let protectionMode: String?

    enum CodingKeys: String, CodingKey {
        case why, confidence
        case protectionState = "protection_state"
        case currentProtection = "current_protection"
        case recommendedProtection = "recommended_protection"
        case bestProfitReached = "best_profit_reached"
        case currentProfit = "current_profit"
        case profitGivenBack = "profit_given_back"
        case profitGivenBackPercent = "profit_given_back_percent"
        case profitLockedIfHit = "profit_locked_if_hit"
        case profitLockedIsApproximate = "profit_locked_is_approximate"
        case distanceFromCurrentPrice = "distance_from_current_price"
        case protectionUrgency = "protection_urgency"
        case targetIntelligence = "target_intelligence"
        case actionable
        case breakEvenEarned = "break_even_earned"
        case earnedDistanceRequired = "earned_distance_required"
        case protectionMode = "protection_mode"
    }
}

struct ProtectionShadowIntelligence: Decodable {
    let prediction: String
    let modelConfidence: Double
    let historicalExperience: String
    let sampleSize: Int
    let supportingFactors: [String]
    let conflictingFactors: [String]
    let noveltyReasons: [String]
    let shadowOnly: Bool

    enum CodingKeys: String, CodingKey {
        case prediction
        case modelConfidence = "model_confidence"
        case historicalExperience = "historical_experience"
        case sampleSize = "sample_size"
        case supportingFactors = "supporting_factors"
        case conflictingFactors = "conflicting_factors"
        case noveltyReasons = "novelty_reasons"
        case shadowOnly = "shadow_only"
    }
}

struct ProfitProtectionAdminStatistics: Decodable {
    let sampleSize: Int
    let lifecycle: [String: Int]
    let protectionStates: [String: Int]
    let outcomes: [String: Int]
    let performance: [String: Double]

    enum CodingKeys: String, CodingKey {
        case lifecycle, outcomes, performance
        case sampleSize = "sample_size"
        case protectionStates = "protection_states"
    }
}

struct EntryAuditStatistics: Decodable {
    let evaluated: Int
    let decisions: [String: Int]
    let actionableRate: Double
    let entryRarityWarning: Bool
    let topBlockers: [EntryAuditBlocker]
    let shadow: EntryAuditShadow

    enum CodingKeys: String, CodingKey {
        case evaluated, decisions, shadow
        case actionableRate = "actionable_rate"
        case entryRarityWarning = "entry_rarity_warning"
        case topBlockers = "top_blockers"
    }
}

struct EntryAuditBlocker: Decodable, Identifiable {
    let blocker: String
    let encountered: Int
    let decisiveVeto: Int
    let evaluated: Int
    let subsequentFavorableRate: Double?
    let subsequentAdverseRate: Double?
    var id: String { blocker }

    enum CodingKeys: String, CodingKey {
        case blocker, encountered, evaluated
        case decisiveVeto = "decisive_veto"
        case subsequentFavorableRate = "subsequent_favorable_rate"
        case subsequentAdverseRate = "subsequent_adverse_rate"
    }
}

struct EntryAuditShadow: Decodable {
    let sampleSize: Int
    let disagreements: Int
    let agreementRate: Double?

    enum CodingKeys: String, CodingKey {
        case disagreements
        case sampleSize = "sample_size"
        case agreementRate = "agreement_rate"
    }
}
