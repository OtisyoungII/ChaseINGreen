//
//  SetupModel.swift
//  ChaseINGreen
//
//  Created by Otis Young on 4/16/26.
//

import Foundation

// MARK: - Health

struct SetupHealthResponse: Codable {
    let status: String
    let service: String?
}

// MARK: - Setup

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

// MARK: - Trade Create

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

// MARK: - Trade Response (UPDATED ✅)

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

    // ✅ NEW FIELDS (Render DB sync)
    let closedAt: String?
    let exitPrice: Double?
    let realizedPnl: Double?
    let lastUpdatedAt: String?

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

        // ✅ NEW KEYS
        case closedAt = "closed_at"
        case exitPrice = "exit_price"
        case realizedPnl = "realized_pnl"
        case lastUpdatedAt = "last_updated_at"
    }
}

// MARK: - Quote

struct QuoteResponse: Codable {
    let symbol: String
    let displaySymbol: String
    let instrumentName: String
    let instrumentDetail: String
    let assetClass: String

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
    let freshness: String
    let lastUpdated: String?
    let priceLabel: String

    enum CodingKeys: String, CodingKey {
        case symbol
        case displaySymbol = "display_symbol"
        case instrumentName = "instrument_name"
        case instrumentDetail = "instrument_detail"
        case assetClass = "asset_class"
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
        case freshness
        case lastUpdated = "last_updated"
        case priceLabel = "price_label"
    }
}

// MARK: - Trade Alert Request

struct TradeAlertRequest: Codable {
    let symbol: String
    let direction: String
    let entryPrice: Double
    let currentBrokerPrice: Double?
    let currentAppPrice: Double?
    let quantity: Double?
    let accountSize: Double?
    let cashAvailable: Double?
    let buyingPower: Double?
    let stopLoss: Double?
    let takeProfit: Double?
    let accountType: String?
    let broker: String?
    let dailyPnl: Double?
    let openPnl: Double?
    let realizedPnl: Double?
    let maxDailyLossAllowed: Double?
    let maxTotalLossAllowed: Double?
    let payoutTarget: Double?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case direction
        case entryPrice = "entry_price"
        case currentBrokerPrice = "current_broker_price"
        case currentAppPrice = "current_app_price"
        case quantity
        case accountSize = "account_size"
        case cashAvailable = "cash_available"
        case buyingPower = "buying_power"
        case stopLoss = "stop_loss"
        case takeProfit = "take_profit"
        case accountType = "account_type"
        case broker
        case dailyPnl = "daily_pnl"
        case openPnl = "open_pnl"
        case realizedPnl = "realized_pnl"
        case maxDailyLossAllowed = "max_daily_loss_allowed"
        case maxTotalLossAllowed = "max_total_loss_allowed"
        case payoutTarget = "payout_target"
        case notes
    }
}

// MARK: - Trade Alert Response

struct TradeAlertResponse: Codable {
    let symbol: String
    let displaySymbol: String?
    let alertType: String
    let severity: String
    let title: String
    let message: String
    let flavor: String?
    let decision: String
    let confidence: Int
    let marketPhase: String?
    let tradeState: String?
    let responseRequiredWithinSeconds: Int?
    let accountType: String?
    let broker: String?
    let reasons: [String]
    let warnings: [String]
    let actions: [String]
    let needsUserResponse: Bool
    let responseOptions: [String]

    enum CodingKeys: String, CodingKey {
        case symbol
        case displaySymbol = "display_symbol"
        case alertType = "alert_type"
        case severity
        case title
        case message
        case flavor
        case decision
        case confidence
        case marketPhase = "market_phase"
        case tradeState = "trade_state"
        case responseRequiredWithinSeconds = "response_required_within_seconds"
        case accountType = "account_type"
        case broker
        case reasons
        case warnings
        case actions
        case needsUserResponse = "needs_user_response"
        case responseOptions = "response_options"
    }
}

// MARK: - NEW REQUEST MODELS (🔥 REQUIRED)

struct BrokerPriceUpdateRequest: Codable {
    let currentPrice: Double
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case currentPrice = "current_price"
        case notes
    }
}

struct TradeCloseRequest: Codable {
    let exitPrice: Double?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case exitPrice = "exit_price"
        case notes
    }
}

struct TradeReduceRequest: Codable {
    let newQuantity: Double
    let currentPrice: Double?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case newQuantity = "new_quantity"
        case currentPrice = "current_price"
        case notes
    }
}

struct TradeAddRequest: Codable {
    let addQuantity: Double
    let currentPrice: Double?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case addQuantity = "add_quantity"
        case currentPrice = "current_price"
        case notes
    }
}
