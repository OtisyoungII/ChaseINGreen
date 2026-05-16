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

    let brokerAccountId: String?
    let brokerAccountName: String?
    let brokerAccountNumberLast4: String?
    let accountGroupKey: String?
    let parentTradeGroupId: String?

    let maxDailyLossAllowed: Double?
    let maxTotalLossAllowed: Double?
    let payoutTarget: Double?

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
        case brokerAccountId = "broker_account_id"
        case brokerAccountName = "broker_account_name"
        case brokerAccountNumberLast4 = "broker_account_number_last4"
        case accountGroupKey = "account_group_key"
        case parentTradeGroupId = "parent_trade_group_id"
        case maxDailyLossAllowed = "max_daily_loss_allowed"
        case maxTotalLossAllowed = "max_total_loss_allowed"
        case payoutTarget = "payout_target"
        case notes
    }
}

// MARK: - Trade Update

struct LoggedTradeUpdateRequest: Codable {
    let symbol: String?
    let direction: String?
    let entryPrice: Double?
    let openedAt: String?
    let currentPrice: Double?

    let stopLoss: Double?
    let clearStopLoss: Bool?
    let takeProfit: Double?
    let clearTakeProfit: Bool?

    let quantity: Double?
    let accountSize: Double?
    let platform: String?

    let brokerAccountId: String?
    let brokerAccountName: String?
    let brokerAccountNumberLast4: String?
    let accountGroupKey: String?
    let parentTradeGroupId: String?

    let maxDailyLossAllowed: Double?
    let maxTotalLossAllowed: Double?
    let payoutTarget: Double?

    let notes: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case direction
        case entryPrice = "entry_price"
        case openedAt = "opened_at"
        case currentPrice = "current_price"
        case stopLoss = "stop_loss"
        case clearStopLoss = "clear_stop_loss"
        case takeProfit = "take_profit"
        case clearTakeProfit = "clear_take_profit"
        case quantity
        case accountSize = "account_size"
        case platform
        case brokerAccountId = "broker_account_id"
        case brokerAccountName = "broker_account_name"
        case brokerAccountNumberLast4 = "broker_account_number_last4"
        case accountGroupKey = "account_group_key"
        case parentTradeGroupId = "parent_trade_group_id"
        case maxDailyLossAllowed = "max_daily_loss_allowed"
        case maxTotalLossAllowed = "max_total_loss_allowed"
        case payoutTarget = "payout_target"
        case notes
    }
}

// MARK: - Trade Response

struct LoggedTradeResponse: Codable, Identifiable {
    let id: UUID
    let userId: String?

    let symbol: String
    let direction: String

    let entryPrice: Double
    let currentPrice: Double?

    let bestPrice: Double?
    let worstPrice: Double?

    let stopLoss: Double?
    let takeProfit: Double?

    let quantity: Double?
    let accountSize: Double?
    let platform: String?

    let brokerAccountId: String?
    let brokerAccountName: String?
    let brokerAccountNumberLast4: String?

    let accountGroupKey: String?
    let parentTradeGroupId: String?

    let openPnl: Double?
    let realizedPnl: Double?
    
    let grossPnl: Double?
    let netPnl: Double?
    let commissionPaid: Double?
    let feesPaid: Double?
    let spreadCost: Double?
    let swapFee: Double?
    let exchangeFee: Double?
    let secFee: Double?
    let routingFee: Double?

    let exitPriceConfirmed: Bool
    let closeSource: String?
    let closeConfidence: String?

    let maxLoss: Double?
    let riskPercent: Double?

    let maxDailyLossAllowed: Double?
    let maxTotalLossAllowed: Double?
    let payoutTarget: Double?

    let openedAt: String
    let isOpen: Bool
    let notes: String?

    let createdAt: String
    let closedAt: String?
    let exitPrice: Double?
    let lastUpdatedAt: String?
    
