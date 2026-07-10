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

// MARK: - Sanitized Connection Features

struct MatchTraderConnectionFeatures: Codable {
    let provider: String?
    let broker: String?
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
        case provider
        case broker
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
    let systemName: String?
    let systemActive: Bool?
    let systemDemo: Bool?

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
        case systemName = "system_name"
        case systemActive = "system_active"
        case systemDemo = "system_demo"

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
