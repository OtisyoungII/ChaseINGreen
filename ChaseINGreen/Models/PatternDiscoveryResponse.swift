//
//  PatternDiscoveryResponse.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import Foundation

struct PatternDiscoveryResponse: Codable {
    let userId: String?
    let totalPatterns: Int?

    let strongestPatternKey: String?
    let strongestPatternType: String?
    let strongestPatternWinRate: Double?
    let strongestPatternAveragePnl: Double?

    let weakestPatternKey: String?
    let weakestPatternType: String?
    let weakestPatternWinRate: Double?
    let weakestPatternAveragePnl: Double?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case totalPatterns = "total_patterns"

        case strongestPatternKey = "strongest_pattern_key"
        case strongestPatternType = "strongest_pattern_type"
        case strongestPatternWinRate = "strongest_pattern_win_rate"
        case strongestPatternAveragePnl = "strongest_pattern_average_pnl"

        case weakestPatternKey = "weakest_pattern_key"
        case weakestPatternType = "weakest_pattern_type"
        case weakestPatternWinRate = "weakest_pattern_win_rate"
        case weakestPatternAveragePnl = "weakest_pattern_average_pnl"
    }
}