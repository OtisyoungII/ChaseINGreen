//
//  TradeLogCreateRequest.swift
//  ChaseINGreen
//

import Foundation

struct TradeLogCreateRequest: Codable {
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

    let instructionsCompleted: Bool
    let bypassInstructions: Bool
    let allowInstructionReplay: Bool
    let userConfirmedUnderstanding: Bool

    init(
        symbol: String,
        displaySymbol: String? = nil,
        broker: String?,
        accountType: String?,
        accountSize: Double?,
        direction: String?,
        intent: String,
        entryPrice: Double?,
        exitPrice: Double?,
        stopLoss: Double?,
        takeProfit: Double?,
        positionSize: Double?,
        riskAmount: Double?,
        setupType: String?,
        marketPhase: String?,
        timeframe: String?,
        reasons: [String],
        warnings: [String],
        emotions: [String],
        mistakes: [String],
        confidence: String?,
        outcome: String,
        notes: String?,
        instructionsCompleted: Bool,
        bypassInstructions: Bool,
        allowInstructionReplay: Bool,
        userConfirmedUnderstanding: Bool
    ) {
        self.symbol = symbol
        self.displaySymbol = displaySymbol
        self.broker = broker
        self.accountType = accountType
        self.accountSize = accountSize
        self.direction = direction
        self.intent = intent
        self.entryPrice = entryPrice
        self.exitPrice = exitPrice
        self.stopLoss = stopLoss
        self.takeProfit = takeProfit
        self.positionSize = positionSize
        self.riskAmount = riskAmount
        self.setupType = setupType
        self.marketPhase = marketPhase
        self.timeframe = timeframe
        self.reasons = reasons
        self.warnings = warnings
        self.emotions = emotions
        self.mistakes = mistakes
        self.confidence = confidence
        self.outcome = outcome
        self.notes = notes
        self.instructionsCompleted = instructionsCompleted
        self.bypassInstructions = bypassInstructions
        self.allowInstructionReplay = allowInstructionReplay
        self.userConfirmedUnderstanding = userConfirmedUnderstanding
    }

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

        case instructionsCompleted = "instructions_completed"
        case bypassInstructions = "bypass_instructions"
        case allowInstructionReplay = "allow_instruction_replay"
        case userConfirmedUnderstanding = "user_confirmed_understanding"
    }

    private var normalizedDirection: String? {
        guard let direction else { return nil }

        switch direction.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "long", "buy":
            return "buy"
        case "short", "sell":
            return "sell"
        default:
            return direction
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(symbol, forKey: .symbol)
        try container.encodeIfPresent(displaySymbol, forKey: .displaySymbol)

        try container.encodeIfPresent(broker, forKey: .broker)
        try container.encodeIfPresent(accountType, forKey: .accountType)
        try container.encodeIfPresent(accountSize, forKey: .accountSize)

        try container.encodeIfPresent(normalizedDirection, forKey: .direction)
        try container.encode(intent, forKey: .intent)

        try container.encodeIfPresent(entryPrice, forKey: .entryPrice)
        try container.encodeIfPresent(exitPrice, forKey: .exitPrice)
        try container.encodeIfPresent(stopLoss, forKey: .stopLoss)
        try container.encodeIfPresent(takeProfit, forKey: .takeProfit)

        try container.encodeIfPresent(positionSize, forKey: .positionSize)
        try container.encodeIfPresent(riskAmount, forKey: .riskAmount)

        try container.encodeIfPresent(setupType, forKey: .setupType)
        try container.encodeIfPresent(marketPhase, forKey: .marketPhase)
        try container.encodeIfPresent(timeframe, forKey: .timeframe)

        try container.encode(reasons, forKey: .reasons)
        try container.encode(warnings, forKey: .warnings)
        try container.encode(emotions, forKey: .emotions)
        try container.encode(mistakes, forKey: .mistakes)

        try container.encodeIfPresent(confidence, forKey: .confidence)
        try container.encode(outcome, forKey: .outcome)
        try container.encodeIfPresent(notes, forKey: .notes)

        try container.encode(instructionsCompleted, forKey: .instructionsCompleted)
        try container.encode(bypassInstructions, forKey: .bypassInstructions)
        try container.encode(allowInstructionReplay, forKey: .allowInstructionReplay)
        try container.encode(userConfirmedUnderstanding, forKey: .userConfirmedUnderstanding)
    }
}
