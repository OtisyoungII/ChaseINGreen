//
//  BrokerLoginModels.swift
//  ChaseINGreen
//
//  By: Otis Young II
// --------------------------------------------------------------
// PURPOSE
// --------------------------------------------------------------
// ✅ Broker connection request/response models
// ✅ Aqua Funding login through the Match-Trader provider
// ✅ Username/password are the only Aqua credentials sent by iOS
// ✅ Match-Trader platform configuration remains backend-only
// ✅ Safe authenticated account details may return to Swift
// ✅ IBKR health and broker sync response models
//
// IMPORTANT RULES
// --------------------------------------------------------------
// ✅ Users never enter a Match-Trader server URL
// ✅ Users never enter a Match-Trader broker ID
// ✅ Users never paste co-auth cookies
// ✅ Users never paste refresh cookies
// ✅ Users never paste tradingApiToken values
// ✅ Passwords are never returned by the backend
// ✅ Aqua Funding and Trade The Pool keep separate adapters
// ✅ No live trading or order execution occurs here
// --------------------------------------------------------------

import Foundation

// MARK: - Match-Trader Login Request

struct MatchTraderLoginRequest: Codable {
    let login: String
    let password: String
    let broker: String
    let accountLabel: String?

    enum CodingKeys: String, CodingKey {
        case login
        case password
        case broker
        case accountLabel = "account_label"
    }
}

// MARK: - Match-Trader Login Response

struct MatchTraderLoginResponse: Codable {
    let success: Bool?
    let userId: String?
    let broker: String?
    let provider: String?
    let headline: String?
    let summary: String?
    let connection: MatchTraderConnectionFeatures?

    enum CodingKeys: String, CodingKey {
        case success
        case userId = "user_id"
        case broker
        case provider
        case headline
        case summary
        case connection
    }
}

// MARK: - Saved Match-Trader Connection Health

struct MatchTraderAuthHealthResponse: Codable {
    let success: Bool?
    let broker: String?
    let provider: String?
    let connected: Bool?
    let authenticated: Bool?
    let status: String?
    let tokenExpired: Bool?
    let refreshExpired: Bool?
    let accountCount: Int?
    let accounts: [MatchTraderConnectedAccount]?
    let connection: MatchTraderConnectionFeatures?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case broker
        case provider
        case connected
        case authenticated
        case status
        case tokenExpired = "token_expired"
        case refreshExpired = "refresh_expired"
        case accountCount = "account_count"
        case accounts
        case connection
        case message
    }
}

// MARK: - Sanitized Connection Features

struct MatchTraderConnectionFeatures: Codable {
    let connectionId: String?
    let provider: String?
    let broker: String?
    let status: String?
    let connectionName: String?
    let usernameHint: String?
    let accountLabel: String?
    let email: String?

    let tokenType: String?
    let expiresAt: String?
    let refreshExpiresAt: String?
    let sessionId: String?

    let tokenExpired: Bool?
    let refreshExpired: Bool?
    let authenticated: Bool?

    let accountCount: Int?
    let accounts: [MatchTraderConnectedAccount]?

    enum CodingKeys: String, CodingKey {
        case connectionId = "connection_id"
        case provider
        case broker
        case status
        case connectionName = "connection_name"
        case usernameHint = "username_hint"
        case accountLabel = "account_label"
        case email

        case tokenType = "token_type"
        case expiresAt = "expires_at"
        case refreshExpiresAt = "refresh_expires_at"
        case sessionId = "session_id"

        case tokenExpired = "token_expired"
        case refreshExpired = "refresh_expired"
        case authenticated

        case accountCount = "account_count"
        case accounts
    }
}

// MARK: - Safe Match-Trader Account

struct MatchTraderConnectedAccount: Codable, Identifiable {
    let tradingAccountId: String?
    let accountUUID: String?
    let accountName: String?

    let systemUUID: String?
    let systemType: String?
    let systemName: String?
    let systemActive: Bool?
    let systemDemo: Bool?

    let accountType: String?
    let group: String?
    let leverage: Double?
    let isRetail: Bool?
    let isProView: Bool?

    let offerUUID: String?
    let offerName: String?
    let offerDescription: String?
    let offerDemo: Bool?
    let initialDeposit: Double?

