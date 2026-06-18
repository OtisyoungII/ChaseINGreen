//
//  PreTradeContext.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/11/26.
//


import Foundation

struct PreTradeContextRequest: Codable {
    let symbol: String
    let direction: String?
    let broker: String?
    let accountType: String?
    let accountSize: Double?
    let plannedEntry: Double?
    let plannedStopLoss: Double?
    let plannedTakeProfit: Double?
    let plannedSize: Double?

    init(
        symbol: String,
        direction: String? = nil,
        broker: String? = nil,
        accountType: String? = nil,
        accountSize: Double? = nil,
        plannedEntry: Double? = nil,
        plannedStopLoss: Double? = nil,
        plannedTakeProfit: Double? = nil,
        plannedSize: Double? = nil
    ) {
        self.symbol = symbol
        self.direction = direction
        self.broker = broker
        self.accountType = accountType
        self.accountSize = accountSize
        self.plannedEntry = plannedEntry
        self.plannedStopLoss = plannedStopLoss
        self.plannedTakeProfit = plannedTakeProfit
        self.plannedSize = plannedSize
    }
    enum CodingKeys: String, CodingKey {
        case symbol
        case direction
        case broker
        case accountType = "account_type"
        case accountSize = "account_size"
        case plannedEntry = "planned_entry"
        case plannedStopLoss = "planned_stop_loss"
        case plannedTakeProfit = "planned_take_profit"
        case plannedSize = "planned_size"
    }
}

struct PreTradeContextResponse: Codable, Identifiable {
    var id: String { symbol }

    let symbol: String
    let displaySymbol: String?

    let canEnter: Bool
    let entryGrade: Int
    let setupBias: String
    let setupQuality: String
    let tradeTiming: String

    let scenario: String?
    let scenarioType: String?
    let scenarioConfidence: Int?

    let plainEnglishRead: String
    let nextExpectedEvent: String?
    let confirmation: String?
    let invalidation: String?

    let supportLevel: Double?
    let resistanceLevel: Double?
    let target1: Double?
    let target2: Double?

    let reasons: [String]
    let warnings: [String]
    let actions: [String]
    let conviction: String
    let directionSignal: String
    let cardTone: String
    
    let convictionReason: String?
    let support1: Double?
    let support2: Double?
    let resistance1: Double?
    let resistance2: Double?
    let midpoint: Double?
    let breakoutAbove: Double?
    let breakdownBelow: Double?

    let priceSource: String
    

    enum CodingKeys: String, CodingKey {
        case symbol
        case displaySymbol = "display_symbol"

        case canEnter = "can_enter"
        case entryGrade = "entry_grade"
        case setupBias = "setup_bias"
        case setupQuality = "setup_quality"
        case tradeTiming = "trade_timing"

        case scenario
        case scenarioType = "scenario_type"
        case scenarioConfidence = "scenario_confidence"

        case plainEnglishRead = "plain_english_read"
        case nextExpectedEvent = "next_expected_event"
        case confirmation
        case invalidation

        case supportLevel = "support_level"
        case resistanceLevel = "resistance_level"
        case target1 = "target_1"
        case target2 = "target_2"

        case reasons
        case warnings
        case actions
        case conviction
        case directionSignal = "direction_signal"
        case cardTone = "card_tone"
        
        case convictionReason = "conviction_reason"
        case support1 = "support_1"
        case support2 = "support_2"
        case resistance1 = "resistance_1"
        case resistance2 = "resistance_2"
        case midpoint
        case breakoutAbove = "breakout_above"
        case breakdownBelow = "breakdown_below"

        case priceSource = "price_source"
        
    }
}
