//
//  BatCaveModels.swift
//  ChaseINGreen
//  by: Otis Young
//
//  Bat Cave, unified portfolio, account workspace,
//  Portfolio AI, and execution preview models.
//

import Foundation

struct UnifiedPortfolioResponse: Codable {
    let userId: String
    let totalAccounts: Int
    let totalEquity: Double
    let totalCash: Double
    let totalBuyingPower: Double
    let totalAvailableFunds: Double
    let totalDailyPnl: Double
    let totalUnrealizedPnl: Double
    let totalRealizedPnl: Double
    let totalPnl: Double

    let brokerageValue: Double
    let propFirmValue: Double
    let cryptoValue: Double
    let retirementValue: Double
    let businessValue: Double
    let cashReserveValue: Double

    let portfolioTone: String
    let headline: String
    let summary: String

    let accounts: [UnifiedPortfolioAccount]
    let warnings: [String]
    let actions: [String]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case totalAccounts = "total_accounts"
        case totalEquity = "total_equity"
        case totalCash = "total_cash"
        case totalBuyingPower = "total_buying_power"
        case totalAvailableFunds = "total_available_funds"
        case totalDailyPnl = "total_daily_pnl"
        case totalUnrealizedPnl = "total_unrealized_pnl"
        case totalRealizedPnl = "total_realized_pnl"
        case totalPnl = "total_pnl"

        case brokerageValue = "brokerage_value"
        case propFirmValue = "prop_firm_value"
        case cryptoValue = "crypto_value"
        case retirementValue = "retirement_value"
        case businessValue = "business_value"
        case cashReserveValue = "cash_reserve_value"

        case portfolioTone = "portfolio_tone"
        case headline
        case summary
        case accounts
        case warnings
        case actions
    }
}

struct UnifiedPortfolioAccount: Codable, Identifiable, Hashable {
    var id: String { "\(broker)-\(accountId)" }

    let broker: String
    let accountId: String
    let accountName: String?
    let accountGroup: String
    let accountType: String?
    let platform: String?

    let balance: Double
    let equity: Double
    let buyingPower: Double
    let availableFunds: Double
    let cashBalance: Double

    let dailyPnl: Double
    let unrealizedPnl: Double
    let realizedPnl: Double
    let totalPnl: Double

    let dailyDrawdownRemaining: Double?
    let maxDrawdownRemaining: Double?

    let currency: String
    let riskTone: String
    let summary: String

    enum CodingKeys: String, CodingKey {
        case broker
        case accountId = "account_id"
        case accountName = "account_name"
        case accountGroup = "account_group"
        case accountType = "account_type"
        case platform

        case balance
        case equity
        case buyingPower = "buying_power"
        case availableFunds = "available_funds"
        case cashBalance = "cash_balance"

        case dailyPnl = "daily_pnl"
        case unrealizedPnl = "unrealized_pnl"
        case realizedPnl = "realized_pnl"
        case totalPnl = "total_pnl"

        case dailyDrawdownRemaining = "daily_drawdown_remaining"
        case maxDrawdownRemaining = "max_drawdown_remaining"

        case currency
        case riskTone = "risk_tone"
        case summary
    }
}

struct AccountSelectionResponse: Codable {
    let userId: String
    let selectionMode: String

    let broker: String?
    let accountId: String?
    let accountGroup: String?

    let selectedCount: Int
    let totalAvailableAccounts: Int

    let selectedEquity: Double
    let selectedCash: Double
    let selectedBuyingPower: Double
    let selectedAvailableFunds: Double
    let selectedDailyPnl: Double
    let selectedTotalPnl: Double

    let status: String
    let headline: String
    let summary: String

    let selectedAccounts: [UnifiedPortfolioAccount]
    let portfolioSummary: PortfolioSummaryResponse

    let warnings: [String]
    let actions: [String]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case selectionMode = "selection_mode"

        case broker
        case accountId = "account_id"
        case accountGroup = "account_group"

        case selectedCount = "selected_count"
        case totalAvailableAccounts = "total_available_accounts"

        case selectedEquity = "selected_equity"
        case selectedCash = "selected_cash"
        case selectedBuyingPower = "selected_buying_power"
        case selectedAvailableFunds = "selected_available_funds"
        case selectedDailyPnl = "selected_daily_pnl"
        case selectedTotalPnl = "selected_total_pnl"

        case status
        case headline
        case summary

        case selectedAccounts = "selected_accounts"
        case portfolioSummary = "portfolio_summary"

        case warnings
        case actions
    }
}

struct PortfolioSummaryResponse: Codable {
    let userId: String
    let totalAccounts: Int
    let totalEquity: Double
    let totalCash: Double
    let totalBuyingPower: Double
    let totalAvailableFunds: Double
    let totalDailyPnl: Double
    let totalUnrealizedPnl: Double
    let totalRealizedPnl: Double
    let totalPnl: Double

    let brokerageValue: Double
    let propFirmValue: Double
    let cryptoValue: Double
    let retirementValue: Double
    let businessValue: Double
    let cashReserveValue: Double

