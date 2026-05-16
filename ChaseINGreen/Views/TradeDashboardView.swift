//
//  TradeDashboardView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 4/16/26.
//

import SwiftUI

private enum TradeDashboardSymbolPreset: String, CaseIterable, Identifiable {
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

struct TradeDashboardView: View {
    let accessToken: String

    @State private var selectedSymbol: TradeDashboardSymbolPreset?
    @State private var showingNewTradeSheet = false
    @State private var activeTrades: [LoggedTradeResponse] = []
    @State private var errorMessage: String?

    private var filteredTrades: [LoggedTradeResponse] {
        guard let selectedSymbol else { return activeTrades }
        return activeTrades.filter { $0.symbol.uppercased() == selectedSymbol.rawValue }
    }

    private var activeSymbolForSheet: String {
        selectedSymbol?.rawValue ?? "TQQQ"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    assetPickerSection
                    activeTradesSection
                }
                .padding()
            }
            .background(Color.secondary.opacity(0.08))
            .navigationTitle("Trades")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingNewTradeSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewTradeSheet) {
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
                await loadTrades()
            }
            .refreshable {
                await loadTrades()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trade Monitor")
                .font(.largeTitle.bold())

            Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                DashboardStatCard(
                    title: "Active",
                    value: "\(activeTrades.count)",
                    systemImage: "chart.line.uptrend.xyaxis"
                )

                DashboardStatCard(
                    title: "Filtered",
                    value: "\(filteredTrades.count)",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            }
        }
    }

    private var assetPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Symbols")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    AssetButton(
                        title: "All",
                        systemImage: "square.grid.2x2",
                        isSelected: selectedSymbol == nil
                    ) {
                        selectedSymbol = nil
                    }

                    ForEach(TradeDashboardSymbolPreset.allCases) { symbol in
                        AssetButton(
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
            Text("Trades In Progress")
                .font(.headline)

            if filteredTrades.isEmpty {
                AppUnavailableView(
                    title: "No Open Trades",
                    systemImage: "tray",
                    message: selectedSymbol == nil
                        ? "Tap + to add your first trade."
                        : "Use Quick Log Trade to add one for \(selectedSymbol?.displayName ?? "this symbol").")
            } else {
                ForEach(filteredTrades) { trade in
                    TradeCardView(trade: trade)
                }
            }
        }
    }

    private func loadTrades() async {
        do {
            errorMessage = nil
            activeTrades = try await APIService.shared.fetchOpenTrades(accessToken: accessToken)
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
    TradeDashboardView(accessToken: "dummy-access-token")
}
