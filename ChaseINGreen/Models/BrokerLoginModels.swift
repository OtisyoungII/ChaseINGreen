//
//  BrokerLoginModels.swift
//  ChaseINGreen
//
//  By: Otis Young II
// --------------------------------------------------------------
// ✅ Match-Trader token login/sync payloads
// ✅ IBKR health/sync responses
// ✅ Broker sync response models for Bat Cave
// ✅ No live trading or order execution here
// --------------------------------------------------------------

import Foundation

struct MatchTraderSyncRequest: Codable {
    let serverURL: String
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let expiresAt: String?

    let broker: String?
    let accountLabel: String?
    let accountId: String?
    let accountName: String?

    let startingBalance: Double?
    let dailyDrawdownLimit: Double?
    let maxDrawdownLimit: Double?
    let symbols: [String]

    enum CodingKeys: String, CodingKey {
        case serverURL = "server_url"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresAt = "expires_at"

        case broker
        case accountLabel = "account_label"
        case accountId = "account_id"
        case accountName = "account_name"

        case startingBalance = "starting_balance"
        case dailyDrawdownLimit = "daily_drawdown_limit"
        case maxDrawdownLimit = "max_drawdown_limit"
        case symbols
    }
}

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
    let accounts: [UnifiedPortfolioAccount]?

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
        case warnings
        case actions
    }
}

struct IBKRHealthResponse: Codable {
    let success: Bool?
    let status: String?
    let service: String?
    let authenticated: Bool?
    let connected: Bool?
    let competing: Bool?
    let message: String?
}
