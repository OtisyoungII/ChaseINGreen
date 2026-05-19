//
//  TradeLogCreateRequest.swift
//  ChaseINGreen
//
//  Created by Otis Young on 5/18/26.
//

// ChaseINGreen/Tools/TradeLogCreateRequest.swift

import Foundation

struct TradeLogCreateRequest: Codable {

    let symbol: String
    let broker: String?
    let accountType: String?
    let accountSize: Double?

    let direction: String?
    let intent: String

    let entryPrice: Double?
    let exitPrice: Double?

    let stopLoss: Double?
    let takeProfit: Double?

    let positionSize: Double?
    let riskAmount: Double?

    let setupType: String?
    let marketPhase: String?
    let timeframe: String?

    let reasons: [String]
    let warnings: [String]
    let emotions: [String]
    let mistakes: [String]

    let confidence: String?
    let outcome: String

    let notes: String?

    // onboarding / learning
    let instructionsCompleted: Bool
    let bypassInstructions: Bool
    let allowInstructionReplay: Bool
    let userConfirmedUnderstanding: Bool

    enum CodingKeys: String, CodingKey {
        case symbol
        case broker

        case accountType = "account_type"
        case accountSize = "account_size"

        case direction
        case intent

        case entryPrice = "entry_price"
        case exitPrice = "exit_price"

        case stopLoss = "stop_loss"
        case takeProfit = "take_profit"

        case positionSize = "position_size"
        case riskAmount = "risk_amount"

        case setupType = "setup_type"
        case marketPhase = "market_phase"
        case timeframe

        case reasons
        case warnings
        case emotions
        case mistakes

        case confidence
        case outcome
        case notes

        case instructionsCompleted = "instructions_completed"
        case bypassInstructions = "bypass_instructions"
        case allowInstructionReplay = "allow_instruction_replay"
        case userConfirmedUnderstanding = "user_confirmed_understanding"
    }
}
