//
//  TradeModels.swift
//  ChaseINGreen
//
//  Created by Otis Young on 4/16/26.
//

import Foundation

enum TradeAsset: String, CaseIterable, Identifiable, Codable {
    case gold
    case bitcoin
    case oil
    case silver
    case ethereum

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gold: return "Gold"
        case .bitcoin: return "Bitcoin"
        case .oil: return "Oil"
        case .silver: return "Silver"
        case .ethereum: return "Ethereum"
        }
    }

    var systemImage: String {
        switch self {
        case .gold: return "medal.fill"
        case .bitcoin: return "bitcoinsign.circle.fill"
        case .oil: return "drop.fill"
        case .silver: return "circle.hexagongrid.fill"
        case .ethereum: return "e.circle.fill"
        }
    }
}

enum TradeDirection: String, CaseIterable, Identifiable, Codable {
    case buy
    case sell

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

struct Trade: Identifiable, Codable, Hashable {
    let id: UUID
    var asset: TradeAsset
    var direction: TradeDirection
    var entryPrice: String
    var stopLoss: String
    var takeProfit: String
    var openedAt: Date
    var notes: String
    var isActive: Bool

    init(
        id: UUID = UUID(),
        asset: TradeAsset,
        direction: TradeDirection,
        entryPrice: String,
        stopLoss: String,
        takeProfit: String,
        openedAt: Date,
        notes: String = "",
        isActive: Bool = true
    ) {
        self.id = id
        self.asset = asset
        self.direction = direction
        self.entryPrice = entryPrice
        self.stopLoss = stopLoss
        self.takeProfit = takeProfit
        self.openedAt = openedAt
        self.notes = notes
        self.isActive = isActive
    }
}

extension Trade {
    static let sampleData: [Trade] = [
        Trade(
            asset: .bitcoin,
            direction: .buy,
            entryPrice: "68425.50",
            stopLoss: "67980.00",
            takeProfit: "69200.00",
            openedAt: .now.addingTimeInterval(-3600),
            notes: "Watching breakout continuation."
        ),
        Trade(
            asset: .gold,
            direction: .sell,
            entryPrice: "2361.80",
            stopLoss: "2368.40",
            takeProfit: "2348.20",
            openedAt: .now.addingTimeInterval(-5400),
            notes: "Short from resistance."
        ),
        Trade(
            asset: .oil,
            direction: .buy,
            entryPrice: "81.24",
            stopLoss: "80.70",
            takeProfit: "82.10",
            openedAt: .now.addingTimeInterval(-1800),
            notes: "Momentum push after reclaim."
        )
    ]
}
