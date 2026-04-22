//
//  SetupModel.swift
//  ChaseINGreen
//
//  Created by Otis Young on 4/16/26.
//

import Foundation

struct SetupHealthResponse: Codable {
    let status: String
    let service: String?
}

struct SetupResponse: Codable {
    let ticker: String
    let status: String
    let dailyBias: String?
    let setupType: String?
    let currentPrice: Double?
    let confidence: Int?
    let triggerReady: Bool?
    let alertText: String?

    enum CodingKeys: String, CodingKey {
        case ticker
        case status
        case dailyBias = "daily_bias"
        case setupType = "setup_type"
        case currentPrice = "current_price"
        case confidence
        case triggerReady = "trigger_ready"
        case alertText = "alert_text"
    }
}

struct LoggedTradeCreateRequest: Codable {
    let userId: String?
    let symbol: String
    let direction: String
    let entryPrice: Double
    let currentPrice: Double?
    let stopLoss: Double?
    let takeProfit: Double?
    let quantity: Double?
    let accountSize: Double?
    let platform: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case symbol
        case direction
        case entryPrice = "entry_price"
        case currentPrice = "current_price"
        case stopLoss = "stop_loss"
        case takeProfit = "take_profit"
        case quantity
        case accountSize = "account_size"
        case platform
        case notes
    }
}

struct LoggedTradeResponse: Codable, Identifiable {
    let id: UUID
    let userId: String?
    let symbol: String
    let direction: String
    let entryPrice: Double
    let currentPrice: Double?
    let stopLoss: Double?
    let takeProfit: Double?
    let quantity: Double?
    let accountSize: Double?
    let platform: String?
    let openedAt: String
    let isOpen: Bool
    let notes: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case symbol
        case direction
        case entryPrice = "entry_price"
        case currentPrice = "current_price"
        case stopLoss = "stop_loss"
        case takeProfit = "take_profit"
        case quantity
        case accountSize = "account_size"
        case platform
        case openedAt = "opened_at"
        case isOpen = "is_open"
        case notes
        case createdAt = "created_at"
    }
}
struct QuoteResponse: Codable {
    let symbol: String
    let price: Double?
    let change: Double?
    let percentChange: Double?
    let previousClose: Double?
    let open: Double?
    let high: Double?
    let low: Double?
    let volume: Int?
    let currency: String?
    let marketState: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case price
        case change
        case percentChange = "percent_change"
        case previousClose = "previous_close"
        case open
        case high
        case low
        case volume
        case currency
        case marketState = "market_state"
    }
}
