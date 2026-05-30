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
    let admin: Int
    let banned: Int
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
        case testerGroup = "tester_group"
        case appVersionLabel = "app_version_label"
        case notes
        case isBanned = "is_banned"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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