    init(
        id: UUID,
        userId: String?,
        symbol: String,
        direction: String,
        entryPrice: Double,
        currentPrice: Double?,
        bestPrice: Double?,
        worstPrice: Double?,
        stopLoss: Double?,
        takeProfit: Double?,
        quantity: Double?,
        accountSize: Double?,
        platform: String?,
        brokerAccountId: String?,
        brokerAccountName: String?,
        brokerAccountNumberLast4: String?,
        accountGroupKey: String?,
        parentTradeGroupId: String?,
        openPnl: Double?,
        realizedPnl: Double?,
        grossPnl: Double? = nil,
        netPnl: Double? = nil,
        commissionPaid: Double? = nil,
        feesPaid: Double? = nil,
        spreadCost: Double? = nil,
        swapFee: Double? = nil,
        exchangeFee: Double? = nil,
        secFee: Double? = nil,
        routingFee: Double? = nil,
        exitPriceConfirmed: Bool,
        closeSource: String?,
        closeConfidence: String?,
        maxLoss: Double?,
        riskPercent: Double?,
        maxDailyLossAllowed: Double?,
        maxTotalLossAllowed: Double?,
        payoutTarget: Double?,
        openedAt: String,
        isOpen: Bool,
        notes: String?,
        createdAt: String,
        closedAt: String?,
        exitPrice: Double?,
        lastUpdatedAt: String?
    ) {
        self.id = id
        self.userId = userId
        self.symbol = symbol
        self.direction = direction
        self.entryPrice = entryPrice
        self.currentPrice = currentPrice
        self.bestPrice = bestPrice
        self.worstPrice = worstPrice
        self.stopLoss = stopLoss
        self.takeProfit = takeProfit
        self.quantity = quantity
        self.accountSize = accountSize
        self.platform = platform
        self.brokerAccountId = brokerAccountId
        self.brokerAccountName = brokerAccountName
        self.brokerAccountNumberLast4 = brokerAccountNumberLast4
        self.accountGroupKey = accountGroupKey
        self.parentTradeGroupId = parentTradeGroupId
        self.openPnl = openPnl
        self.realizedPnl = realizedPnl
        self.grossPnl = grossPnl
        self.netPnl = netPnl
        self.commissionPaid = commissionPaid
        self.feesPaid = feesPaid
        self.spreadCost = spreadCost
        self.swapFee = swapFee
        self.exchangeFee = exchangeFee
        self.secFee = secFee
        self.routingFee = routingFee
        self.exitPriceConfirmed = exitPriceConfirmed
        self.closeSource = closeSource
        self.closeConfidence = closeConfidence
        self.maxLoss = maxLoss
        self.riskPercent = riskPercent
        self.maxDailyLossAllowed = maxDailyLossAllowed
        self.maxTotalLossAllowed = maxTotalLossAllowed
        self.payoutTarget = payoutTarget
        self.openedAt = openedAt
        self.isOpen = isOpen
        self.notes = notes
        self.createdAt = createdAt
        self.closedAt = closedAt
        self.exitPrice = exitPrice
        self.lastUpdatedAt = lastUpdatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"

        case symbol
        case direction

        case entryPrice = "entry_price"
        case currentPrice = "current_price"

        case bestPrice = "best_price"
        case worstPrice = "worst_price"

        case stopLoss = "stop_loss"
        case takeProfit = "take_profit"

        case quantity
        case accountSize = "account_size"
        case platform

        case brokerAccountId = "broker_account_id"
        case brokerAccountName = "broker_account_name"
        case brokerAccountNumberLast4 = "broker_account_number_last4"

        case accountGroupKey = "account_group_key"
        case parentTradeGroupId = "parent_trade_group_id"

        case openPnl = "open_pnl"
        case realizedPnl = "realized_pnl"
        
        case grossPnl = "gross_pnl"
        case netPnl = "net_pnl"
        case commissionPaid = "commission_paid"
        case feesPaid = "fees_paid"
        case spreadCost = "spread_cost"
        case swapFee = "swap_fee"
        case exchangeFee = "exchange_fee"
        case secFee = "sec_fee"
        case routingFee = "routing_fee"

        case exitPriceConfirmed = "exit_price_confirmed"
        case closeSource = "close_source"
        case closeConfidence = "close_confidence"

        case maxLoss = "max_loss"
        case riskPercent = "risk_percent"

        case maxDailyLossAllowed = "max_daily_loss_allowed"
        case maxTotalLossAllowed = "max_total_loss_allowed"
        case payoutTarget = "payout_target"

        case openedAt = "opened_at"
        case isOpen = "is_open"
        case notes

        case createdAt = "created_at"
        case closedAt = "closed_at"
        case exitPrice = "exit_price"
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
    let flashAlert: Bool?
    let probabilityLabel: String?
    let probabilityDetail: String?
    let recoveryChance: Double?
    let failureRate: Double?
    let sessionHighSwept: Bool?
    let sessionLowSwept: Bool?
    let sessionContext: String?
    let learningInsight: String?
    let journalLesson: String?
    let priceSource: String?

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
        case flashAlert = "flash_alert"
        case probabilityLabel = "probability_label"
        case probabilityDetail = "probability_detail"
        case recoveryChance = "recovery_chance"
        case failureRate = "failure_rate"
        case sessionHighSwept = "session_high_swept"
        case sessionLowSwept = "session_low_swept"
        case sessionContext = "session_context"
        case learningInsight = "learning_insight"
        case journalLesson = "journal_lesson"
        case priceSource = "price_source"
    }
}

