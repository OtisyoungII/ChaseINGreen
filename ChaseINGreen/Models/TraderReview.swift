//
//  TradeReview.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import Foundation

struct TradeReviewResponse: Codable {
    let success: Bool?
    let symbol: String?
    let headline: String?
    let summary: String?
    let grade: Int?
    let score: Int?
    let reasons: [String]?
    let warnings: [String]?
    let actions: [String]?
}
