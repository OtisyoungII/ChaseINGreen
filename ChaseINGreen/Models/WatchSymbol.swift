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
        .init(requestSymbol: "DIS", displayName: "Disney", tradeSymbol: "DIS", systemImage: "sparkles"),
        .init(requestSymbol: "GOOGL", displayName: "Google", tradeSymbol: "GOOGL", systemImage: "magnifyingglass"),
        .init(requestSymbol: "GOOG", displayName: "Alphabet C", tradeSymbol: "GOOG", systemImage: "magnifyingglass"),
        .init(requestSymbol: "NFLX", displayName: "Netflix", tradeSymbol: "NFLX", systemImage: "play.rectangle.fill"),
        .init(requestSymbol: "JPM", displayName: "JPMorgan Chase", tradeSymbol: "JPM", systemImage: "building.columns.fill"),
        .init(requestSymbol: "SCHW", displayName: "Charles Schwab", tradeSymbol: "SCHW", systemImage: "building.columns.fill"),
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
        .init(requestSymbol: "BZ=F", displayName: "Brent Oil", tradeSymbol: "BRENT", systemImage: "drop.fill"),
        .init(requestSymbol: "GC=F", displayName: "Gold", tradeSymbol: "XAUUSD", systemImage: "medal.fill"),
        .init(requestSymbol: "SI=F", displayName: "Silver", tradeSymbol: "XAGUSD", systemImage: "medal.fill"),
        .init(requestSymbol: "BTC-USD", displayName: "Bitcoin", tradeSymbol: "BTCUSD", systemImage: "bitcoinsign.circle.fill"),
        .init(requestSymbol: "^DJI", displayName: "US30", tradeSymbol: "US30", systemImage: "building.columns.fill")
    ]

    static let aliases: [String: String] = [
        "APPLE": "AAPL",
        "APPL": "AAPL",
        "IPHONE": "AAPL",

        "DISNEY": "DIS",
        "DIS": "DIS",

        "MICROSOFT": "MSFT",
        "MSFT": "MSFT",

        "AMAZON": "AMZN",
        "AMZN": "AMZN",

        "NVIDIA": "NVDA",
        "NVIDA": "NVDA",
        "NVDA": "NVDA",

        "AMD": "AMD",

        "TESLA": "TSLA",
        "TSLA": "TSLA",

        "FACEBOOK": "META",
        "META": "META",

        "GOOGLE": "GOOGL",
        "ALPHABET": "GOOGL",
        "GOOGL": "GOOGL",
        "GOOG": "GOOG",

        "NETFLIX": "NFLX",
        "NFLX": "NFLX",

        "JP MORGAN": "JPM",
        "JPMORGAN": "JPM",
        "CHASE": "JPM",
        "JPM": "JPM",

        "CHARLES SCHWAB": "SCHW",
        "SCHWAB": "SCHW",
        "SCHW": "SCHW",

        "PALANTIR": "PLTR",
        "PLTR": "PLTR",

        "BITCOIN": "BTC-USD",
        "BTC": "BTC-USD",
        "BTCUSD": "BTC-USD",
        "BTC/USD": "BTC-USD",

        "ETH": "ETH-USD",
        "ETHEREUM": "ETH-USD",
        "ETHUSD": "ETH-USD",

        "GOLD": "GC=F",
        "XAU": "GC=F",
        "XAUUSD": "GC=F",

        "SILVER": "SI=F",
        "XAG": "SI=F",
        "XAGUSD": "SI=F",

        "OIL": "CL=F",
        "WTI": "CL=F",
        "USOIL": "CL=F",
        "BRENT": "BZ=F",
        "UKOIL": "BZ=F",

        "NASDAQ": "NQ=F",
        "NAS100": "NQ=F",
        "NQ": "NQ=F",

        "ES": "ES=F",
        "SP500": "ES=F",
        "S&P 500": "ES=F",

        "DOW": "^DJI",
        "DJI": "^DJI",
        "US30": "^DJI"
    ]

    static func normalizedInput(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    static func comparisonKey(_ raw: String) -> String {
        let compact = normalizedInput(raw)
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "-", with: "")
        let aliases: [String: String] = [
            "XXBTZUSD": "BTCUSD", "XBTUSD": "BTCUSD",
            "XETHZUSD": "ETHUSD", "XXDGZUSD": "DOGEUSD",
            "XXDGUSD": "DOGEUSD", "XDGUSD": "DOGEUSD",
        ]
        return aliases[compact] ?? compact
    }

    static func suggestions(
        matching raw: String,
        limit: Int = 8
    ) -> [WatchSymbol] {
        let cleaned = normalizedInput(raw)
        guard !cleaned.isEmpty else { return [] }

        var ranked: [(rank: Int, item: WatchSymbol)] = []

        for item in presets {
            let request = item.requestSymbol.uppercased()
            let display = item.displayName.uppercased()
            let trade = item.tradeSymbol.uppercased()

            let itemAliases = aliases
                .filter { _, value in
                    value.uppercased() == request ||
                    value.uppercased() == trade
                }
                .map { key, _ in key.uppercased() }

            let fields = [request, display, trade] + itemAliases

            if fields.contains(cleaned) {
                ranked.append((0, item))
            } else if fields.contains(where: { $0.hasPrefix(cleaned) }) {
                ranked.append((1, item))
            } else if fields.contains(where: { $0.contains(cleaned) }) {
                ranked.append((2, item))
            }
        }

        var seen = Set<String>()

        return ranked
            .sorted {
                if $0.rank != $1.rank {
                    return $0.rank < $1.rank
                }

                return $0.item.displayName < $1.item.displayName
            }
            .compactMap { pair in
                guard !seen.contains(pair.item.requestSymbol) else {
                    return nil
                }

                seen.insert(pair.item.requestSymbol)
                return pair.item
            }
            .prefix(limit)
            .map { $0 }
    }

    static func preset(matching raw: String) -> WatchSymbol? {
        let cleaned = normalizedInput(raw)
        guard !cleaned.isEmpty else { return nil }

        let resolved = aliases[cleaned] ?? cleaned

        return presets.first {
            $0.requestSymbol.uppercased() == resolved
                || $0.displayName.uppercased() == resolved
                || $0.tradeSymbol.uppercased() == resolved
        }
    }

    static func isValidCustomTicker(_ raw: String) -> Bool {
        let cleaned = normalizedInput(raw)
        guard !cleaned.isEmpty, cleaned.count <= 14 else { return false }

        let allowed = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.^=-"
        )

        return cleaned.unicodeScalars.allSatisfy {
            allowed.contains($0)
        }
    }

    static func resolve(_ raw: String) -> WatchSymbol? {
        if let preset = preset(matching: raw) {
            return preset
        }

        guard isValidCustomTicker(raw) else {
            return nil
        }

        return custom(raw)
    }

    static func custom(_ raw: String) -> WatchSymbol {
        let cleaned = normalizedInput(raw)

        return WatchSymbol(
            requestSymbol: cleaned,
            displayName: cleaned,
            tradeSymbol: cleaned,
            systemImage: "star.circle.fill",
            isCustom: true
        )
    }
}
