//
//  MarketCandle.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/13/26.
//


import Foundation



struct MarketCandle: Codable, Identifiable {
    let timestamp: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double

    var id: Date { timestamp }
}
