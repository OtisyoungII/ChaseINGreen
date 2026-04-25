//
//  DashboardView.swift
//  ChaseINGreen
//

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
    case us30 = "^DJI"
    case nq = "NQ=F"
    case es = "ES=F"
    case wti = "CL=F"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .btcusd: return "BTCUSD"
        case .xauusd: return "XAUUSD"
        case .us30: return "US30"
        case .nq: return "NQ"
        case .es: return "ES"
        case .wti: return "WTI"
        default: return rawValue
        }
    }

    var requestSymbol: String {
        rawValue
    }

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
        case .xauusd:
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
    @State private var showingBrokerPricePrompt = false
    @State private var brokerPriceText = ""

    @State private var trades: [LoggedTradeResponse] = []
    @State private var backendStatus = "Checking..."
    @State private var errorMessage: String?
    @State private var currentQuote: QuoteResponse?
    @State private var currentTradeAlert: TradeAlertResponse?
    @State private var lastQuoteUpdate: Date?

    private let refreshTimer = Timer.publish(every: 8, on: .main, in: .common).autoconnect()

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
        .alert("Update Broker Price", isPresented: $showingBrokerPricePrompt) {
            TextField("Broker price", text: $brokerPriceText)
                .keyboardType(.decimalPad)

            Button("Update") {
                Task {
                    await refreshAlertWithBrokerPrice()
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Use the price you see inside your broker.")
        }
        .task {
            print("🧪 Dashboard .task fired")
            await loadDashboard()
        }
        .refreshable {
            print("🧪 Dashboard refresh fired")
            await loadDashboard()
        }
        .onReceive(refreshTimer) { _ in
            Task {
                print("⏱️ refreshTimer fired for \(selectedSymbol.requestSymbol)")
                await loadQuote()
                await loadTradeAlert()
            }
        }
        .onChange(of: selectedSymbol) { _, newValue in
            Task {
                print("🔁 selectedSymbol changed to \(newValue.requestSymbol)")
                currentTradeAlert = nil
                await loadQuote()
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
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(alert.title)
                                .font(.headline)

                            Text(alert.message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(alert.confidence)%")
                            .font(.headline.bold())
                            .foregroundStyle(alertTint(alert))
                    }

                    if let flavor = alert.flavor {
                        Text(flavor)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        pill(alert.severity.uppercased(), color: alertTint(alert))

                        if let marketPhase = alert.marketPhase {
                            pill(
                                marketPhase.replacingOccurrences(of: "_", with: " "),
                                color: .secondary
                            )
                        }

                        if let seconds = alert.responseRequiredWithinSeconds {
                            pill("Respond \(seconds)s", color: .orange)
                        }
                    }

                    if !alert.warnings.isEmpty {
                        bulletSection(title: "Warnings", items: alert.warnings)
                    }

                    if !alert.actions.isEmpty {
                        bulletSection(title: "Actions", items: alert.actions)
                    }

                    if alert.needsUserResponse {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(alert.responseOptions, id: \.self) { option in
                                    Button(option) {
                                        handleAlertResponse(option)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(alertTint(alert).opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(alertTint(alert).opacity(0.35), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
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
                }
            }
        }
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

    private func bulletSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(items, id: \.self) { item in
                Text("• \(item)")
                    .font(.caption)
            }
        }
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func loadDashboard() async {
        print("🧪 loadDashboard started")
        await loadHealth()
        await loadQuote()
        await loadTrades()
        await loadTradeAlert()
        print("🧪 loadDashboard finished")
    }

    private func loadHealth() async {
        do {
            print("🧪 loadHealth started")
            let response = try await APIService.shared.fetchHealth(accessToken: accessToken)
            backendStatus = response.status.capitalized
            print("✅ backendStatus = \(backendStatus)")
        } catch {
            backendStatus = "Offline"
            errorMessage = "Health check failed: \(error.localizedDescription)"
            print("❌ loadHealth failed: \(error.localizedDescription)")
        }
    }

    private func loadQuote() async {
        do {
            print("🧪 loadQuote started for \(selectedSymbol.requestSymbol)")
            errorMessage = nil

            currentQuote = try await APIService.shared.fetchQuote(
                for: selectedSymbol.requestSymbol,
                accessToken: accessToken
            )

            lastQuoteUpdate = Date()
            print("✅ currentQuote price = \(currentQuote?.price ?? -1)")
        } catch {
            errorMessage = "Could not load quote: \(error.localizedDescription)"
            print("❌ loadQuote failed: \(error.localizedDescription)")
        }
    }

    private func loadTrades() async {
        do {
            print("🧪 loadTrades started")
            errorMessage = nil

            trades = try await APIService.shared.fetchOpenTrades(accessToken: accessToken)

            print("✅ trades loaded = \(trades.count)")
        } catch {
            errorMessage = "Could not load trades: \(error.localizedDescription)"
            print("❌ loadTrades failed: \(error.localizedDescription)")
        }
    }

    private func loadTradeAlert() async {
        guard let trade = filteredTrades.first else {
            currentTradeAlert = nil
            print("ℹ️ No filtered trade available for alert")
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
            realizedPnl: nil,
            maxDailyLossAllowed: nil,
            maxTotalLossAllowed: nil,
            payoutTarget: nil,
            notes: trade.notes
        )

        do {
            print("🧪 loadTradeAlert started for \(request.symbol)")
            errorMessage = nil

            currentTradeAlert = try await APIService.shared.fetchTradeAlert(
                request,
                accessToken: accessToken
            )

            print("✅ trade alert = \(currentTradeAlert?.alertType ?? "none")")
        } catch {
            errorMessage = "Could not load trade alert: \(error.localizedDescription)"
            print("❌ loadTradeAlert failed: \(error.localizedDescription)")
        }
    }

    private func handleAlertResponse(_ option: String) {
        print("🧠 User tapped alert response: \(option)")

        if option.lowercased().contains("update broker price") {
            brokerPriceText = currentQuote?.price.map { String(format: "%.2f", $0) } ?? ""
            showingBrokerPricePrompt = true
        }
    }

    private func refreshAlertWithBrokerPrice() async {
        guard let updatedBrokerPrice = Double(brokerPriceText) else {
            errorMessage = "Invalid broker price."
            return
        }

        guard let trade = filteredTrades.first else {
            errorMessage = "No active trade available."
            return
        }

        let request = TradeAlertRequest(
            symbol: selectedSymbol.requestSymbol,
            direction: trade.direction,
            entryPrice: trade.entryPrice,
            currentBrokerPrice: updatedBrokerPrice,
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
            realizedPnl: nil,
            maxDailyLossAllowed: nil,
            maxTotalLossAllowed: nil,
            payoutTarget: nil,
            notes: trade.notes
        )

        do {
            print("🧪 refreshAlertWithBrokerPrice = \(updatedBrokerPrice)")
            errorMessage = nil

            currentTradeAlert = try await APIService.shared.fetchTradeAlert(
                request,
                accessToken: accessToken
            )

            print("✅ refreshed alert with broker price")
        } catch {
            errorMessage = "Could not refresh alert: \(error.localizedDescription)"
            print("❌ refreshAlertWithBrokerPrice failed: \(error.localizedDescription)")
        }
    }

    private func saveTrade(_ payload: LoggedTradeCreateRequest) async {
        do {
            print("🧪 saveTrade started for \(payload.symbol)")
            errorMessage = nil

            _ = try await APIService.shared.createTrade(payload, accessToken: accessToken)

            print("✅ saveTrade succeeded, reloading trades")
            await loadTrades()
            await loadTradeAlert()
        } catch {
            errorMessage = "Could not save trade: \(error.localizedDescription)"
            print("❌ saveTrade failed: \(error.localizedDescription)")
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

    private func alertTint(_ alert: TradeAlertResponse) -> Color {
        switch alert.severity.lowercased() {
        case "critical":
            return .red
        case "warning":
            return .orange
        case "info":
            return .green
        default:
            return .gray
        }
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
}

#Preview {
    NavigationStack {
        DashboardView(accessToken: "dummy-access-token")
    }
}