    let partnerId: String?
    let branchUUID: String?
    let createdAt: String?
    let moneyManager: String?

    let authenticatedForTrading: Bool?

    var id: String {
        tradingAccountId
            ?? accountUUID
            ?? accountName
            ?? UUID().uuidString
    }

    enum CodingKeys: String, CodingKey {
        case tradingAccountId = "trading_account_id"
        case accountUUID = "account_uuid"
        case accountName = "account_name"

        case systemUUID = "system_uuid"
        case systemType = "system_type"
        case systemName = "system_name"
        case systemActive = "system_active"
        case systemDemo = "system_demo"

        case accountType = "account_type"
        case group
        case leverage
        case isRetail = "is_retail"
        case isProView = "is_pro_view"

        case offerUUID = "offer_uuid"
        case offerName = "offer_name"
        case offerDescription = "offer_description"
        case offerDemo = "offer_demo"
        case initialDeposit = "initial_deposit"

        case partnerId = "partner_id"
        case branchUUID = "branch_uuid"
        case createdAt = "created_at"
        case moneyManager = "money_manager"

        case authenticatedForTrading = "authenticated_for_trading"
    }
}

// MARK: - Backend Session Sync Request

struct MatchTraderSyncRequest: Codable {
    let broker: String
    let accountId: String?
    let symbols: [String]

    enum CodingKeys: String, CodingKey {
        case broker
        case accountId = "account_id"
        case symbols
    }
}

// MARK: - Account-Specific Tradable Instruments

struct MatchTraderInstrumentsResponse: Codable {
    let success: Bool?
    let broker: String?
    let provider: String?
    let accountId: String?
    let count: Int?
    let instruments: [MatchTraderInstrument]?
    let headline: String?
    let summary: String?

    enum CodingKeys: String, CodingKey {
        case success
        case broker
        case provider
        case accountId = "account_id"
        case count
        case instruments
        case headline
        case summary
    }
}

struct MatchTraderInstrument: Codable, Identifiable, Hashable {
    let symbol: String
    let displayName: String?
    let group: String?
    let tradable: Bool?
    let minimumVolume: Double?
    let maximumVolume: Double?
    let volumeStep: Double?

    var id: String {
        symbol.uppercased()
    }

    enum CodingKeys: String, CodingKey {
        case symbol
        case displayName = "display_name"
        case group
        case tradable
        case minimumVolume = "minimum_volume"
        case maximumVolume = "maximum_volume"
        case volumeStep = "volume_step"
    }
}

// MARK: - Broker Sync Response

struct BrokerSyncResponse: Codable {
    let success: Bool?
    let broker: String?
    let provider: String?
    let status: String?
    let tone: String?
    let headline: String?
    let summary: String?

    let syncedCount: Int?
    let accountsSynced: Int?
    let accounts: [BrokerAccountResponse]?
    let balanceHealth: [MatchTraderBalanceHealthFeatures]?

    let warnings: [String]?
    let actions: [String]?

    enum CodingKeys: String, CodingKey {
        case success
        case broker
        case provider
        case status
        case tone
        case headline
        case summary

        case syncedCount = "synced_count"
        case accountsSynced = "accounts_synced"
        case accounts
        case balanceHealth = "balance_health"

        case warnings
        case actions
    }
}

// MARK: - Live Match-Trader Balance Health

struct MatchTraderBalanceHealthFeatures: Codable, Identifiable {
    let provider: String?
    let broker: String?
    let accountId: String?

    let balance: Double?
    let equity: Double?
    let margin: Double?
    let freeMargin: Double?
    let openPnl: Double?
    let todayPnl: Double?

    let dailyDrawdownLimit: Double?
    let maxDrawdownLimit: Double?
    let dailyDrawdownRemaining: Double?
    let maxDrawdownRemaining: Double?

    let buyingPower: Double?
    let equityBuffer: Double?
    let equityBufferPercent: Double?

    let riskLevel: String?
    let riskScore: Int?
    let tradingAllowed: Bool?

    let suggestedMaxTradeRisk: Double?
    let suggestedMaxTradeRiskPercent: Double?

    let headline: String?
    let summary: String?

    var id: String {
        accountId ?? "match-trader-balance-health"
    }

