//
//  TradingWorkspaceView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//  Updated by Otis Young II + AI on 7/2/26.
//
//  ✅ BAT CAVE WORKSPACE VIEW
//  --------------------------------------------------------------
//  ✅ Shows selected symbol clearly in the header
//  ✅ Quote Source card identifies symbol/provider/price/confidence
//  ✅ Timeframes card explains direction context
//  ✅ Live Monitor card uses open trades until broker sync is final
//  ✅ Open Trades card prioritizes the selected symbol first
//  ✅ ML Insights card remains connected
//  ✅ No model assumptions beyond current workspace/trader/open-trade data
//

import SwiftUI

struct TradingWorkspaceView: View {
    @StateObject private var viewModel = TradingWorkspaceViewModel()

    let accessToken: String
    let symbol: String
    let direction: String?
    let broker: String?
    let accountKey: String?

    init(
        accessToken: String,
        symbol: String = "TQQQ",
        direction: String? = nil,
        broker: String? = nil,
        accountKey: String? = nil
    ) {
        self.accessToken = accessToken
        self.symbol = symbol.uppercased()
        self.direction = direction
        self.broker = broker
        self.accountKey = accountKey
    }

    private var selectedSymbol: String {
        viewModel.traderOS?.symbol?.uppercased() ?? symbol.uppercased()
    }

    private var selectedSymbolTrades: [LoggedTradeResponse] {
        viewModel.openTrades.filter {
            $0.symbol.uppercased() == selectedSymbol.uppercased()
        }
    }

