//
//  DashboardView.swift
//  ChaseINGreen
//
// by: Otis Young



import SwiftUI

private enum SymbolPreset: String, CaseIterable, Identifiable {
    case tqqq = "TQQQ"
    case qqq = "QQQ"
    case nvda = "NVDA"
    case tsla = "TSLA"
    case soxl = "SOXL"
    case soxs = "SOXS"
    case oklo = "OKLO"
    case pltr = "PLTR"
    case btcusd = "BTC-USD"
    case xauusd = "GC=F"
    case xagusd = "SI=F"
    case us30 = "^DJI"
    case nq = "NQ=F"
    case es = "ES=F"
    case wti = "CL=F"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .btcusd: return "BTCUSD"
        case .xauusd: return "XAUUSD"
        case .xagusd: return "XAGUSD"
        case .us30: return "US30"
        case .nq: return "NQ"
        case .es: return "ES"
        case .wti: return "WTI"
        default: return rawValue
        }
    }

    var requestSymbol: String { rawValue }

    var systemImage: String {
        switch self {
        case .tqqq, .qqq, .nq, .es:
            return "chart.line.uptrend.xyaxis"
        case .tsla:
            return "bolt.car.fill"
        case .nvda, .soxl, .soxs:
            return "cpu.fill"
        case .btcusd:
            return "bitcoinsign.circle.fill"
        case .xauusd, .xagusd:
            return "medal.fill"
        case .us30:
            return "building.columns.fill"
        case .wti:
            return "drop.fill"
        default:
            return "waveform.path.ecg"
        }
    }
}

struct DashboardView: View {
    let accessToken: String

    @State private var selectedSymbol: SymbolPreset = .tqqq
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
            return symbol == selectedSymbol.displayName.uppercased()
                || symbol == selectedSymbol.rawValue.uppercased()
        }
    }

    private var activeSymbolForSheet: String {
        selectedSymbol.displayName
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
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
            TradeActionFormSheet(
                prompt: prompt,
                currentQuotePrice: currentQuote?.price
            ) { result in
                Task {
                    await submitTradeAction(result)
                }
            }
        }
        .task {
            print("🧪 Dashboard .task fired")
            await loadDashboard(forceQuote: true)
        }
        .refreshable {
            print("🧪 Dashboard refresh fired")
            await loadDashboard(forceQuote: true)
        }
        .onReceive(refreshTimer) { _ in
            Task {
                print("⏱️ refreshTimer fired for \(selectedSymbol.requestSymbol)")
                await loadQuote(force: false)
                await loadTradeAlert()
            }
        }
        .onChange(of: selectedSymbol) { _, newValue in
            Task {
                print("🔁 selectedSymbol changed to \(newValue.requestSymbol)")
                currentTradeAlert = nil
                await loadQuote(force: true)
                await loadTradeAlert()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "building.columns.fill")
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
                print("➕ Quick Log Trade tapped")
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

    private var symbolShortcutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Symbols")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(SymbolPreset.allCases) { symbol in
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
                            Text(quote.displaySymbol)
                                .font(.title2.bold())

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
                    description: Text("Waiting for market data.")
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
                        TradeCardView(trade: trade)

                        TradeActionRow(
                            trade: trade,
                            currentQuotePrice: currentQuote?.price
                        ) { prompt in
                            activePrompt = prompt
                        }
                    }
                }
            }
        }

        // MARK: - Data Loading

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
                currentQuote = try await APIService.shared.fetchQuote(
                    for: symbol,
                    accessToken: accessToken
                )

                lastQuoteFetchTime = Date()
                lastQuoteFetchSymbol = symbol
                lastQuoteUpdate = Date()
            } catch {
                errorMessage = "Could not load quote: \(error.localizedDescription)"
            }
        }

        private func loadTrades() async {
            do {
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
                currentTradeAlert = try await APIService.shared.fetchTradeAlert(
                    request,
                    accessToken: accessToken
                )
            } catch {
                errorMessage = "Could not load trade alert: \(error.localizedDescription)"
            }
        }

        // MARK: - Actions

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
                _ = try await APIService.shared.createTrade(payload, accessToken: accessToken)
                await loadTrades()
                await loadTradeAlert()
            } catch {
                errorMessage = "Could not save trade: \(error.localizedDescription)"
            }
        }

        private func submitTradeAction(_ result: TradeActionResult) async {
            do {
                switch result {
                case .brokerPrice(let trade, let value, let note):
                    _ = try await APIService.shared.updateBrokerPrice(
                        tradeId: trade.id,
                        currentPrice: value,
                        notes: note,
                        accessToken: accessToken
                    )

                case .stopLoss(let trade, let value, let note):
                    _ = try await APIService.shared.updateTrade(
                        tradeId: trade.id,
                        stopLoss: value,
                        notes: note,
                        accessToken: accessToken
                    )

                case .takeProfit(let trade, let value, let note):
                    _ = try await APIService.shared.updateTrade(
                        tradeId: trade.id,
                        takeProfit: value,
                        notes: note,
                        accessToken: accessToken
                    )

                case .quantity(let trade, let value, let note):
                    _ = try await APIService.shared.updateTrade(
                        tradeId: trade.id,
                        quantity: value,
                        notes: note,
                        accessToken: accessToken
                    )

                case .reduce(let trade, let value, let note):
                    _ = try await APIService.shared.reduceTrade(
                        tradeId: trade.id,
                        newQuantity: value,
                        currentPrice: currentQuote?.price,
                        notes: note,
                        accessToken: accessToken
                    )

                case .add(let trade, let value, let note):
                    _ = try await APIService.shared.addToTrade(
                        tradeId: trade.id,
                        addQuantity: value,
                        currentPrice: currentQuote?.price,
                        notes: note,
                        accessToken: accessToken
                    )

                case .close(let trade, let value, let note):
                    _ = try await APIService.shared.closeTrade(
                        tradeId: trade.id,
                        exitPrice: value,
                        notes: note,
                        accessToken: accessToken
                    )
                }

                await loadTrades()
                await loadTradeAlert()
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        // MARK: - Helpers

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
            HStack {
                Image(systemName: systemImage)
                VStack(alignment: .leading) {
                    Text(title).font(.caption)
                    Text(value).bold()
                }
                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }

        private func symbolButton(title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                VStack {
                    Image(systemName: systemImage)
                    Text(title).font(.caption)
                }
                .frame(width: 80, height: 80)
                .background(isSelected ? Color.primary.opacity(0.1) : Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }

        private func marketMetric(_ title: String, _ value: Double?) -> some View {
            VStack(alignment: .leading) {
                Text(title).font(.caption)
                Text(formatPrice(value)).bold()
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
            guard let change = quote.percentChange else { return .secondary }
            return change > 0 ? .green : (change < 0 ? .red : .secondary)
        }
    }
