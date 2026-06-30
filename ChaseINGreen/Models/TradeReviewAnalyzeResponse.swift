//
//  TradeReviewAnalyzeResponse.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import Foundation

struct TradeReviewAnalyzeResponse: Codable {
    let success: Bool

    let tradeId: String
    let accountKey: String?

    let scopedTradesCount: Int
    let allTradesCount: Int

    let outcome: TradeOutcomeResponse
    let review: TradeReviewDetailResponse
    let memory: TraderMemoryResponse?
    let patterns: PatternDiscoveryResponse?
    let profile: TraderProfileResponse?
    let calendar: TradingCalendarReportResponse?

    enum CodingKeys: String, CodingKey {
        case success
        case tradeId = "trade_id"
        case accountKey = "account_key"
        case scopedTradesCount = "scoped_trades_count"
        case allTradesCount = "all_trades_count"
        case outcome
        case review
        case memory
        case patterns
        case profile
        case calendar
    }
}

struct TradeOutcomeResponse: Codable {
    let outcomeGrade: Int?
    let outcomeSummary: String?
    let labels: String?

    let entryQualityScore: Int?
    let exitQualityScore: Int?
    let riskQualityScore: Int?
    let timingQualityScore: Int?
    let managementQualityScore: Int?

    enum CodingKeys: String, CodingKey {
        case outcomeGrade = "outcome_grade"
        case outcomeSummary = "outcome_summary"
        case labels

        case entryQualityScore = "entry_quality_score"
        case exitQualityScore = "exit_quality_score"
        case riskQualityScore = "risk_quality_score"
        case timingQualityScore = "timing_quality_score"
        case managementQualityScore = "management_quality_score"
    }
}
struct TradeReviewDetailResponse: Codable {
    let symbol: String?
    let headline: String?
    let summary: String?

    let overallGrade: Int?
    let gradeLetter: String?

    let strengths: String?
    let improvements: String?
    let coachingNotes: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case headline
        case summary

        case overallGrade = "overall_grade"
        case gradeLetter = "grade_letter"

        case strengths
        case improvements

        case coachingNotes = "coaching_notes"
    }
}
