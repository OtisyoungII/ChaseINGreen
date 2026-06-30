//
//  TraderMemoryResponse.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import Foundation

struct TraderMemoryResponse: Codable {
    let userId: String?
    let totalTrades: Int?
    let openTrades: Int?
    let closedTrades: Int?

    let winningTrades: Int?
    let losingTrades: Int?
    let winRate: Double?

    let totalPnl: Double?
    let averagePnl: Double?
    let bestSymbol: String?
    let worstSymbol: String?
    

    let biggestStrength: String?
    let biggestWeakness: String?
    let summary: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case totalTrades = "total_trades"
        case openTrades = "open_trades"
        case closedTrades = "closed_trades"

        case winningTrades = "winning_trades"
        case losingTrades = "losing_trades"
        case winRate = "win_rate"

        case totalPnl = "total_pnl"
        case averagePnl = "average_pnl"
        case bestSymbol = "best_symbol"
        case worstSymbol = "worst_symbol"

        case biggestStrength = "biggest_strength"
        case biggestWeakness = "biggest_weakness"
        case summary
    }
}
