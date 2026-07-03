//
//  BrokerAccount.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/1/26.
//
// ==============================================================
// MARK: - Broker Account Models
// --------------------------------------------------------------
// ✅ Manual broker account sync models
// ✅ IBKR account sync response models
// ✅ IBKR position sync response models
// ✅ Keeps prop-firm fields separate from brokerage fields
// ✅ Supports Aqua Funding / Trade The Pool / IBKR / future brokers
// ==============================================================

import Foundation

struct BrokerAccountResponse: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: String

    let broker: String
    let accountId: String

    let accountNumber: String?
    let accountName: String?
    let accountStatus: String?

    let accountMode: String?
    let accountType: String?
    let propFirmName: String?
    let propModel: String?
    let platform: String?

    let startingBalance: Double?
    let balance: Double?
    let equity: Double?
    let buyingPower: Double?
    let cashBalance: Double?
    let availableFunds: Double?

    let dailyDrawdownLimit: Double?
    let maxDrawdownLimit: Double?
    let dailyDrawdownRemaining: Double?
    let maxDrawdownRemaining: Double?

    let profitTarget: Double?
    let profitTargetRemaining: Double?
    let payoutTarget: Double?

    let dailyPnl: Double?
    let unrealizedPnl: Double?
    let realizedPnl: Double?

    let currency: String?
    let notes: String?

    let isActive: Bool
    let lastManualUpdateAt: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case broker
        case accountId = "account_id"
        case accountNumber = "account_number"
        case accountName = "account_name"
        case accountStatus = "account_status"
        case accountMode = "account_mode"
        case accountType = "account_type"
        case propFirmName = "prop_firm_name"
        case propModel = "prop_model"
        case platform
        case startingBalance = "starting_balance"
        case balance
        case equity
        case buyingPower = "buying_power"
        case cashBalance = "cash_balance"
        case availableFunds = "available_funds"
        case dailyDrawdownLimit = "daily_drawdown_limit"
        case maxDrawdownLimit = "max_drawdown_limit"
        case dailyDrawdownRemaining = "daily_drawdown_remaining"
        case maxDrawdownRemaining = "max_drawdown_remaining"
        case profitTarget = "profit_target"
        case profitTargetRemaining = "profit_target_remaining"
        case payoutTarget = "payout_target"
        case dailyPnl = "daily_pnl"
        case unrealizedPnl = "unrealized_pnl"
        case realizedPnl = "realized_pnl"
        case currency
        case notes
        case isActive = "is_active"
        case lastManualUpdateAt = "last_manual_update_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct BrokerAccountUpsertRequest: Codable {
    let broker: String
    let accountId: String

    let accountNumber: String?
    let accountName: String?
    let accountStatus: String?

    let accountMode: String?
    let accountType: String?
    let propFirmName: String?
    let propModel: String?
    let platform: String?

    let startingBalance: Double?
    let balance: Double?
    let equity: Double?
    let buyingPower: Double?
    let cashBalance: Double?
    let availableFunds: Double?

    let dailyDrawdownLimit: Double?
    let maxDrawdownLimit: Double?
    let dailyDrawdownRemaining: Double?
    let maxDrawdownRemaining: Double?

    let profitTarget: Double?
    let profitTargetRemaining: Double?
    let payoutTarget: Double?

    let dailyPnl: Double?
    let unrealizedPnl: Double?
    let realizedPnl: Double?

    let currency: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case broker
        case accountId = "account_id"
        case accountNumber = "account_number"
        case accountName = "account_name"
        case accountStatus = "account_status"
        case accountMode = "account_mode"
        case accountType = "account_type"
        case propFirmName = "prop_firm_name"
        case propModel = "prop_model"
        case platform
        case startingBalance = "starting_balance"
        case balance
        case equity
        case buyingPower = "buying_power"
        case cashBalance = "cash_balance"
        case availableFunds = "available_funds"
        case dailyDrawdownLimit = "daily_drawdown_limit"
        case maxDrawdownLimit = "max_drawdown_limit"
        case dailyDrawdownRemaining = "daily_drawdown_remaining"
        case maxDrawdownRemaining = "max_drawdown_remaining"
        case profitTarget = "profit_target"
        case profitTargetRemaining = "profit_target_remaining"
        case payoutTarget = "payout_target"
        case dailyPnl = "daily_pnl"
        case unrealizedPnl = "unrealized_pnl"
        case realizedPnl = "realized_pnl"
        case currency
        case notes
    }
}

// ==============================================================
// MARK: - IBKR Sync Models
// ==============================================================

struct IBKRAccountSyncResponse: Codable {
    let success: Bool?
    let status: String?
    let tone: String?
    let headline: String?
    let summary: String?
    let account: BrokerAccountResponse?
    let accounts: [BrokerAccountResponse]?
    let warnings: [String]?
    let actions: [String]?

    enum CodingKeys: String, CodingKey {
        case success
        case status
        case tone
        case headline
        case summary
        case account
        case accounts
        case warnings
        case actions
    }
}

struct IBKRPositionSyncResponse: Codable {
    let success: Bool?
    let status: String?
    let tone: String?
    let headline: String?
    let summary: String?
    let positions: [IBKRPositionResponse]?
    let openTrades: [LoggedTradeResponse]?
    let warnings: [String]?
    let actions: [String]?

    enum CodingKeys: String, CodingKey {
        case success
        case status
        case tone
        case headline
        case summary
        case positions
        case openTrades = "open_trades"
        case warnings
        case actions
    }
}

struct IBKRPositionResponse: Codable, Identifiable, Hashable {
    var id: String {
        "\(accountId ?? "ibkr")-\(symbol ?? "unknown")-\(conid ?? "0")"
    }

    let accountId: String?
    let accountName: String?
    let symbol: String?
    let conid: String?
    let assetClass: String?
    let currency: String?

    let position: Double?
    let marketPrice: Double?
    let marketValue: Double?
    let averageCost: Double?
    let unrealizedPnl: Double?
    let realizedPnl: Double?

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case accountName = "account_name"
        case symbol
        case conid
        case assetClass = "asset_class"
        case currency
        case position
        case marketPrice = "market_price"
        case marketValue = "market_value"
        case averageCost = "average_cost"
        case unrealizedPnl = "unrealized_pnl"
        case realizedPnl = "realized_pnl"
    }
}