// MARK: - Trade Action Requests

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
    let closeReason: String?
    let closeSource: String?
    let closeConfidence: String?
    let exitPriceConfirmed: Bool
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case exitPrice = "exit_price"
        case closeReason = "close_reason"
        case closeSource = "close_source"
        case closeConfidence = "close_confidence"
        case exitPriceConfirmed = "exit_price_confirmed"
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

struct StopLossHitRequest: Codable {
    let exitPrice: Double?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case exitPrice = "exit_price"
        case notes
    }
}

struct TakeProfitHitRequest: Codable {
    let exitPrice: Double?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case exitPrice = "exit_price"
        case notes
    }
}

// MARK: - Trade Stats

struct TradeStatsSummaryResponse: Codable {
    let totalClosedTrades: Int
    let winningTrades: Int
    let losingTrades: Int
    let flatTrades: Int

    let winRate: Double
    let totalRealizedPnl: Double
    let avgWin: Double?
    let avgLoss: Double?

    let protectedProfitTrades: Int
    let majorGivebackTrades: Int
    let missedBestExitTrades: Int

    let openTrades: Int
    let totalOpenPnl: Double
    
    let totalGrossPnl: Double?
    let totalNetPnl: Double?
    let totalCommissionPaid: Double?
    let totalFeesPaid: Double?

    enum CodingKeys: String, CodingKey {
        case totalClosedTrades = "total_closed_trades"
        case winningTrades = "winning_trades"
        case losingTrades = "losing_trades"
        case flatTrades = "flat_trades"
        case winRate = "win_rate"
        case totalRealizedPnl = "total_realized_pnl"
        case avgWin = "avg_win"
        case avgLoss = "avg_loss"
        case protectedProfitTrades = "protected_profit_trades"
        case majorGivebackTrades = "major_giveback_trades"
        case missedBestExitTrades = "missed_best_exit_trades"
        case openTrades = "open_trades"
        case totalOpenPnl = "total_open_pnl"
        
        case totalGrossPnl = "total_gross_pnl"
        case totalNetPnl = "total_net_pnl"
        case totalCommissionPaid = "total_commission_paid"
        case totalFeesPaid = "total_fees_paid"
    }
}
