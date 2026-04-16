//
//  SetupModel.swift
//  ChaseINGreen
//
//  Created by Otis Young on 4/16/26.
//

import Foundation

struct HealthResponse: Codable {
    let status: String
    let service: String?
    let app: String?
    let message: String?
}

struct SetupResponse: Codable {
    let ticker: String
    let status: String
    let dailyBias: String
    let setupType: String
    let currentPrice: Double?
    let levels: Levels
    let timeframes: Timeframes
    let confidence: Int
    let triggerReady: Bool
    let alertText: String

    enum CodingKeys: String, CodingKey {
        case ticker
        case status
        case dailyBias = "daily_bias"
        case setupType = "setup_type"
        case currentPrice = "current_price"
        case levels
        case timeframes
        case confidence
        case triggerReady = "trigger_ready"
        case alertText = "alert_text"
    }
}

struct Levels: Codable {
    let currentPrice: Double?
    let prevDayHigh: Double?
    let prevDayLow: Double?
    let prevDayClose: Double?

    enum CodingKeys: String, CodingKey {
        case currentPrice = "current_price"
        case prevDayHigh = "prev_day_high"
        case prevDayLow = "prev_day_low"
        case prevDayClose = "prev_day_close"
    }
}

struct Timeframes: Codable {
    let oneDay: TimeframeDetail
    let fourHour: TimeframeDetail
    let oneHour: TimeframeDetail
    let fifteenMinute: TimeframeDetail

    enum CodingKeys: String, CodingKey {
        case oneDay = "1d"
        case fourHour = "4h"
        case oneHour = "1h"
        case fifteenMinute = "15m"
    }
}

struct TimeframeDetail: Codable {
    let timeframe: String
    let trend: String
    let macdState: String
    let rsi: Double?
    let volumeState: String
    let triggerReady: Bool
    let notes: String

    enum CodingKeys: String, CodingKey {
        case timeframe
        case trend
        case macdState = "macd_state"
        case rsi
        case volumeState = "volume_state"
        case triggerReady = "trigger_ready"
        case notes
    }
}
