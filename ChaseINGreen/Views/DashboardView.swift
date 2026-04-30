//
//  DashboardView.swift
//  ChaseINGreen
//
//  by: Otis Young
//

import SwiftUI

private struct WatchSymbol: Identifiable, Hashable {
    let requestSymbol: String
    let displayName: String
    let tradeSymbol: String
    let systemImage: String

    var id: String { requestSymbol }

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
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        return WatchSymbol(
            requestSymbol: cleaned,
            displayName: cleaned,
            tradeSymbol: cleaned,
            systemImage: "magnifyingglass.circle.fill"
        )
    }
}

struct DashboardView: View {
    let accessToken: String

    @State private var selectedSymbol: WatchSymbol = WatchSymbol.presets[0]
    @State private var customSymbolText = ""
    @State private var showingQuickEntry = false
    @State private var activePrompt: TradeActionPrompt?

    @State private var trades: [LoggedTradeResponse] = []
    @State private var backendStatus = "Checking..."
    @State private var errorMessage: String?
    @State private var currentQuote: QuoteResponse?
    @State private var currentTradeAlert: TradeAlertResponse?
    @State private var lastQuoteUpdate: Date?
    @State private var lastQuoteFetchTime: Date?
    @State private var lastQuoteFetchSymbol: String?

    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var filteredTrades: [LoggedTradeResponse] {
        trades.filter { trade in
            let symbol = trade.symbol.uppercased()
            let selectedAliases = [
                selectedSymbol.requestSymbol.uppercased(),
                selectedSymbol.displayName.uppercased(),
                selectedSymbol.tradeSymbol.uppercased()
            ]

            return selectedAliases.contains(symbol)
        }
    }

