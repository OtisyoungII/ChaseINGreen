//
//  MarketDetailView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/12/26.
//

import SwiftUI

struct MarketDetailView: View {
    let requestSymbol: String
    let displayName: String
    let tradeSymbol: String
    let accessToken: String

    @State private var quote: QuoteResponse?
    @State private var preTradeContext: PreTradeContextResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedTimeframe = "15m"
    @State private var selectedChartStyle: CandleChartStyle = .standard
    @State private var aiLevelsUnlocked = false
    @State private var remainingAIReveals = 5
    @State private var maxAIReveals = 5
    @State private var candles: [MarketCandle] = []
    @State private var userPlan = "free"
    @State private var isAdminUser = false
    @State private var showingPaywall = false

    private let timeframes = ["4h", "1h", "30m", "15m", "5m", "1m"]

    private var normalizedPlan: String {
        userPlan.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isUnlimitedAI: Bool {
        isAdminUser || normalizedPlan == "admin" || normalizedPlan == "secret"
    }

    private var canUseAILevels: Bool {
        isUnlimitedAI || normalizedPlan == "gold"
    }

    private var shouldShowRevealCount: Bool {
        !isUnlimitedAI && canUseAILevels
    }

    private var tierLabel: String {
        if isAdminUser || normalizedPlan == "admin" { return "Admin" }
        if normalizedPlan == "secret" { return "Secret" }
        if normalizedPlan == "gold" { return "Gold" }
        if normalizedPlan == "premium" { return "Premium" }
        return "Free"
    }

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    quoteSection
                    insightGateSection
                    chartSection

                    if canUseAILevels {
                        marketAccessSection
                    }
                }
                .padding()
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        #endif
        .task {
            await loadMarketDetail()
        }
        .refreshable {
            await loadMarketDetail()
        }
        .sheet(isPresented: $showingPaywall) {
            SubscriptionPaywallView(
                accessToken: accessToken
            )
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayName)
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text(tradeSymbol)
                .font(.headline.bold())
                .foregroundStyle(AppTheme.softGold)

