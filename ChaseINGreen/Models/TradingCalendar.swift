//
//  TradingCalendar.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import Foundation

// MARK: - Calendar Summary

struct TradingCalendarSummaryResponse: Codable {

    let totalDays: Int
    let greenDays: Int
    let redDays: Int
    let flatDays: Int

    let totalPnl: Double
    let averageDailyPnl: Double
    let winRate: Double

    enum CodingKeys: String, CodingKey {
        case totalDays = "total_days"
        case greenDays = "green_days"
        case redDays = "red_days"
        case flatDays = "flat_days"
        case totalPnl = "total_pnl"
        case averageDailyPnl = "average_daily_pnl"
        case winRate = "win_rate"
    }
}

// MARK: - Calendar Day

struct TradingCalendarDayResponse: Codable, Identifiable {

    var id: String { tradeDate }

    let tradeDate: String

    let accountKey: String?
    let accountName: String?
    let platform: String?

    let totalTrades: Int
    let closedTrades: Int?
    let openTrades: Int?
    let winningTrades: Int
    let losingTrades: Int
    let flatTrades: Int
    let confirmedPnlTrades: Int?
    let unconfirmedPnlTrades: Int?
    let needsReview: Bool?

    let grossPnl: Double
    let totalFees: Double
    let totalPnl: Double
    let averagePnl: Double

    let winRate: Double

    let bestTradePnl: Double?
    let worstTradePnl: Double?

    let calendarTone: String
    let summary: String

    enum CodingKeys: String, CodingKey {
        case tradeDate = "trade_date"
        case accountKey = "account_key"
        case accountName = "account_name"
        case platform

        case totalTrades = "total_trades"
        case closedTrades = "closed_trades"
        case openTrades = "open_trades"
        case winningTrades = "winning_trades"
        case losingTrades = "losing_trades"
        case flatTrades = "flat_trades"
        case confirmedPnlTrades = "confirmed_pnl_trades"
        case unconfirmedPnlTrades = "unconfirmed_pnl_trades"
        case needsReview = "needs_review"

        case grossPnl = "gross_pnl"
        case totalFees = "total_fees"
        case totalPnl = "total_pnl"
        case averagePnl = "average_pnl"

        case winRate = "win_rate"

        case bestTradePnl = "best_trade_pnl"
        case worstTradePnl = "worst_trade_pnl"

        case calendarTone = "calendar_tone"
        case summary
    }
}

// MARK: - Calendar Response

struct TradingCalendarResponse: Codable {

    let success: Bool
    let summary: TradingCalendarSummaryResponse
    let days: [TradingCalendarDayResponse]
}

// MARK: - Calendar Detail

struct TradingCalendarDayDetailResponse: Codable {

    let success: Bool
    let day: TradingCalendarDayResponse?
    let trades: [LoggedTradeResponse]
}
