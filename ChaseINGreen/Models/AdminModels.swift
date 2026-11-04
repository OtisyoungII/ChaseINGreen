//
//  AdminModels.swift
//  ChaseINGreen
//
//  Created by Otis Young on 5/28/26.
//



import Foundation

struct AdminDashboardResponse: Codable {
    let users: AdminDashboardUserCounts
    let trades: AdminDashboardTradeCounts
}

struct AdminDashboardUserCounts: Codable {
    let total: Int
    let free: Int
    let premium: Int
    let gold: Int
    let secret: Int
    let secretAccessCount: Int?
    let secretNonAdminCount: Int?
    let admin: Int
    let banned: Int

    enum CodingKeys: String, CodingKey {
        case total, free, premium, gold, secret, admin, banned
        case secretAccessCount = "secret_access_count"
        case secretNonAdminCount = "secret_non_admin_count"
    }
}

enum AdminUserBadgeKind: String, Equatable {
    case free
    case gold
    case secret
    case admin
    case banned
    case apple
    case tester

    var label: String { rawValue.uppercased() }
}

struct AdminDashboardTradeCounts: Codable {
    let open: Int
    let closed: Int
}

struct AdminUserResponse: Identifiable, Codable {
    let id: UUID
    let auth0UserId: String
    let email: String?
    let alias: String?
    let plan: String
    let isPremium: Bool
    let isGold: Bool
    let isSecret: Bool
    let isAdmin: Bool
    let adminPlanOverride: String?
    let appleSubscriptionActive: Bool?
    let appleSubscriptionProductId: String?
    let appleSubscriptionExpiresAt: String?
    let testerGroup: String?
    let appVersionLabel: String?
    let notes: String?
    let isBanned: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case auth0UserId = "auth0_user_id"
        case email
        case alias
        case plan
        case isPremium = "is_premium"
        case isGold = "is_gold"
        case isSecret = "is_secret"
        case isAdmin = "is_admin"
        case adminPlanOverride = "admin_plan_override"
        case appleSubscriptionActive = "apple_subscription_active"
        case appleSubscriptionProductId = "apple_subscription_product_id"
        case appleSubscriptionExpiresAt = "apple_subscription_expires_at"
        case testerGroup = "tester_group"
        case appVersionLabel = "app_version_label"
        case notes
        case isBanned = "is_banned"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var identityProvider: String {
        let subject = auth0UserId.lowercased()
        if subject.hasPrefix("apple|") { return "apple" }
        if subject.hasPrefix("google-oauth2|") { return "google" }
        if subject.hasPrefix("auth0|") { return "auth0" }
        return subject.split(separator: "|").first.map(String.init) ?? "unknown"
    }

    var bestAdminIdentity: String {
        if let email = email?.trimmingCharacters(in: .whitespacesAndNewlines),
           !email.isEmpty {
            return email
        }
        if let alias = alias?.trimmingCharacters(in: .whitespacesAndNewlines),
           !alias.isEmpty {
            return alias
        }
        let suffix = auth0UserId.split(separator: "|").last.map(String.init) ?? auth0UserId
        return suffix.count > 12
            ? "…" + suffix.suffix(12)
            : suffix
    }

    var adminBadges: [AdminUserBadgeKind] {
        var result: [AdminUserBadgeKind] = []
        if isAdmin {
            result.append(.admin)
        } else if isGold || plan.lowercased() == "gold" {
            result.append(.gold)
        } else {
            result.append(.free)
        }
        if isSecret { result.append(.secret) }
        if isBanned { result.append(.banned) }
        if identityProvider == "apple" { result.append(.apple) }
        if testerGroup?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            result.append(.tester)
        }
        return result
    }

    var rosterAccent: AdminUserBadgeKind {
        if isBanned { return .banned }
        if isAdmin { return .admin }
        if isSecret { return .secret }
        if isGold { return .gold }
        return .free
    }
}


struct AdminUserUpdateRequest: Codable {
    let alias: String?
    let plan: String?
    let isPremium: Bool?
    let isGold: Bool?
    let isSecret: Bool?
    let isAdmin: Bool?
    let testerGroup: String?
    let appVersionLabel: String?
    let notes: String?
    let isBanned: Bool?

    enum CodingKeys: String, CodingKey {
        case alias
        case plan
        case isPremium = "is_premium"
        case isGold = "is_gold"
        case isSecret = "is_secret"
        case isAdmin = "is_admin"
        case testerGroup = "tester_group"
        case appVersionLabel = "app_version_label"
        case notes
        case isBanned = "is_banned"
    }
}

struct ProductIntelligenceResponse: Decodable {
    struct Overview: Decodable {
        let total_accounts: Int
        let new_accounts: Int
        let active_accounts: Int
        let dau: Int
        let wau: Int
        let mau: Int
        let returning_accounts: Int
        let authenticated_sessions: Int
        let return_rate: Double?
    }
    let overview: Overview
    let available_since: String?
    let collection_enabled: Bool
    let sample_truncated: Bool
    let features: [String: Int]
    let platform_event_counts: [String: Int]
    let device_event_counts: [String: Int]
    let os_event_counts: [String: Int]
    let release_active_accounts: [String: Int]
    let plan_accounts: [String: Int]
    let pipeline_event_counts: [String: Int]
    let broker_outcomes_by_release: [String: Int]
    let reliability_categories: [String: Int]
    let workflow_completions: [String: Int]
    let daily_active: [String: Int]
    let new_accounts_by_day: [String: Int]
    struct BrokerMetrics: Decodable {
        let events: Int
        let sync_attempts: Int
        let sync_successes: Int
        let sync_failures: Int
        let membership_complete: Int
        let valuation_complete: Int
        let pnl_complete: Int
        let basis_incomplete: Int
        let valuation_observations: Int
        let pnl_observations: Int
        let stale_events: Int
        let average_latency_ms: Double?
        let p50_latency_ms: Double?
        let p95_latency_ms: Double?
        let last_success_at: String?
        var counts: [String: Int] {
            ["Observed events": events, "Sync attempts": sync_attempts, "Successful syncs": sync_successes,
             "Failed syncs": sync_failures, "Membership complete": membership_complete,
             "Valuation complete (observed)": valuation_complete, "P/L complete (observed)": pnl_complete,
             "Valuation observations": valuation_observations, "P/L observations": pnl_observations,
             "Unknown basis": basis_incomplete, "Stale observations": stale_events]
        }
    }
    struct AccountInventory: Decodable {
        let source_mode: String
        let provider: String
        let count: Int
    }
    struct ConnectionInventory: Decodable {
        let provider: String
        let active: Bool
        let count: Int
    }
    let account_inventory: [AccountInventory]
    let connection_inventory: [ConnectionInventory]
    let brokers: [String: BrokerMetrics]
    let same_request_mark_pl_disagreements: Int
    let limitations: [String]
}
