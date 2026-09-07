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
