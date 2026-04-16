//
//  SetupModel.swift
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
        case .silver: return "circle.fill"
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

enum TradeStatus: String, CaseIterable, Identifiable, Codable {
    case open
    case partial
    case closed

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

struct Trade: Identifiable, Codable, Equatable {
    let id: UUID
    var asset: TradeAsset
    var direction: TradeDirection
    var status: TradeStatus
    var entryPrice: String
    var currentPrice: String
    var stopLoss: String
    var takeProfit: String
    var openedAt: Date
    var closedAt: Date?
    var notes: String

    init(
        id: UUID = UUID(),
        asset: TradeAsset,
        direction: TradeDirection,
        status: TradeStatus = .open,
        entryPrice: String,
        currentPrice: String = "",
        stopLoss: String = "",
        takeProfit: String = "",
        openedAt: Date = .now,
        closedAt: Date? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.asset = asset
        self.direction = direction
        self.status = status
        self.entryPrice = entryPrice
        self.currentPrice = currentPrice
        self.stopLoss = stopLoss
        self.takeProfit = takeProfit
        self.openedAt = openedAt
        self.closedAt = closedAt
        self.notes = notes
    }
}

struct TradeDraft: Equatable {
    var id: UUID? = nil
    var asset: TradeAsset = .bitcoin
    var direction: TradeDirection = .buy
    var status: TradeStatus = .open
    var entryPrice: String = ""
    var currentPrice: String = ""
    var stopLoss: String = ""
    var takeProfit: String = ""
    var openedAt: Date = .now
    var closedAt: Date? = nil
    var notes: String = ""

    init() {}

    init(asset: TradeAsset) {
        self.asset = asset
    }

    init(from trade: Trade) {
        self.id = trade.id
        self.asset = trade.asset
        self.direction = trade.direction
        self.status = trade.status
        self.entryPrice = trade.entryPrice
        self.currentPrice = trade.currentPrice
        self.stopLoss = trade.stopLoss
        self.takeProfit = trade.takeProfit
        self.openedAt = trade.openedAt
        self.closedAt = trade.closedAt
        self.notes = trade.notes
    }

    func asTrade() -> Trade {
        Trade(
            id: id ?? UUID(),
            asset: asset,
            direction: direction,
            status: status,
            entryPrice: entryPrice,
            currentPrice: currentPrice,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
            openedAt: openedAt,
            closedAt: closedAt,
            notes: notes
        )
    }
}

extension Trade {
    static let sampleData: [Trade] = [
        Trade(
            asset: .bitcoin,
            direction: .buy,
            status: .open,
            entryPrice: "68425.50",
            currentPrice: "68610.20",
            stopLoss: "67980.00",
            takeProfit: "69200.00",
            openedAt: .now.addingTimeInterval(-3200),
            notes: "Watching continuation."
        ),
        Trade(
            asset: .gold,
            direction: .sell,
            status: .partial,
            entryPrice: "2361.80",
            currentPrice: "2357.40",
            stopLoss: "2368.40",
            takeProfit: "2348.20",
            openedAt: .now.addingTimeInterval(-5400),
            notes: "Short from resistance."
        ),
        Trade(
            asset: .oil,
            direction: .buy,
            status: .open,
            entryPrice: "81.24",
            currentPrice: "81.66",
            stopLoss: "80.70",
            takeProfit: "82.10",
            openedAt: .now.addingTimeInterval(-1900),
            notes: "Momentum push after reclaim."
        )
    ]
}
