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
    var ledgerValuations: [AcceptedValuation]? = nil
    var sourceMode: String? = nil
    var ledgerKnownRealizedPnl: Double? = nil
    var ledgerRealizedPnl: Double? = nil
    var ledgerUnrealizedPnl: Double? = nil
    var ledgerCalculatedBalance: Double? = nil
    var ledgerCalculatedValue: Double? = nil
    var brokerReportedEquity: Double? = nil
    var ledgerUnconfirmedCloses: Int? = nil
    var ledgerUnpricedPositions: Int? = nil
    var ledgerUnassociatedTrades: Int? = nil
    var ledgerStatus: String? = nil

    let id: UUID
    let userId: String

    let broker: String
    let accountId: String

    let accountNumber: String?
    let accountName: String?
    let accountStatus: String?

    let accountMode: String?
    let accountType: String?
    let ownershipType: String?
    let fundingType: String?
    let marginType: String?
    let customerType: String?
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
    let participationState: String?
    let canonicalAccountId: String?
    let brokerConnectionId: String?
    let connectionMode: String?
    let connectionStatus: String?
    let connectionName: String?
    let sourceMachine: String?
    let accountTitle: String?
    let businessType: String?
    let dataState: String?
    let stale: Bool?
    let lastSuccessfulSync: String?
    let positionsCount: Int?
    let lastManualUpdateAt: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case ledgerValuations = "ledger_valuations"
        case sourceMode = "source_mode"
        case ledgerKnownRealizedPnl = "ledger_known_realized_pnl"
        case ledgerRealizedPnl = "ledger_realized_pnl"
        case ledgerUnrealizedPnl = "ledger_unrealized_pnl"
        case ledgerCalculatedBalance = "ledger_calculated_balance"
        case ledgerCalculatedValue = "ledger_calculated_value"
        case brokerReportedEquity = "broker_reported_equity"
        case ledgerUnconfirmedCloses = "ledger_unconfirmed_closes"
        case ledgerUnpricedPositions = "ledger_unpriced_positions"
        case ledgerUnassociatedTrades = "ledger_unassociated_trades"
        case ledgerStatus = "ledger_status"

        case id
        case userId = "user_id"
        case broker
        case accountId = "account_id"
        case accountNumber = "account_number"
        case accountName = "account_name"
        case accountStatus = "account_status"
        case accountMode = "account_mode"
        case accountType = "account_type"
        case ownershipType = "ownership_type"
        case fundingType = "funding_type"
        case marginType = "margin_type"
        case customerType = "customer_type"
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
        case participationState = "participation_state"
        case canonicalAccountId = "canonical_account_id"
        case brokerConnectionId = "broker_connection_id"
        case connectionMode = "connection_mode"
        case connectionStatus = "connection_status"
        case connectionName = "connection_name"
        case sourceMachine = "source_machine"
        case accountTitle = "account_title"
        case businessType = "business_type"
        case dataState = "data_state"
        case stale
        case lastSuccessfulSync = "last_successful_sync"
        case positionsCount = "positions_count"
        case lastManualUpdateAt = "last_manual_update_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isEligibleManualOrBrokerAccount: Bool {
        LedgerTruthPolicy.activeAccount(isActive: isActive, participation: participationState, status: accountStatus)
    }

    var normalizedParticipationState: String {
        participationState?.lowercased() ?? "active"
    }
}

struct BrokerAccountUpsertRequest: Codable {
    let broker: String
    let accountId: String?

    let accountNumber: String?
    let accountName: String?
    let accountStatus: String?

    let accountMode: String?
    let accountType: String?
    let ownershipType: String?
    let fundingType: String?
    let marginType: String?
    let customerType: String?
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

    var canonicalAccountId: UUID? = nil
    var creationId: UUID? = nil
    var reconcileManualTrades: Bool = false

    enum CodingKeys: String, CodingKey {
        case canonicalAccountId = "canonical_account_id"
        case creationId = "creation_id"
        case reconcileManualTrades = "reconcile_manual_trades"
        case broker
        case accountId = "account_id"
        case accountNumber = "account_number"
        case accountName = "account_name"
        case accountStatus = "account_status"
        case accountMode = "account_mode"
        case accountType = "account_type"
        case ownershipType = "ownership_type"
        case fundingType = "funding_type"
        case marginType = "margin_type"
        case customerType = "customer_type"
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
