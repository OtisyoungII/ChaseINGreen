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

struct TradeOpportunityResponse: Codable {
    let symbol: String
    let bias: String
    let setupQuality: String
    let setupType: String
    let runnerPotential: Bool
    let alertText: String

    let action: String?
    let probability: Double?
    let riskLevel: String?
    let timeHorizon: String?
    let reasoning: [String]?

    enum CodingKeys: String, CodingKey {
        case symbol, bias
        case setupQuality = "setup_quality"
        case setupType = "setup_type"
        case runnerPotential = "runner_potential"
        case alertText = "alert_text"

        case action
        case probability
        case riskLevel = "risk_level"
        case timeHorizon = "time_horizon"
        case reasoning
    }
}
