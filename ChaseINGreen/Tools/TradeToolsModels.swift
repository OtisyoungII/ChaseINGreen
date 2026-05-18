//
//  TradeToolsModels.swift
//  ChaseINGreen
//
//  Created by Otis Young on 5/18/26.
//

import Foundation

struct TradeToolsLogResponse: Codable {
    let success: Bool
    let tradeLog: TradeLogDTO
    let mlEvent: MLTrainingEventDTO

    enum CodingKeys: String, CodingKey {
        case success
        case tradeLog = "trade_log"
        case mlEvent = "ml_event"
    }
}

struct TradeLogDTO: Codable {
    let symbol: String
    let displaySymbol: String?
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
    let instructionsStatus: String
    let instructionsCompleted: Bool
    let bypassInstructions: Bool
    let allowInstructionReplay: Bool
    let userConfirmedUnderstanding: Bool

    enum CodingKeys: String, CodingKey {
        case symbol
        case displaySymbol = "display_symbol"
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
        case instructionsStatus = "instructions_status"
        case instructionsCompleted = "instructions_completed"
        case bypassInstructions = "bypass_instructions"
        case allowInstructionReplay = "allow_instruction_replay"
        case userConfirmedUnderstanding = "user_confirmed_understanding"
    }
}

struct MLTrainingEventDTO: Codable {
    let userId: Int?
    let tradeLogId: Int?
    let tradeJournalId: Int?
    let alertId: Int?
    let eventType: String
    let labels: [String]
    let symbol: String?
    let broker: String?
    let accountType: String?
    let features: [String: FeatureValue]
    let includeInPersonalModel: Bool
    let includeInSharedModel: Bool
    let anonymized: Bool
    let consentVersion: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case tradeLogId = "trade_log_id"
        case tradeJournalId = "trade_journal_id"
        case alertId = "alert_id"
        case eventType = "event_type"
        case labels
        case symbol
        case broker
        case accountType = "account_type"
        case features
        case includeInPersonalModel = "include_in_personal_model"
        case includeInSharedModel = "include_in_shared_model"
        case anonymized
        case consentVersion = "consent_version"
        case notes
    }
}

enum FeatureValue: Codable {
    case string(String)
    case double(Double)
    case int(Int)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}