    let portfolioTone: String
    let headline: String
    let summary: String
    let warnings: [String]
    let actions: [String]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case totalAccounts = "total_accounts"
        case totalEquity = "total_equity"
        case totalCash = "total_cash"
        case totalBuyingPower = "total_buying_power"
        case totalAvailableFunds = "total_available_funds"
        case totalDailyPnl = "total_daily_pnl"
        case totalUnrealizedPnl = "total_unrealized_pnl"
        case totalRealizedPnl = "total_realized_pnl"
        case totalPnl = "total_pnl"

        case brokerageValue = "brokerage_value"
        case propFirmValue = "prop_firm_value"
        case cryptoValue = "crypto_value"
        case retirementValue = "retirement_value"
        case businessValue = "business_value"
        case cashReserveValue = "cash_reserve_value"

        case portfolioTone = "portfolio_tone"
        case headline
        case summary
        case warnings
        case actions
    }
}

struct PortfolioAIResponse: Codable {
    let userId: String
    let symbol: String?
    let selection: AccountSelectionResponse

    let riskScore: Int
    let portfolioTone: String
    let headline: String
    let summary: String

    let cashContext: String
    let exposureContext: String
    let accountContext: String

    let warnings: [String]
    let actions: [String]
    let opportunities: [String]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case symbol
        case selection
        case riskScore = "risk_score"
        case portfolioTone = "portfolio_tone"
        case headline
        case summary
        case cashContext = "cash_context"
        case exposureContext = "exposure_context"
        case accountContext = "account_context"
        case warnings
        case actions
        case opportunities
    }
}

struct ExecutionAnalyzeRequest: Codable {
    let symbol: String
    let side: String
    let quantity: Double?
    let orderType: String

    let broker: String?
    let accountId: String?
    let accountGroup: String?
    let selectionMode: String?

    let estimatedCost: Double?
    let estimatedRisk: Double?
    let maxRiskPercent: Double?

    let userIntent: String?
    let holdingStyle: String?
    let riskPreference: String?
    let notes: String?

    let requestAutoExecution: Bool

    enum CodingKeys: String, CodingKey {
        case symbol
        case side
        case quantity
        case orderType = "order_type"

        case broker
        case accountId = "account_id"
        case accountGroup = "account_group"
        case selectionMode = "selection_mode"

        case estimatedCost = "estimated_cost"
        case estimatedRisk = "estimated_risk"
        case maxRiskPercent = "max_risk_percent"

        case userIntent = "user_intent"
        case holdingStyle = "holding_style"
        case riskPreference = "risk_preference"
        case notes

        case requestAutoExecution = "request_auto_execution"
    }
}

struct ExecutionAnalyzeResponse: Codable {
    let success: Bool
    let mode: String
    let message: String

    let portfolioAI: PortfolioAIResponse
    let selection: AccountSelectionResponse
    let approval: TradeApprovalDecisionResponse
    let route: ExecutionRouteDecisionResponse

    enum CodingKeys: String, CodingKey {
        case success
        case mode
        case message
        case portfolioAI = "portfolio_ai"
        case selection
        case approval
        case route
    }
}

struct TradeApprovalDecisionResponse: Codable {
    let symbol: String
    let side: String
    let quantity: Double?

    let approved: Bool
    let autoExecutionAllowed: Bool

    let accountId: String?
    let accountName: String?
    let broker: String?
    let accountClass: String?

    let approvalStatus: String
    let confidence: Int
    let riskScore: Int

    let headline: String
    let summary: String

    let reasons: [String]
    let warnings: [String]
    let actions: [String]

    enum CodingKeys: String, CodingKey {
        case symbol
        case side
        case quantity
        case approved
        case autoExecutionAllowed = "auto_execution_allowed"

        case accountId = "account_id"
        case accountName = "account_name"
        case broker
        case accountClass = "account_class"

        case approvalStatus = "approval_status"
        case confidence
        case riskScore = "risk_score"

        case headline
        case summary
        case reasons
        case warnings
        case actions
    }
}

struct ExecutionRouteDecisionResponse: Codable {
    let symbol: String
    let side: String
    let quantity: Double?
    let orderType: String

    let approvedForRouting: Bool
    let approvedForAutoExecution: Bool

    let broker: String?
    let provider: String?
    let accountId: String?
    let accountName: String?
    let accountClass: String?

    let routeStatus: String
    let confidence: Int
    let riskScore: Int

    let headline: String
    let summary: String

    let reasons: [String]
    let warnings: [String]
    let actions: [String]

    enum CodingKeys: String, CodingKey {
        case symbol
        case side
        case quantity
        case orderType = "order_type"

        case approvedForRouting = "approved_for_routing"
        case approvedForAutoExecution = "approved_for_auto_execution"

        case broker
        case provider
        case accountId = "account_id"
        case accountName = "account_name"
        case accountClass = "account_class"

        case routeStatus = "route_status"
        case confidence
        case riskScore = "risk_score"

        case headline
        case summary
        case reasons
        case warnings
        case actions
    }
}