            Text("Market Detail")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.secondaryText)

            if isLoading {
                ProgressView()
                    .tint(AppTheme.gold)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.danger)
            }
        }
    }

    private var quoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Live Market")

            if let quote {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(displayName)
                                .font(.title2.bold())
                                .foregroundStyle(AppTheme.primaryText)

                            Text(quote.displaySymbol)
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.softGold)

                            Text(quote.instrumentName)
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)

                            Text(quote.instrumentDetail)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.mutedText)
                        }

                        Spacer()

                        Text(formatPrice(quote.price))
                            .font(.title.bold())
                            .foregroundStyle(AppTheme.primaryText)
                    }

                    HStack {
                        Text("Change: \(formatSigned(quote.change))")
                        Spacer()
                        Text("%: \(formatSigned(quote.percentChange))")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(quoteTint(quote))

                    HStack {
                        metric("Open", formatPrice(quote.open))
                        metric("High", formatPrice(quote.high))
                        metric("Low", formatPrice(quote.low))
                    }

                    HStack {
                        metric("Prev Close", formatPrice(quote.previousClose))
                        metric("Volume", formatVolume(quote.volume))
                    }

                    Text("\(quote.priceLabel) • \(quote.freshness) • \(quote.marketState ?? "Unknown")")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding()
                .background(AppTheme.cardBlack)
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(AppTheme.cardStroke, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                AppUnavailableView(
                    title: "No Market Price",
                    systemImage: "chart.line.uptrend.xyaxis",
                    message: "Pull down to refresh this ticker."
                )
            }
        }
    }

    private var insightGateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(canUseAILevels ? "AI Levels" : "AI Levels Locked")

            VStack(alignment: .leading, spacing: 8) {
                if canUseAILevels {
                    Text("Support, resistance, zones, and AI reads are gated insight tools.")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.primaryText)

                    Text(isUnlimitedAI ? "Your tier has unlimited AI chart access." : "Reveal tickets control how many symbols unlock AI levels and trade reads.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                } else {
                    Text("Live quotes and basic candles are free. AI levels, zones, and trade reads unlock with Gold.")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.primaryText)

                    Text("Upgrade to reveal chart levels and AI trade context.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)

                    Button {
                        showingPaywall = true
                    } label: {
                        Label("Upgrade to Gold", systemImage: "crown.fill")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.deepBlack)
                    .background(AppTheme.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding()
            .background(AppTheme.cardBlack)
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppTheme.gold.opacity(0.35), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Chart")

            HStack(spacing: 8) {
                ForEach(timeframes, id: \.self) { timeframe in
                    Button {
                        selectedTimeframe = timeframe
                        aiLevelsUnlocked = isUnlimitedAI

                        Task {
                            await loadMarketDetail()
                        }
                    } label: {
                        Text(timeframe)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(selectedTimeframe == timeframe ? AppTheme.gold : AppTheme.cardBlack)
                            .foregroundStyle(selectedTimeframe == timeframe ? AppTheme.deepBlack : AppTheme.primaryText)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            chartStylePicker

            VStack(alignment: .leading, spacing: 10) {
                Text("\(displayName) • \(selectedTimeframe)")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.primaryText)

                CandleChartView(
                    candles: candles,
                    currentPrice: quote?.price,
                    showAILevels: aiLevelsUnlocked && canUseAILevels,
                    context: preTradeContext,
                    chartStyle: selectedChartStyle
                )

                chartGateButtonOrRead
            }
            .padding()
            .background(AppTheme.cardBlack.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
    }

    private var chartStylePicker: some View {
        HStack(spacing: 8) {
            ForEach(CandleChartStyle.allCases) { style in
                Button {
                    selectedChartStyle = style
                } label: {
                    Text(style.rawValue)
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(selectedChartStyle == style ? AppTheme.gold : AppTheme.cardBlack)
                        .foregroundStyle(selectedChartStyle == style ? AppTheme.deepBlack : AppTheme.primaryText)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var chartGateButtonOrRead: some View {
        if !canUseAILevels {
            VStack(spacing: 12) {
                AppUnavailableView(
                    title: "AI Chart Locked",
                    systemImage: "lock.fill",
                    message: "Free and Premium can view live quote data and basic candles. AI levels unlock with Gold."
                )

                Button {
                    showingPaywall = true
                } label: {
                    Label("Upgrade to Gold", systemImage: "crown.fill")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.deepBlack)
                .background(AppTheme.gold)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        } else if aiLevelsUnlocked, let preTradeContext {
            PreTradeContextCard(
                context: preTradeContext,
                isLoading: isLoading,
                errorMessage: nil
            ) {
                Task {
                    await loadMarketDetail()
                }
            }
        } else {
            Button {
                revealAILevels()
            } label: {
                Label(revealButtonTitle, systemImage: "lock.open.fill")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.deepBlack)
            .background(canRevealAI ? AppTheme.gold : AppTheme.mutedText)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .disabled(!canRevealAI)
        }
    }

    private var revealButtonTitle: String {
        if isUnlimitedAI {
            return "Reveal AI Levels"
        }

        return "Reveal AI Levels (\(remainingAIReveals) left)"
    }

    private var canRevealAI: Bool {
        isUnlimitedAI || remainingAIReveals > 0
    }

    private var marketAccessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Market Access")

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Tier")
                        .foregroundStyle(AppTheme.secondaryText)

                    Spacer()

                    Text(tierLabel)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.gold)
                }

                if shouldShowRevealCount {
                    Divider()

                    HStack {
                        Text("AI Reveals Remaining")
                            .foregroundStyle(AppTheme.secondaryText)

                        Spacer()

                        Text("\(remainingAIReveals) / \(maxAIReveals)")
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.primaryText)
                    }
                }

                Divider()

                Text(isUnlimitedAI ? "Unlimited AI chart access is active." : "AI levels, support zones, resistance zones, and trade reads consume reveal tickets.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding()
            .background(AppTheme.cardBlack)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private func revealAILevels() {
        guard canUseAILevels else { return }
        guard canRevealAI else { return }

        aiLevelsUnlocked = true

        if !isUnlimitedAI {
            remainingAIReveals = max(remainingAIReveals - 1, 0)
        }
    }

    private func loadMarketDetail() async {
        isLoading = true
        errorMessage = nil

        do {
            let currentUser = try await APIService.shared.fetchCurrentUser(accessToken: accessToken)
            userPlan = currentUser.plan ?? "free"
            isAdminUser = currentUser.isAdmin

            if isUnlimitedAI {
                aiLevelsUnlocked = true
            }

            quote = try await APIService.shared.fetchQuote(
                for: requestSymbol,
                accessToken: accessToken
            )

            candles = try await APIService.shared.fetchMarketCandles(
                for: requestSymbol,
                timeframe: selectedTimeframe,
                accessToken: accessToken
            )

            if canUseAILevels {
                let request = PreTradeContextRequest(symbol: requestSymbol)

                preTradeContext = try await APIService.shared.fetchPreTradeContext(
                    request,
                    accessToken: accessToken
                )
            } else {
                preTradeContext = nil
                aiLevelsUnlocked = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .black, design: .rounded))
            .foregroundStyle(AppTheme.softGold)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.secondaryText)

            Text(value)
                .font(.headline.bold())
                .foregroundStyle(AppTheme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatPrice(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f", value)
    }

    private func formatSigned(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%+.2f", value)
    }

    private func formatVolume(_ value: Int?) -> String {
        guard let value else { return "--" }
        return "\(value)"
    }

    private func quoteTint(_ quote: QuoteResponse) -> Color {
        guard let percentChange = quote.percentChange else {
            return AppTheme.secondaryText
        }

        if percentChange > 0 { return .green }
        if percentChange < 0 { return .red }
        return AppTheme.secondaryText
    }
}

#Preview {
    NavigationStack {
        MarketDetailView(
            requestSymbol: "TQQQ",
            displayName: "TQQQ",
            tradeSymbol: "TQQQ",
            accessToken: "dummy-access-token"
        )
    }
}