    private var activeSymbolForSheet: String {
        selectedSymbol.tradeSymbol
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                symbolSearchSection
                symbolShortcutSection
                quoteSection
                tradeAlertSection
                activeTradesSection
            }
            .padding()
        }
        .navigationTitle("Trade Home")
        .sheet(isPresented: $showingQuickEntry) {
            TradeEntrySheet(
                symbol: activeSymbolForSheet,
                currentPrice: currentQuote?.price
            ) { payload in
                Task {
                    await saveTrade(payload)
                }
            }
        }
        .sheet(item: $activePrompt) { prompt in
            TradeActionSheet(
                prompt: prompt,
                currentQuotePrice: currentQuote?.price,
                accessToken: accessToken
            ) {
                await loadTrades()
                await loadTradeAlert()
            }
        }
        .task {
            await loadDashboard(forceQuote: true)
        }
        .refreshable {
            await loadDashboard(forceQuote: true)
        }
        .onReceive(refreshTimer) { _ in
            Task {
                await loadQuote(force: false)
                await loadTradeAlert()
            }
        }
        .onChange(of: selectedSymbol) { _, _ in
            Task {
                currentTradeAlert = nil
                await loadQuote(force: true)
                await loadTradeAlert()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: selectedSymbol.systemImage)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("TradeChaser")
                        .font(.largeTitle.bold())

                    Text(Date.now.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Backend: \(backendStatus)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                statCard(
                    title: "Open Trades",
                    value: "\(trades.count)",
                    systemImage: "chart.line.uptrend.xyaxis"
                )

                statCard(
                    title: "Watching",
                    value: selectedSymbol.displayName,
                    systemImage: selectedSymbol.systemImage
                )
            }

            Button {
                showingQuickEntry = true
            } label: {
                Label("Quick Log Trade", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var symbolSearchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Search Any Ticker")
                .font(.headline)

            HStack {
                TextField("Example: SEGG, INTC, AAPL, SPY", text: $customSymbolText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                Button("Search") {
                    searchCustomSymbol()
                }
                .buttonStyle(.borderedProminent)
                .disabled(customSymbolText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Text("Use Yahoo-style symbols for futures/crypto when needed, like GC=F, SI=F, BTC-USD.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var symbolShortcutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preset Watchlist")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(WatchSymbol.presets) { symbol in
                        symbolButton(
                            title: symbol.displayName,
                            systemImage: symbol.systemImage,
                            isSelected: selectedSymbol == symbol
                        ) {
                            selectedSymbol = symbol
                        }
                    }
                }
            }
        }
    }

    private var quoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Market")
                .font(.headline)

            if let quote = currentQuote {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedSymbol.displayName)
                                .font(.title2.bold())

                            Text(quote.displaySymbol)
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)

                            Text(quote.instrumentName)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(quote.instrumentDetail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(formatPrice(quote.price))
                            .font(.title.bold())
                    }

                    HStack {
                        Text("Change: \(formatSigned(quote.change))")
                        Spacer()
                        Text("%: \(formatSigned(quote.percentChange))")
                    }
                    .font(.subheadline)
                    .foregroundStyle(quoteTint(quote))

                    HStack {
                        marketMetric("Open", quote.open)
                        marketMetric("High", quote.high)
                        marketMetric("Low", quote.low)
                    }

                    HStack {
                        marketMetric("Prev Close", quote.previousClose)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Volume")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(formatVolume(quote.volume))
                                .font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("\(quote.priceLabel) • \(quote.freshness) • \(quote.marketState ?? "Unknown")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let lastQuoteUpdate {
                        Text("Updated \(lastQuoteUpdate.formatted(date: .omitted, time: .standard))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                ContentUnavailableView(
                    "No Quote Loaded",
                    systemImage: "waveform.path.ecg",
                    description: Text("Search or choose a preset symbol.")
                )
            }
        }
    }

    private var tradeAlertSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trade Alert")
                .font(.headline)

            if let alert = currentTradeAlert {
                TradeAlertCard(
                    alert: alert,
                    onSelectOption: handleAlertResponse
                )
            } else {
                ContentUnavailableView(
                    "No Active Alert",
                    systemImage: "checkmark.shield",
                    description: Text("Open trade alert will appear here when a trade is available.")
                )
            }
        }
    }

    private var activeTradesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trades In Progress")
                .font(.headline)

            if filteredTrades.isEmpty {
                ContentUnavailableView(
                    "No Open Trades",
                    systemImage: "tray",
                    description: Text("Use Quick Log Trade to add one for \(selectedSymbol.displayName).")
                )
            } else {
                ForEach(filteredTrades) { trade in
                    VStack(alignment: .leading, spacing: 10) {
                        TradeCardView(trade: trade)

                        TradeActionPanel(
                            trade: trade,
                            currentQuotePrice: currentQuote?.price
                        ) { prompt in
                            activePrompt = prompt
                        }
                    }
                }
            }
        }
    }

    private func searchCustomSymbol() {
        let cleaned = customSymbolText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else {
            return
        }

        selectedSymbol = WatchSymbol.custom(cleaned)
    }

    private func loadDashboard(forceQuote: Bool = false) async {
        await loadHealth()
        await loadQuote(force: forceQuote)
        await loadTrades()
        await loadTradeAlert()
    }

    private func loadHealth() async {
        do {
            let response = try await APIService.shared.fetchHealth(accessToken: accessToken)
            backendStatus = response.status.capitalized
        } catch {
            backendStatus = "Offline"
            errorMessage = "Health check failed: \(error.localizedDescription)"
        }
    }

    private func loadQuote(force: Bool = false) async {
        let symbol = selectedSymbol.requestSymbol

        if !force,
           lastQuoteFetchSymbol == symbol,
           let lastFetch = lastQuoteFetchTime,
           Date().timeIntervalSince(lastFetch) < 30 {
            return
        }

        do {
            errorMessage = nil

            currentQuote = try await APIService.shared.fetchQuote(
                for: symbol,
                accessToken: accessToken
            )

            lastQuoteFetchTime = Date()
            lastQuoteFetchSymbol = symbol
            lastQuoteUpdate = Date()
        } catch {
            currentQuote = nil
            errorMessage = "Could not load quote: \(error.localizedDescription)"
        }
    }

    private func loadTrades() async {
        do {
            errorMessage = nil
            trades = try await APIService.shared.fetchOpenTrades(accessToken: accessToken)
        } catch {
            errorMessage = "Could not load trades: \(error.localizedDescription)"
        }
    }

    private func loadTradeAlert() async {
        guard let trade = filteredTrades.first else {
            currentTradeAlert = nil
            return
        }

        let request = TradeAlertRequest(
            symbol: selectedSymbol.requestSymbol,
            direction: trade.direction,
            entryPrice: trade.entryPrice,
            currentBrokerPrice: trade.currentPrice ?? currentQuote?.price,
            currentAppPrice: currentQuote?.price,
            quantity: trade.quantity,
            accountSize: trade.accountSize,
            cashAvailable: nil,
            buyingPower: nil,
            stopLoss: trade.stopLoss,
            takeProfit: trade.takeProfit,
            accountType: inferAccountType(from: trade.platform),
            broker: trade.platform,
            dailyPnl: nil,
            openPnl: nil,
            realizedPnl: trade.realizedPnl,
            maxDailyLossAllowed: nil,
            maxTotalLossAllowed: nil,
            payoutTarget: nil,
            notes: trade.notes
        )

        do {
            errorMessage = nil

            currentTradeAlert = try await APIService.shared.fetchTradeAlert(
                request,
                accessToken: accessToken
            )
        } catch {
            errorMessage = "Could not load trade alert: \(error.localizedDescription)"
        }
    }

    private func handleAlertResponse(_ option: String) {
        guard let trade = filteredTrades.first else {
            errorMessage = "No active trade available."
            return
        }

        let lower = option.lowercased()

        if lower.contains("update broker price") {
            activePrompt = .brokerPrice(trade)
        } else if lower.contains("got out") || lower.contains("took profit") {
            activePrompt = .close(trade)
        } else if lower.contains("reduced") {
            activePrompt = .reduce(trade)
        }
    }

    private func saveTrade(_ payload: LoggedTradeCreateRequest) async {
        do {
            errorMessage = nil

            _ = try await APIService.shared.createTrade(
                payload,
                accessToken: accessToken
            )

            await loadTrades()
            await loadTradeAlert()
        } catch {
            errorMessage = "Could not save trade: \(error.localizedDescription)"
        }
    }

    private func inferAccountType(from platform: String?) -> String? {
        guard let platform else { return nil }

        let normalized = platform.lowercased()

        if normalized.contains("aqua")
            || normalized.contains("topstep")
            || normalized.contains("trade_the_pool")
            || normalized.contains("trade the pool") {
            return "prop_firm"
        }

        if normalized.contains("paper") {
            return "paper"
        }

        return "cash"
    }

    private func statCard(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.headline.bold())
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func symbolButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)

                Text(title)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(width: 86, height: 86)
            .background(isSelected ? Color.primary.opacity(0.12) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private func marketMetric(_ title: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formatPrice(value))
                .font(.subheadline.bold())
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
            return .secondary
        }

        if percentChange > 0 {
            return .green
        }

        if percentChange < 0 {
            return .red
        }

        return .secondary
    }
}

#Preview {
    NavigationStack {
        DashboardView(accessToken: "dummy-access-token")
    }
}
