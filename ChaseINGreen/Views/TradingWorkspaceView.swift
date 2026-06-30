//
//  TradingWorkspaceView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
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
        self.symbol = symbol
        self.direction = direction
        self.broker = broker
        self.accountKey = accountKey
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Bat Cave")
                .font(.largeTitle.bold())

            Text(viewModel.workspace?.effectiveSummary ?? "Trader OS command center for AI, broker quote source, timeframes, open trades, accounts, calendar, and stats.")
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
                                .frame(width: 320)
                                .frame(minHeight: 250)
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
                Label(card.title, systemImage: card.systemImage)
                    .font(.headline)

                Divider()

                cardContent(card)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func cardContent(_ card: TradingWorkspaceCard) -> some View {
        switch card {

        case .traderOS:
            Text(viewModel.traderOS?.headline ?? "Trader OS waiting for signal.")
            Text(viewModel.traderOS?.summary ?? "No AI summary loaded yet.")

            if let ai = viewModel.traderOS?.ai {
                Text("AI: \(ai.finalRecommendation ?? "waiting")")
                Text("Confidence: \(ai.confidence ?? 0)%")
                Text("Risk: \(ai.riskScore ?? 0)%")
            }

        case .quoteSource:
            if let quote = viewModel.traderOS?.quoteResolution {
                Text("Provider: \(quote.provider ?? "unknown")")
                Text("Broker: \(quote.broker ?? "none")")
                Text("Price: \(formatPrice(quote.price))")
                Text("Freshness: \(quote.freshness ?? "unknown")")
                Text("Confidence: \(quote.confidence ?? 0)%")
            } else {
                Text("Quote source not loaded yet.")
            }

        case .timeframes:
            if let mtf = viewModel.traderOS?.multiTimeframe {
                timeframeRow("4H", mtf.trend4h)
                timeframeRow("1H", mtf.trend1h)
                timeframeRow("15M", mtf.trend15m)
                timeframeRow("5M", mtf.trend5m)
                timeframeRow("1M", mtf.trend1m)
                Text("Bias: \(mtf.entryBias ?? "waiting")")
            } else {
                Text("Multi-timeframe data not loaded yet.")
            }

        case .liveMonitor:
            Text("Live monitor not wired to Swift model yet.")

        case .openTrades:
            Text("\(viewModel.openTrades.count) open trade(s)")
            ForEach(viewModel.openTrades.prefix(4), id: \.id) { trade in
                Text("• \(trade.symbol)")
            }

        case .calendar:
            Text(viewModel.calendar == nil ? "Calendar not loaded yet." : "Trading calendar loaded.")

        case .brokerAccounts:
            Text("\(viewModel.brokerAccounts.count) account(s)")
            ForEach(viewModel.brokerAccounts.prefix(4), id: \.id) { account in
                Text("• \(account.broker)")
            }

        case .stats:
            Text(viewModel.tradeStats == nil ? "Stats not loaded yet." : "Trade stats ready.")

        case .journal:
            Text("Journal behavior is feeding Trader OS through dashboard, calendar, memory, profile, and coaching data.")
        }
    }

    private func timeframeRow(_ label: String, _ value: String?) -> some View {
        HStack {
            Text(label)
                .fontWeight(.semibold)
                .frame(width: 44, alignment: .leading)

            Text(timeframeIcon(value))
            Text(value ?? "unknown")
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

    private func formatPrice(_ value: Double?) -> String {
        guard let value else { return "unknown" }
        return String(format: "%.2f", value)
    }

    private func zoomOverlay(card: TradingWorkspaceCard) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label(card.title, systemImage: card.systemImage)
                        .font(.title2.bold())

                    Spacer()

                    Button {
                        viewModel.closeZoom()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                    }
                }

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

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
