//
//  PositionSizeResponse.swift
//  ChaseINGreen
//
//  Created by Otis Young on 7/4/26.
//

import Foundation

struct PositionSizeResponse: Codable {
    let success: Bool?
    let positionSize: PositionSizeBlock?

    enum CodingKeys: String, CodingKey {
        case success
        case positionSize = "position_size"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        success = try container.decodeIfPresent(Bool.self, forKey: .success)

        if let wrapped = try container.decodeIfPresent(PositionSizeBlock.self, forKey: .positionSize) {
            positionSize = wrapped
        } else {
            positionSize = try? PositionSizeBlock(from: decoder)
        }
    }
}

struct PositionSizeBlock: Codable {
    let symbol: String?
    let broker: String?
    let accountKey: String?

    let accountBalance: Double?
    let accountEquity: Double?
    let buyingPower: Double?

    let recommendedSize: Double?
    let maxSize: Double?
    let minSize: Double?

    let riskPercent: Double?
    let dollarRisk: Double?

    let sizeProfile: String?
    let instrumentType: String?
    let sizingMode: String?

    let pdtSensitive: Bool?
    let propFirmMode: Bool?
    let tradeAllowed: Bool?

    let confidence: Int?
    let riskScore: Int?
    let tone: String?
    let priority: String?

    let headline: String?
    let summary: String?

    let reasons: [String]?
    let warnings: [String]?
    let actions: [String]?

    enum CodingKeys: String, CodingKey {
        case symbol, broker, confidence, tone, priority, headline, summary, reasons, warnings, actions

        case accountKey = "account_key"
        case accountBalance = "account_balance"
        case accountEquity = "account_equity"
        case buyingPower = "buying_power"

        case recommendedSize = "recommended_size"
        case maxSize = "max_size"
        case minSize = "min_size"

        case riskPercent = "risk_percent"
        case dollarRisk = "dollar_risk"

        case sizeProfile = "size_profile"
        case instrumentType = "instrument_type"
        case sizingMode = "sizing_mode"

        case pdtSensitive = "pdt_sensitive"
        case propFirmMode = "prop_firm_mode"
        case tradeAllowed = "trade_allowed"

        case riskScore = "risk_score"
    }
}