    enum CodingKeys: String, CodingKey {
        case provider
        case broker
        case accountId = "account_id"

        case balance
        case equity
        case margin
        case freeMargin = "free_margin"
        case openPnl = "open_pnl"
        case todayPnl = "today_pnl"

        case dailyDrawdownLimit = "daily_drawdown_limit"
        case maxDrawdownLimit = "max_drawdown_limit"
        case dailyDrawdownRemaining = "daily_drawdown_remaining"
        case maxDrawdownRemaining = "max_drawdown_remaining"

        case buyingPower = "buying_power"
        case equityBuffer = "equity_buffer"
        case equityBufferPercent = "equity_buffer_percent"

        case riskLevel = "risk_level"
        case riskScore = "risk_score"
        case tradingAllowed = "trading_allowed"

        case suggestedMaxTradeRisk = "suggested_max_trade_risk"
        case suggestedMaxTradeRiskPercent = "suggested_max_trade_risk_percent"

        case headline
        case summary
    }
}

// MARK: - Live Match-Trader Positions

struct MatchTraderPositionsResponse: Codable {
    let success: Bool?
    let broker: String?
    let provider: String?
    let accountCount: Int?
    let count: Int?
    let availableAccountCount: Int?
    let unavailableAccountCount: Int?
    let reconnectRequired: Bool?
    let accounts: [MatchTraderPositionAccount]?
    let headline: String?
    let summary: String?

    enum CodingKeys: String, CodingKey {
        case success
        case broker
        case provider
        case accountCount = "account_count"
        case count
        case availableAccountCount = "available_account_count"
        case unavailableAccountCount = "unavailable_account_count"
        case reconnectRequired = "reconnect_required"
        case accounts
        case headline
        case summary
    }
}

struct MatchTraderPositionAccount: Codable, Identifiable {
    let accountId: String?
    let tradingAccountId: String?
    let accountUUID: String?
    let accountName: String?
    let systemUUID: String?
    let accountType: String?
    let offerName: String?
    let initialDeposit: Double?
    let positions: [MatchTraderLivePosition]?
    let count: Int?
    let available: Bool?
    let balanceHealth: MatchTraderBalanceHealthFeatures?
    let balanceAvailable: Bool?
    let balanceSummary: String?
    let summary: String?

    var id: String {
        accountId ?? accountName ?? "match-trader-account"
    }

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case tradingAccountId = "trading_account_id"
        case accountUUID = "account_uuid"
        case accountName = "account_name"
        case systemUUID = "system_uuid"
        case accountType = "account_type"
        case offerName = "offer_name"
        case initialDeposit = "initial_deposit"
        case positions
        case count
        case available
        case balanceHealth = "balance_health"
        case balanceAvailable = "balance_available"
        case balanceSummary = "balance_summary"
        case summary
    }
}

struct MatchTraderLivePosition: Codable, Identifiable {
    let provider: String?
    let broker: String?
    let accountId: String?
    let accountUUID: String?
    let systemUUID: String?

    let positionId: String?
    let symbol: String
    let side: String?
    let officialSide: String?
    let volume: Double?

    let openPrice: Double?
    let currentPrice: Double?
    let bidPrice: Double?
    let askPrice: Double?

    let stopLoss: Double?
    let takeProfit: Double?

    let grossProfit: Double?
    let netProfit: Double?
    let commission: Double?
    let swap: Double?
    let profit: Double?
    let profitPercent: Double?

    let openedAt: String?
    let isWinning: Bool?
    let isLosing: Bool?
    let isFlat: Bool?

    var id: String {
        positionId
            ?? "\(accountId ?? "aqua")-\(symbol)-\(openPrice ?? 0)"
    }

    enum CodingKeys: String, CodingKey {
        case provider
        case broker
        case accountId = "account_id"
        case accountUUID = "account_uuid"
        case systemUUID = "system_uuid"

        case positionId = "position_id"
        case symbol
        case side
        case officialSide = "official_side"
        case volume

        case openPrice = "open_price"
        case currentPrice = "current_price"
        case bidPrice = "bid_price"
        case askPrice = "ask_price"

        case stopLoss = "stop_loss"
        case takeProfit = "take_profit"

