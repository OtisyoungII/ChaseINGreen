//
//  TradingWorkspace.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import Foundation

struct TradingWorkspaceResponse: Codable {
    let traderOS: TraderOSResponse?
    let calendar: TradingCalendarResponse?
    let openTrades: [LoggedTradeResponse]?
    let brokerAccounts: [BrokerAccountResponse]?
    let tradeStats: TradeStatsSummaryResponse?
    let status: String?
    let tone: String?
    let headline: String?
    let summary: String?

    enum CodingKeys: String, CodingKey {
        case traderOS = "trader_os"
        case calendar
        case openTrades = "open_trades"
        case brokerAccounts = "broker_accounts"
        case tradeStats = "trade_stats"
        case status, tone, headline, summary
    }
}

enum TradingWorkspaceCard: String, CaseIterable, Identifiable, Codable {
    case traderOS = "trader_os"
    case quoteSource = "quote_source"
    case timeframes = "timeframes"
    case liveMonitor = "live_monitor"
    case openTrades = "open_trades"
    case calendar
    case brokerAccounts = "broker_accounts"
    case stats
    case journal
    case mlInsights = "ml_insights"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .traderOS: return "Trader OS"
        case .quoteSource: return "Quote Source"
        case .timeframes: return "Timeframes"
        case .liveMonitor: return "Live Monitor"
        case .openTrades: return "Open Trades"
        case .calendar: return "Calendar"
        case .brokerAccounts: return "Broker Accounts"
        case .stats: return "Stats"
        case .journal: return "Journal"
        case .mlInsights: return "ML Insights"
        }
    }

    var systemImage: String {
        switch self {
        case .traderOS: return "brain.head.profile"
        case .quoteSource: return "dot.radiowaves.left.and.right"
        case .timeframes: return "clock.arrow.circlepath"
        case .liveMonitor: return "waveform.path.ecg"
        case .openTrades: return "chart.line.uptrend.xyaxis"
        case .calendar: return "calendar"
        case .brokerAccounts: return "building.columns"
        case .stats: return "chart.bar.xaxis"
        case .journal: return "book.closed"
        case .mlInsights: return "brain"
        }
    }
}

struct TradingWorkspaceSnapshot: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let symbol: String?
    let traderOSTone: String?
    let traderOSHeadline: String?
    let openTradeCount: Int
    let brokerAccountCount: Int

    init(id: UUID = UUID(), createdAt: Date = Date(), response: TradingWorkspaceResponse) {
        self.id = id
        self.createdAt = createdAt
        self.symbol = response.traderOS?.symbol
        self.traderOSTone = response.traderOS?.tone
        self.traderOSHeadline = response.traderOS?.headline
        self.openTradeCount = response.openTrades?.count ?? 0
        self.brokerAccountCount = response.brokerAccounts?.count ?? 0
    }
}

extension TradingWorkspaceResponse {
    var effectiveHeadline: String {
        headline ?? traderOS?.headline ?? "Trading Workspace"
    }

    var effectiveSummary: String {
        summary ?? traderOS?.summary ?? "Your Trader OS, open trades, calendar, broker accounts, and stats in one command center."
    }

    var effectiveTone: String {
        tone ?? traderOS?.tone ?? "neutral"
    }

    var hasOpenTrades: Bool {
        !(openTrades ?? []).isEmpty
    }

    var openTradeCount: Int {
        openTrades?.count ?? 0
    }

    var brokerAccountCount: Int {
        brokerAccounts?.count ?? 0
    }
}
