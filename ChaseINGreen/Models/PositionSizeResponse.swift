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
        case symbol, broker, confidence, tone, priority, headline, summary
        case reasons, warnings, actions
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
        broker = try container.decodeIfPresent(String.self, forKey: .broker)
        accountKey = try container.decodeIfPresent(String.self, forKey: .accountKey)

        accountBalance = try container.decodeIfPresent(Double.self, forKey: .accountBalance)
        accountEquity = try container.decodeIfPresent(Double.self, forKey: .accountEquity)
        buyingPower = try container.decodeIfPresent(Double.self, forKey: .buyingPower)

        recommendedSize = try container.decodeIfPresent(Double.self, forKey: .recommendedSize)
        maxSize = try container.decodeIfPresent(Double.self, forKey: .maxSize)
        minSize = try container.decodeIfPresent(Double.self, forKey: .minSize)

        riskPercent = try container.decodeIfPresent(Double.self, forKey: .riskPercent)
        dollarRisk = try container.decodeIfPresent(Double.self, forKey: .dollarRisk)

        sizeProfile = try container.decodeIfPresent(String.self, forKey: .sizeProfile)
        instrumentType = try container.decodeIfPresent(String.self, forKey: .instrumentType)
        sizingMode = try container.decodeIfPresent(String.self, forKey: .sizingMode)

        pdtSensitive = try container.decodeIfPresent(Bool.self, forKey: .pdtSensitive)
        propFirmMode = try container.decodeIfPresent(Bool.self, forKey: .propFirmMode)
        tradeAllowed = try container.decodeIfPresent(Bool.self, forKey: .tradeAllowed)

        confidence = try container.decodeIfPresent(Int.self, forKey: .confidence)
        riskScore = try container.decodeIfPresent(Int.self, forKey: .riskScore)
        tone = try container.decodeIfPresent(String.self, forKey: .tone)
        priority = try container.decodeIfPresent(String.self, forKey: .priority)

        headline = try container.decodeIfPresent(String.self, forKey: .headline)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)

        reasons = Self.decodeStringList(container, .reasons)
        warnings = Self.decodeStringList(container, .warnings)
        actions = Self.decodeStringList(container, .actions)
    }

    private static func decodeStringList(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> [String]? {
        if let array = try? container.decodeIfPresent([String].self, forKey: key) {
            return array
        }

        if let string = try? container.decodeIfPresent(String.self, forKey: key) {
            let rows = string
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            return rows.isEmpty ? nil : rows
        }

        return nil
    }
}