    private var sortedOpenTrades: [LoggedTradeResponse] {
        let selected = selectedSymbolTrades
        let others = viewModel.openTrades.filter {
            $0.symbol.uppercased() != selectedSymbol.uppercased()
        }
        return selected + others
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        if viewModel.isLoading {
                            ProgressView("Loading Trader Workspace...")
                                .frame(maxWidth: .infinity, minHeight: 180)
                        } else if let errorMessage = viewModel.errorMessage {
                            errorCard(errorMessage)
                        } else {
                            cardDeck(isWide: proxy.size.width >= 760)
                        }
                    }
                    .padding()
                    .frame(maxWidth: proxy.size.width >= 760 ? 1180 : .infinity)
                    .frame(maxWidth: .infinity)
                }

                if let zoomedCard = viewModel.zoomedCard {
                    zoomOverlay(card: zoomedCard)
                }
            }
        }
        .task {
            await viewModel.load(
                symbol: symbol,
                direction: direction,
                broker: broker,
                accountKey: accountKey,
                accessToken: accessToken
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bat Cave")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.primaryText)

            HStack(spacing: 10) {
                Label(selectedSymbol, systemImage: "scope")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.softGold)

                if let direction {
                    Text(direction.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.cardBackground)
                        .clipShape(Capsule())
                }

                if let broker {
                    Text(broker)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            Text(viewModel.workspace?.effectiveSummary ?? "Trader OS command center for AI, broker quote source, timeframes, open trades, accounts, calendar, ML insights, journal, and stats.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private func cardDeck(isWide: Bool) -> some View {
        Group {
            if isWide {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(TradingWorkspaceCard.allCases) { card in
                            workspaceCard(card)
                                .frame(width: 330)
                                .frame(minHeight: 265)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                VStack(spacing: 14) {
                    ForEach(TradingWorkspaceCard.allCases) { card in
                        workspaceCard(card)
                    }
                }
            }
        }
    }

    private func workspaceCard(_ card: TradingWorkspaceCard) -> some View {
        Button {
            viewModel.zoom(card)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(card.title, systemImage: card.systemImage)
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.softGold)

                    Spacer()

                    Text(selectedSymbol)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Divider()

                cardContent(card)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func cardContent(_ card: TradingWorkspaceCard) -> some View {
        switch card {
        case .traderOS:
            Text(viewModel.traderOS?.headline ?? "\(selectedSymbol) Trader OS waiting for signal.")
                .foregroundStyle(AppTheme.primaryText)

            Text(viewModel.traderOS?.summary ?? "No AI summary loaded yet.")

            if let ai = viewModel.traderOS?.ai {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Decision: \(ai.finalRecommendation ?? "waiting")")
                    Text("Confidence: \(ai.confidence ?? 0)%")
                    Text("Risk: \(ai.riskScore ?? 0)%")
                }
                .font(.caption.bold())
            }

        case .quoteSource:
            if let quote = viewModel.traderOS?.quoteResolution {
                VStack(alignment: .leading, spacing: 5) {
                    Text(quote.symbol ?? selectedSymbol)
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.primaryText)

                    Text("Price: \(formatPrice(quote.price))")
                    Text("Provider: \(quote.provider ?? "unknown")")
                    Text("Broker: \(quote.broker ?? "none")")
                    Text("Freshness: \(quote.freshness ?? "unknown")")
                    Text("Confidence: \(quote.confidence ?? 0)%")

                    if let warning = quote.warning, !warning.isEmpty {
                        Text("⚠️ \(warning)")
                            .foregroundStyle(AppTheme.softGold)
                    }
                }
            } else {
                Text("\(selectedSymbol) quote source not loaded yet.")
            }

        case .timeframes:
            if let mtf = viewModel.traderOS?.multiTimeframe {
                VStack(alignment: .leading, spacing: 6) {
                    timeframeRow("4H", mtf.trend4h)
                    timeframeRow("1H", mtf.trend1h)
                    timeframeRow("15M", mtf.trend15m)
                    timeframeRow("5M", mtf.trend5m)
                    timeframeRow("1M", mtf.trend1m)

                    Text("Bias: \(mtf.entryBias ?? "waiting")")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.softGold)

                    Text("Long: \(mtf.longAllowed == true ? "YES" : "NO") / Short: \(mtf.shortAllowed == true ? "YES" : "NO")")

                    if let waitReason = mtf.waitReason {
                        Text("Wait: \(waitReason)")
                    }
                }
            } else {
                Text("\(selectedSymbol) multi-timeframe data not loaded yet.")
            }

        case .liveMonitor:
            VStack(alignment: .leading, spacing: 6) {
                Text("Trade Doctor")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.primaryText)

                if selectedSymbolTrades.isEmpty {
                    Text("No tracked open trade for \(selectedSymbol).")
                    Text("Showing pre-trade context only until broker sync confirms a live position.")
                } else {
                    Text("\(selectedSymbolTrades.count) tracked \(selectedSymbol) trade(s).")
                        .foregroundStyle(AppTheme.primaryText)

                    ForEach(Array(selectedSymbolTrades.prefix(4)), id: \.id) { trade in
                        tradeRow(trade)
                    }
                }

                if !viewModel.openTrades.isEmpty {
                    Text("Total tracked open trades: \(viewModel.openTrades.count)")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.softGold)
                }
            }

        case .openTrades:
            VStack(alignment: .leading, spacing: 6) {
                Text("\(viewModel.openTrades.count) tracked open trade(s)")
                    .foregroundStyle(AppTheme.primaryText)

                if selectedSymbolTrades.isEmpty {
                    Text("No open \(selectedSymbol) trade found.")
                        .foregroundStyle(AppTheme.softGold)
                }

                ForEach(Array(sortedOpenTrades.prefix(6)), id: \.id) { trade in
                    tradeRow(trade)
                }
            }

        case .calendar:
            if let calendar = viewModel.calendar {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Trading calendar loaded.")
                        .foregroundStyle(AppTheme.primaryText)

                    Text("Days: \(calendar.summary.totalDays)")
                    Text("Green: \(calendar.summary.greenDays)")
                    Text("Red: \(calendar.summary.redDays)")
                    Text("Win Rate: \(Int(calendar.summary.winRate.rounded()))%")
                }
            } else {
                Text("Calendar not loaded yet.")
            }

        case .brokerAccounts:
            VStack(alignment: .leading, spacing: 6) {
                Text("\(viewModel.brokerAccounts.count) account(s)")
                    .foregroundStyle(AppTheme.primaryText)

                ForEach(Array(viewModel.brokerAccounts.prefix(4)), id: \.id) { account in
                    Text("• \(account.broker)")
                }
            }

        case .stats:
            if let stats = viewModel.tradeStats {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Trade stats ready.")
                        .foregroundStyle(AppTheme.primaryText)

                    Text("Closed Trades: \(stats.totalClosedTrades)")
                    Text("Win Rate: \(formatPercent(stats.winRate))")

                    let netPnl = stats.totalNetPnl ?? stats.totalRealizedPnl
                    Text("Net P/L: \(formatMoney(netPnl))")
                }
            } else {
                Text("Stats not loaded yet.")
            }

        case .journal:
            Text("Journal behavior is feeding Trader OS through dashboard, calendar, memory, profile, and coaching data.")

        case .mlInsights:
            MLInsightsCard(
                memory: viewModel.mlInsights?.memory,
                patterns: viewModel.mlInsights?.patterns,
                profile: viewModel.mlInsights?.profile,
                calendar: viewModel.mlInsights?.calendar
            )
        }
    }

    private func tradeRow(_ trade: LoggedTradeResponse) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(trade.symbol.uppercased() == selectedSymbol.uppercased() ? "🎯" : "•")

            VStack(alignment: .leading, spacing: 2) {
                Text(trade.symbol.uppercased())
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.primaryText)

                Text("Tap card to zoom. Broker sync will become execution truth.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(.top, 3)
    }

    private func timeframeRow(_ label: String, _ value: String?) -> some View {
        HStack {
            Text(label)
                .fontWeight(.semibold)
                .frame(width: 44, alignment: .leading)

            Text(timeframeIcon(value))

            Text(value ?? "unknown")
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func timeframeIcon(_ value: String?) -> String {
        let clean = (value ?? "").lowercased()

        if clean.contains("bull") || clean.contains("up") || clean.contains("long") {
            return "🟢"
        }

        if clean.contains("bear") || clean.contains("down") || clean.contains("short") {
            return "🔴"
        }

        if clean.contains("wait") || clean.contains("mixed") || clean.contains("chop") {
            return "🟡"
        }

        return "⚪️"
    }

    private func zoomOverlay(card: TradingWorkspaceCard) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label(card.title, systemImage: card.systemImage)
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.softGold)

                    Spacer()

                    Button {
                        viewModel.closeZoom()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.gold)
                    }
                    .buttonStyle(.plain)
                }

                Text("Context: \(selectedSymbol)")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.secondaryText)

                ScrollView {
                    cardContent(card)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .frame(maxWidth: 760, maxHeight: 620)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding()
        }
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workspace Error")
                .font(.headline)
                .foregroundStyle(AppTheme.softGold)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func formatPrice(_ value: Double?) -> String {
        guard let value else { return "unknown" }
        return String(format: "%.2f", value)
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f%%", value)
    }

    private func formatMoney(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%@%.2f", value >= 0 ? "+$" : "-$", abs(value))
    }
}
