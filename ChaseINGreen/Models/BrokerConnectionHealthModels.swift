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

    enum CodingKeys: String, CodingKey {
        case success
        case userId = "user_id"
        case connectionCount = "connection_count"
        case healthyConnections = "healthy_connections"
        case companies
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
