//
//  TradingCalendarResponse.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//



import Foundation

struct TradingCalendarReportResponse: Codable {
    let totalDays: Int?
    let greenDays: Int?
    let redDays: Int?
    let flatDays: Int?
    let totalPnl: Double?
    let averageDailyPnl: Double?

    enum CodingKeys: String, CodingKey {
        case totalDays = "total_days"
        case greenDays = "green_days"
        case redDays = "red_days"
        case flatDays = "flat_days"
        case totalPnl = "total_pnl"
        case averageDailyPnl = "average_daily_pnl"
    }
}
