//
//  BrokerConnectionHealthModels.swift
//  ChaseINGreen
//
//  By: Otis Young II
// --------------------------------------------------------------
// ✅ Models /broker-connections/health
// ✅ Powers Bat Cave broker status lights
// ✅ Supports multiple companies, providers, and login identities
// --------------------------------------------------------------

import Foundation

struct BrokerConnectionHealthResponse: Codable {
    let success: Bool?
    let userId: String?
    let connectionCount: Int?
    let healthyConnections: Int?
    let companies: [String: BrokerCompanyHealth]?
    let connections: [BrokerHeartbeat]?

    enum CodingKeys: String, CodingKey {
        case success
        case userId = "user_id"
        case connectionCount = "connection_count"
        case healthyConnections = "healthy_connections"
        case companies
        case connections
    }
}

struct BrokerHeartbeat: Codable, Identifiable {
    let provider: String
    let connectionId: String
    let displayName: String?
    let accountType: String?
    let connectionState: String
    let dataState: String
    let lastAttemptedSync: String?
    let lastSuccessfulSync: String?
    let positionCount: Int
    let accountValue: Double?
    let availableFunds: Double?
    let unrealizedPnl: Double?
    let degradedReason: String?

    var id: String { connectionId }

    enum CodingKeys: String, CodingKey {
        case provider
        case connectionId = "connection_id"
        case displayName = "display_name"
        case accountType = "account_type"
        case connectionState = "connection_state"
        case dataState = "data_state"
        case lastAttemptedSync = "last_attempted_sync"
        case lastSuccessfulSync = "last_successful_sync"
        case positionCount = "position_count"
        case accountValue = "account_value"
        case availableFunds = "available_funds"
        case unrealizedPnl = "unrealized_pnl"
        case degradedReason = "degraded_reason"
    }
}

struct BrokerCompanyHealth: Codable {
    let status: String?
    let connected: Int?
    let total: Int?
    let providers: [String: BrokerProviderHealth]?
}

struct BrokerProviderHealth: Codable {
    let status: String?
    let connectionName: String?
    let loginLabel: String?
    let lastSyncAt: String?
    let lastError: String?

    enum CodingKeys: String, CodingKey {
        case status
        case connectionName = "connection_name"
        case loginLabel = "login_label"
        case lastSyncAt = "last_sync_at"
        case lastError = "last_error"
    }
}
