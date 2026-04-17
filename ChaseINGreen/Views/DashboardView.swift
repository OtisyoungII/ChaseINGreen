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
    case btcusd = "BTCUSD"
    case xauusd = "XAUUSD"
    case us30 = "US30"
    case wti = "WTI"

    var id: String { rawValue }

    var displayName: String { rawValue }

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

    @State private var selectedSymbol: SymbolPreset? = nil
    @State private var showingQuickEntry = false
    @State private var trades: [LoggedTradeResponse] = []
    @State private var backendStatus = "Checking..."
    @State private var errorMessage: String?

    private var filteredTrades: [LoggedTradeResponse] {
        guard let selectedSymbol else { return trades }
        return trades.filter { $0.symbol.uppercased() == selectedSymbol.rawValue }
    }

    private var activeSymbolForSheet: String {
        selectedSymbol?.rawValue ?? "TQQQ"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    symbolShortcutSection
                    activeTradesSection
                }
                .padding()
            }
            .navigationTitle("Trade Home")
            .sheet(isPresented: $showingQuickEntry) {
                TradeEntrySheet(
                    symbol: activeSymbolForSheet,
                    currentPrice: nil
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
                await loadTrades()
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
                    title: "Filtered",
                    value: "\(filteredTrades.count)",
                    systemImage: "line.3.horizontal.decrease.circle"
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
                    symbolButton(
                        title: "All",
                        systemImage: "square.grid.2x2.fill",
                        isSelected: selectedSymbol == nil
                    ) {
                        selectedSymbol = nil
                    }

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

    private var activeTradesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trades In Progress")
                    .font(.headline)

                Spacer()

                if let selectedSymbol {
                    Text(selectedSymbol.displayName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }
            }

            if filteredTrades.isEmpty {
                ContentUnavailableView(
                    "No Open Trades",
                    systemImage: "tray",
                    description: Text("Use Quick Log Trade to add one.")
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

    private func loadDashboard() async {
        await loadHealth()
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
}

#Preview {
    DashboardView(accessToken: "dummy-access-token")
}
