//
//  DashboardView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 4/16/26.
//

import SwiftUI

private enum SymbolPreset: String, CaseIterable, Identifiable {
    case tqqq = "TQQQ"
    case tsla = "TSLA"
    case btcusd = "BTC-USD"
    case xauusd = "GC=F"
    case us30 = "^DJI"
    case wti = "CL=F"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tqqq: return "TQQQ"
        case .tsla: return "TSLA"
        case .btcusd: return "BTCUSD"
        case .xauusd: return "XAUUSD"
        case .us30: return "US30"
        case .wti: return "WTI"
        }
    }

    var systemImage: String {
        switch self {
        case .tqqq: return "chart.line.uptrend.xyaxis"
        case .tsla: return "bolt.car.fill"
        case .btcusd: return "bitcoinsign.circle.fill"
        case .xauusd: return "medal.fill"
        case .us30: return "building.columns.fill"
        case .wti: return "drop.fill"
        }
    }
}

struct DashboardView: View {
    let accessToken: String

    @State private var selectedSymbol: SymbolPreset = .tqqq
    @State private var showingQuickEntry = false
    @State private var trades: [LoggedTradeResponse] = []
    @State private var backendStatus = "Checking..."
    @State private var errorMessage: String?
    @State private var currentQuote: QuoteResponse?
    @State private var lastQuoteUpdate: Date?

    private let refreshTimer = Timer.publish(every: 8, on: .main, in: .common).autoconnect()

    private var filteredTrades: [LoggedTradeResponse] {
        trades.filter { $0.symbol.uppercased() == selectedSymbol.displayName }
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
        .task {
            await loadDashboard()
        }
        .refreshable {
            await loadDashboard()
        }
        .onReceive(refreshTimer) { _ in
            Task {
                await loadQuote()
            }
        }
        .onChange(of: selectedSymbol) { _, _ in
            Task {
                await loadQuote()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TradeChaser")
                .font(.largeTitle.bold())

            Text(Date.now.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
                        Text(quote.symbol)
                            .font(.title2.bold())

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
                    description: Text("Waiting for live market data.")
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

    private func loadDashboard() async {
        await loadHealth()
        await loadQuote()
        await loadTrades()
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

    private func loadQuote() async {
        do {
            errorMessage = nil
            currentQuote = try await APIService.shared.fetchQuote(
                for: selectedSymbol.rawValue,
                accessToken: accessToken
            )
            lastQuoteUpdate = Date()
        } catch {
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

    private func saveTrade(_ payload: LoggedTradeCreateRequest) async {
        do {
            errorMessage = nil
            _ = try await APIService.shared.createTrade(payload, accessToken: accessToken)
            await loadTrades()
        } catch {
            errorMessage = "Could not save trade: \(error.localizedDescription)"
        }
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