        case grossProfit = "gross_profit"
        case netProfit = "net_profit"
        case commission
        case swap
        case profit
        case profitPercent = "profit_percent"

        case openedAt = "opened_at"
        case isWinning = "is_winning"
        case isLosing = "is_losing"
        case isFlat = "is_flat"
    }
}

// MARK: - Confirmed Live Position Management

struct MatchTraderPositionManagementRequest: Codable {
    let broker: String
    let accountId: String
    let positionId: String
    let action: String
    let stopLoss: Double?
    let takeProfit: Double?
    let volume: Double?
    let closePercent: Int?
    let userConfirmed: Bool

    enum CodingKeys: String, CodingKey {
        case broker
        case accountId = "account_id"
        case positionId = "position_id"
        case action
        case stopLoss = "stop_loss"
        case takeProfit = "take_profit"
        case volume
        case closePercent = "close_percent"
        case userConfirmed = "user_confirmed"
    }
}

struct MatchTraderPositionManagementResponse: Codable {
    let success: Bool?
    let broker: String?
    let provider: String?
    let accountId: String?
    let status: String?
    let action: String?
    let approved: Bool?
    let message: String?
    let positionId: String?
    let orderId: String?
    let reasons: String?
    let warnings: String?
    let actions: String?

    enum CodingKeys: String, CodingKey {
        case success
        case broker
        case provider
        case accountId = "account_id"
        case status
        case action
        case approved
        case message
        case positionId = "position_id"
        case orderId = "order_id"
        case reasons
        case warnings
        case actions
    }
}

// MARK: - Confirmed Immediate-Market Entry

struct MatchTraderMarketEntryRequest: Codable {
    let broker: String
    let accountId: String
    let symbol: String
    let side: String
    let volume: Double
    let stopLoss: Double?
    let takeProfit: Double?
    let trailingDistance: Double
    let userConfirmed: Bool

    enum CodingKeys: String, CodingKey {
        case broker
        case accountId = "account_id"
        case symbol
        case side
        case volume
        case stopLoss = "stop_loss"
        case takeProfit = "take_profit"
        case trailingDistance = "trailing_distance"
        case userConfirmed = "user_confirmed"
    }
}

struct MatchTraderMarketEntryResponse: Codable {
    let success: Bool?
    let broker: String?
    let provider: String?
    let accountId: String?
    let symbol: String?
    let side: String?
    let volume: Double?
    let status: String?
    let action: String?
    let approved: Bool?
    let message: String?
    let positionId: String?
    let orderId: String?
    let reasons: String?
    let warnings: String?
    let actions: String?

    enum CodingKeys: String, CodingKey {
        case success
        case broker
        case provider
        case accountId = "account_id"
        case symbol
        case side
        case volume
        case status
        case action
        case approved
        case message
        case positionId = "position_id"
        case orderId = "order_id"
        case reasons
        case warnings
        case actions
    }
}

// MARK: - Global Backend-Trade Cleanup

struct BackendTradeClearRequest: Codable {
    let confirmation: String
}

struct BackendTradeClearResponse: Codable {
    let success: Bool?
    let status: String?
    let headline: String?
    let summary: String?
    let deletedTradeCount: Int?
    let affectedUserCount: Int?
    let deletedLinkedJournalCount: Int?
    let brokerConnectionsPreserved: Bool?
    let brokerAccountsPreserved: Bool?
    let standaloneJournalsPreserved: Bool?
    let mlMemoryPreserved: Bool?

    enum CodingKeys: String, CodingKey {
        case success
        case status
        case headline
        case summary
        case deletedTradeCount = "deleted_trade_count"
        case affectedUserCount = "affected_user_count"
        case deletedLinkedJournalCount = "deleted_linked_journal_count"
        case brokerConnectionsPreserved = "broker_connections_preserved"
        case brokerAccountsPreserved = "broker_accounts_preserved"
        case standaloneJournalsPreserved = "standalone_journals_preserved"
        case mlMemoryPreserved = "ml_memory_preserved"
    }
}

// MARK: - IBKR Health Response

struct IBKRHealthResponse: Codable {
    let success: Bool?
    let status: String?
    let service: String?
    let authenticated: Bool?
    let connected: Bool?
    let competing: Bool?
    let message: String?
}
