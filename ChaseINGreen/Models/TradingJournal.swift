//
//  TradeJournal.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import Foundation

struct TradeJournalResponse: Codable, Identifiable {
    let id: UUID
    let tradeId: UUID?
    let symbol: String?
    let direction: String?
    let broker: String?
    let netPnl: Double?
    let notes: String?
    let moodBefore: String?
    let moodDuring: String?
    let moodAfter: String?
    let followedPlan: Bool?
    let respectedStopLoss: Bool?
    let exitedTooEarly: Bool?
    let heldTooLong: Bool?
    let oversizedPosition: Bool?
    let revengeTrade: Bool?
    let selfGrade: String?
    let openedAt: String?
    let closedAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case tradeId = "trade_id"
        case symbol
        case direction, broker
        case netPnl = "net_pnl"
        case notes
        case moodBefore = "mood_before"
        case moodDuring = "mood_during"
        case moodAfter = "mood_after"
        case followedPlan = "followed_plan"
        case respectedStopLoss = "respected_stop_loss"
        case exitedTooEarly = "exited_too_early"
        case heldTooLong = "held_too_long"
        case oversizedPosition = "oversized_position"
        case revengeTrade = "revenge_trade"
        case selfGrade = "self_grade"
        case openedAt = "opened_at"
        case closedAt = "closed_at"
        case createdAt = "created_at"
    }
}

struct TradeJournalUpdateRequest: Codable {
    let notes: String?
}

struct TradeJournalCreateRequest: Codable {
    let tradeId: UUID?
    let symbol: String
    let notes: String?
    let moodBefore: String?
    let moodDuring: String?
    let moodAfter: String?
    let followedPlan: Bool?
    let respectedStopLoss: Bool?
    let exitedTooEarly: Bool?
    let heldTooLong: Bool?
    let oversizedPosition: Bool?
    let revengeTrade: Bool?
    let selfGrade: String?

    enum CodingKeys: String, CodingKey {
        case tradeId = "trade_id"
        case symbol
        case notes
        case moodBefore = "mood_before"
        case moodDuring = "mood_during"
        case moodAfter = "mood_after"
        case followedPlan = "followed_plan"
        case respectedStopLoss = "respected_stop_loss"
        case exitedTooEarly = "exited_too_early"
        case heldTooLong = "held_too_long"
        case oversizedPosition = "oversized_position"
        case revengeTrade = "revenge_trade"
        case selfGrade = "self_grade"
    }
}
