//
//  TraderProfileResponse.swift
//

import Foundation

struct TraderProfileResponse: Codable {
    let traderType: String?
    let riskProfile: String?
    let disciplineScore: Int?
    let consistencyScore: Int?
    let confidenceScore: Int?

    let preferredDirection: String?
    let preferredHoldingTime: String?
    let preferredSession: String?
    let preferredSymbol: String?

    let summary: String?

    enum CodingKeys: String, CodingKey {
        case traderType = "trader_type"
        case riskProfile = "risk_profile"
        case disciplineScore = "discipline_score"
        case consistencyScore = "consistency_score"
        case confidenceScore = "confidence_score"

        case preferredDirection = "preferred_direction"
        case preferredHoldingTime = "preferred_holding_time"
        case preferredSession = "preferred_session"
        case preferredSymbol = "preferred_symbol"

        case summary
    }
}