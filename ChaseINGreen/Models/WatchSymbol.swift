//
//  WatchSymbol.swift
//  ChaseINGreen
//
//  Shared dashboard and Trader OS market-symbol routing.
//

import Foundation

struct WatchSymbol: Identifiable, Hashable, Codable {
    let requestSymbol: String
    let displayName: String
    let tradeSymbol: String
    let systemImage: String
    let isCustom: Bool

    var id: String { requestSymbol }

    init(
        requestSymbol: String,
        displayName: String,
        tradeSymbol: String,
        systemImage: String,
        isCustom: Bool = false
    ) {
        self.requestSymbol = requestSymbol
        self.displayName = displayName
        self.tradeSymbol = tradeSymbol
        self.systemImage = systemImage
        self.isCustom = isCustom
    }

    static let presets: [WatchSymbol] = [
        .init(requestSymbol: "TQQQ", displayName: "TQQQ", tradeSymbol: "TQQQ", systemImage: "chart.line.uptrend.xyaxis"),
        .init(requestSymbol: "QQQ", displayName: "QQQ", tradeSymbol: "QQQ", systemImage: "chart.line.uptrend.xyaxis"),
        .init(requestSymbol: "SPY", displayName: "SPY", tradeSymbol: "SPY", systemImage: "chart.line.uptrend.xyaxis"),
        .init(requestSymbol: "NQ=F", displayName: "NQ", tradeSymbol: "NQ", systemImage: "chart.line.uptrend.xyaxis"),
        .init(requestSymbol: "ES=F", displayName: "ES", tradeSymbol: "ES", systemImage: "chart.line.uptrend.xyaxis"),
        .init(requestSymbol: "NVDA", displayName: "NVDA", tradeSymbol: "NVDA", systemImage: "cpu.fill"),
        .init(requestSymbol: "INTC", displayName: "INTC", tradeSymbol: "INTC", systemImage: "cpu.fill"),
        .init(requestSymbol: "MSFT", displayName: "MSFT", tradeSymbol: "MSFT", systemImage: "desktopcomputer"),
        .init(requestSymbol: "AAPL", displayName: "AAPL", tradeSymbol: "AAPL", systemImage: "apple.logo"),
        .init(requestSymbol: "AMZN", displayName: "AMZN", tradeSymbol: "AMZN", systemImage: "shippingbox.fill"),
        .init(requestSymbol: "META", displayName: "META", tradeSymbol: "META", systemImage: "network"),
        .init(requestSymbol: "TSLA", displayName: "TSLA", tradeSymbol: "TSLA", systemImage: "bolt.car.fill"),
        .init(requestSymbol: "SOXL", displayName: "SOXL", tradeSymbol: "SOXL", systemImage: "cpu.fill"),
        .init(requestSymbol: "SOXS", displayName: "SOXS", tradeSymbol: "SOXS", systemImage: "cpu.fill"),
        .init(requestSymbol: "PLTR", displayName: "PLTR", tradeSymbol: "PLTR", systemImage: "waveform.path.ecg"),
        .init(requestSymbol: "OKLO", displayName: "OKLO", tradeSymbol: "OKLO", systemImage: "atom"),
        .init(requestSymbol: "ROKU", displayName: "ROKU", tradeSymbol: "ROKU", systemImage: "tv.fill"),
        .init(requestSymbol: "RIOT", displayName: "RIOT", tradeSymbol: "RIOT", systemImage: "bitcoinsign.circle.fill"),
        .init(requestSymbol: "MRNA", displayName: "MRNA", tradeSymbol: "MRNA", systemImage: "cross.case.fill"),
        .init(requestSymbol: "EVTV", displayName: "EVTV", tradeSymbol: "EVTV", systemImage: "bolt.fill"),
        .init(requestSymbol: "SEGG", displayName: "SEGG", tradeSymbol: "SEGG", systemImage: "flame.fill"),
        .init(requestSymbol: "XOM", displayName: "XOM", tradeSymbol: "XOM", systemImage: "fuelpump.fill"),
        .init(requestSymbol: "CVX", displayName: "CVX", tradeSymbol: "CVX", systemImage: "fuelpump.fill"),
        .init(requestSymbol: "CL=F", displayName: "WTI Oil", tradeSymbol: "WTI", systemImage: "drop.fill"),
        .init(requestSymbol: "GC=F", displayName: "Gold", tradeSymbol: "XAUUSD", systemImage: "medal.fill"),
        .init(requestSymbol: "SI=F", displayName: "Silver", tradeSymbol: "XAGUSD", systemImage: "medal.fill"),
        .init(requestSymbol: "BTC-USD", displayName: "Bitcoin", tradeSymbol: "BTCUSD", systemImage: "bitcoinsign.circle.fill"),
        .init(requestSymbol: "^DJI", displayName: "US30", tradeSymbol: "US30", systemImage: "building.columns.fill")
    ]

    static func custom(_ raw: String) -> WatchSymbol {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        return WatchSymbol(
            requestSymbol: cleaned,
            displayName: cleaned,
            tradeSymbol: cleaned,
            systemImage: "star.circle.fill",
            isCustom: true
        )
    }
}
