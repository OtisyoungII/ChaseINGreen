//
//  MLInsightsResponse.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import Foundation

struct MLInsightsResponse: Codable {
    let success: Bool?
    let userId: String?
    let scope: String?
    let tradeId: String?
    let accountKey: String?
    let scopedTradesCount: Int?

    let outcome: TradeOutcomeResponse?
    let review: TradeReviewDetailResponse?
    let memory: TraderMemoryResponse?
    let patterns: PatternDiscoveryResponse?
    let profile: TraderProfileResponse?
    let calendar: TradingCalendarReportResponse?
    let dashboard: TraderDashboardResponse?

    let message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case userId = "user_id"
        case scope
        case tradeId = "trade_id"
        case accountKey = "account_key"
        case scopedTradesCount = "scoped_trades_count"

        case outcome
        case review
        case memory
        case patterns
        case profile
        case calendar
        case dashboard

        case message
    }
}

struct MLInsightsRequest: Codable {
    let tradeId: UUID?
    let accountKey: String?
    let broker: String?
    let symbol: String?
    let scope: String
    let includeOpenTrades: Bool
    let includeClosedTrades: Bool
    let includeInSharedModel: Bool

    init(
        tradeId: UUID? = nil,
        accountKey: String? = nil,
        broker: String? = nil,
        symbol: String? = nil,
        scope: String = "all",
        includeOpenTrades: Bool = true,
        includeClosedTrades: Bool = true,
        includeInSharedModel: Bool = false
    ) {
        self.tradeId = tradeId
        self.accountKey = accountKey
        self.broker = broker
        self.symbol = symbol
        self.scope = scope
        self.includeOpenTrades = includeOpenTrades
        self.includeClosedTrades = includeClosedTrades
        self.includeInSharedModel = includeInSharedModel
    }

    enum CodingKeys: String, CodingKey {
        case tradeId = "trade_id"
        case accountKey = "account_key"
        case broker
        case symbol
        case scope
        case includeOpenTrades = "include_open_trades"
        case includeClosedTrades = "include_closed_trades"
        case includeInSharedModel = "include_in_shared_model"
    }
}
