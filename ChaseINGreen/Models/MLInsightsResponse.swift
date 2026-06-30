//
//  MLInsightsResponse.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import Foundation

struct MLInsightsResponse: Codable {
    let traderMemory: TraderMemoryResponse?
    let patternDiscovery: PatternDiscoveryResponse?
    let traderProfile: TraderProfileResponse?
    let calendar: TradingCalendarReportResponse?
    let dashboard: TraderDashboardResponse?

    let headline: String?
    let summary: String?
    let tone: String?

    enum CodingKeys: String, CodingKey {
        case traderMemory = "trader_memory"
        case patternDiscovery = "pattern_discovery"
        case traderProfile = "trader_profile"
        case calendar
        case dashboard
        case headline
        case summary
        case tone
    }
}
