//
//  TraderDashboardResponse.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import Foundation

struct TraderDashboardResponse: Codable {
    let userId: String?
    let accountKey: String?
    let headline: String?
    let dashboardTone: String?
    let coachingSummary: String?

    let journalCount: Int?
    let followedPlanRate: Double?
    let respectedStopRate: Double?
    let revengeTradeCount: Int?
    let oversizedCount: Int?
    let exitedTooEarlyCount: Int?
    let heldTooLongCount: Int?
    let dominantMood: String?

    let keyStrengths: String?
    let keyWeaknesses: String?
    let alerts: String?
    let nextActions: String?

    let totalTrades: Int?
    let winRate: Double?
    let averagePnl: Double?
    let totalPnl: Double?
    let greenDays: Int?
    let redDays: Int?

    let strongestMemory: String?
    let weakestMemory: String?
    let strongestPattern: String?
    let weakestPattern: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case accountKey = "account_key"
        case headline
        case dashboardTone = "dashboard_tone"
        case coachingSummary = "coaching_summary"

        case journalCount = "journal_count"
        case followedPlanRate = "followed_plan_rate"
        case respectedStopRate = "respected_stop_rate"
        case revengeTradeCount = "revenge_trade_count"
        case oversizedCount = "oversized_count"
        case exitedTooEarlyCount = "exited_too_early_count"
        case heldTooLongCount = "held_too_long_count"
        case dominantMood = "dominant_mood"

        case keyStrengths = "key_strengths"
        case keyWeaknesses = "key_weaknesses"
        case alerts
        case nextActions = "next_actions"

        case totalTrades = "total_trades"
        case winRate = "win_rate"
        case averagePnl = "average_pnl"
        case totalPnl = "total_pnl"
        case greenDays = "green_days"
        case redDays = "red_days"

        case strongestMemory = "strongest_memory"
        case weakestMemory = "weakest_memory"
        case strongestPattern = "strongest_pattern"
        case weakestPattern = "weakest_pattern"
    }
}
