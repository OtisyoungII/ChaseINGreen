//
//  TradeOpportunityModels.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/24/26.
//

import Foundation

struct TradeOpportunityRequest: Codable {
    let symbol: String
    let direction: String?
    let broker: String?
    let accountKey: String?
    let startingBalance: Double?
    let currentBalance: Double?
    let targetBalance: Double?
    let averageDailyProfit: Double?

    enum CodingKeys: String, CodingKey {
        case symbol, direction, broker
        case accountKey = "account_key"
        case startingBalance = "starting_balance"
        case currentBalance = "current_balance"
        case targetBalance = "target_balance"
        case averageDailyProfit = "average_daily_profit"
    }
}

struct TradeOpportunityAPIResponse: Codable {
    let success: Bool
    let opportunity: TradeOpportunityResponse
}

struct TradeOpportunityResponse: Codable {
    let symbol: String
    let bias: String
    let trend: String?
    let pressure: String?
    let setupQuality: String
    let setupType: String
    let runnerPotential: Bool
    let alertText: String

    let entryWindow: TradeOpportunityEntryWindow?
    let risk: TradeOpportunityRisk?
    let timing: TradeOpportunityTiming?
    let sizing: TradeOpportunitySizing?
    let accuracyContext: TradeOpportunityAccuracyContext?
    let internalNote: String?
    let decision: String?
    let passedGates: [String]?
    let failedGates: [String]?
    let hardVetoes: [String]?
    let dataNeeded: [String]?
    let decisionReasons: [String]?
    let waitingFor: [String]?

    var action: String {
        entryWindow?.type ?? setupType
    }

    var probabilityPercent: Int? {
        accuracyContext?.confidence
    }

    var riskDisplay: String {
        guard let score = risk?.riskScore else {
            return risk?.estimatedPullbackRisk?.displayOpportunityValue ?? "Unavailable"
        }
        return "\(score)% • \((risk?.estimatedPullbackRisk ?? "risk").displayOpportunityValue)"
    }

    var timeDisplay: String {
        timing?.waitUrgency?.displayOpportunityValue
            ?? entryWindow?.type?.displayOpportunityValue
            ?? "Unavailable"
    }

    var reasoning: [String] {
        TradePresentationPolicy.uniqueReasoning([
            entryWindow?.message,
            timing?.message,
            sizing?.sizingNote,
        ])
    }

    var isConsolidation: Bool {
        setupQuality.lowercased() == "consolidation"
        || setupType.lowercased().contains("chop")
        || setupType.lowercased().contains("range")
        || setupType.lowercased().contains("sideways")
    }

    enum CodingKeys: String, CodingKey {
        case symbol, bias, trend, pressure
        case setupQuality = "setup_quality"
        case setupType = "setup_type"
        case runnerPotential = "runner_potential"
        case alertText = "alert_text"
        case entryWindow = "entry_window"
        case risk
        case timing
        case sizing
        case accuracyContext = "accuracy_context"
        case internalNote = "internal_note"
        case decision
        case passedGates = "passed_gates"
        case failedGates = "failed_gates"
        case hardVetoes = "hard_vetoes"
        case dataNeeded = "data_needed"
        case decisionReasons = "decision_reasons"
        case waitingFor = "waiting_for"
    }
}

struct TradeOpportunityEntryWindow: Codable {
    let type: String?
    let low: Double?
    let high: Double?
    let trigger: Double?
    let message: String?
}

struct TradeOpportunityRisk: Codable {
    let invalidation: Double?
    let distanceToStop: Double?
    let estimatedPullbackRisk: String?
    let riskScore: Int?

    enum CodingKeys: String, CodingKey {
        case invalidation
        case distanceToStop = "distance_to_stop"
        case estimatedPullbackRisk = "estimated_pullback_risk"
        case riskScore = "risk_score"
    }
}

struct TradeOpportunityTiming: Codable {
    let avoidChasing: Bool?
    let waitUrgency: String?
    let pressure: String?
    let minutesLeft15m: Int?
    let minutesLeft1h: Int?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case avoidChasing = "avoid_chasing"
        case waitUrgency = "wait_urgency"
        case pressure
        case minutesLeft15m = "minutes_left_15m"
        case minutesLeft1h = "minutes_left_1h"
        case message
    }
}

struct TradeOpportunitySizing: Codable {
    let suggestedSize: Double?
    let sizeProfile: String?
    let userCanOverride: Bool?
    let sizingNote: String?

    enum CodingKeys: String, CodingKey {
        case suggestedSize = "suggested_size"
        case sizeProfile = "size_profile"
        case userCanOverride = "user_can_override"
        case sizingNote = "sizing_note"
    }
}

struct TradeOpportunityAccuracyContext: Codable {
    let waitProbability: Int?
    let waitReadyProbability: Int?
    let downsidePressureProbability: Int?
    let fakeBreakoutProbability: Int?
    let confidence: Int?

    enum CodingKeys: String, CodingKey {
        case waitProbability = "wait_probability"
        case waitReadyProbability = "wait_ready_probability"
        case downsidePressureProbability = "downside_pressure_probability"
        case fakeBreakoutProbability = "fake_breakout_probability"
        case confidence
    }
}

private extension String {
    var displayOpportunityValue: String {
        replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}
