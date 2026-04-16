//
//  TradeModels.swift
//  ChaseINGreen
//
//  Created by Otis Young on 4/16/26.
//

import SwiftUI

struct TradeDashboardView: View {
    @State private var selectedAsset: TradeAsset? = nil
    @State private var showingNewTradeSheet = false
    @State private var activeTrades: [Trade] = Trade.sampleData

    var filteredTrades: [Trade] {
        guard let selectedAsset else { return activeTrades }
        return activeTrades.filter { $0.asset == selectedAsset }
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
            .background(Color(.systemBackground))
            .navigationTitle("Trades")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewTradeSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewTradeSheet) {
                NewTradeView { newTrade in
                    activeTrades.insert(newTrade, at: 0)
                }
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
            Text("Quick Assets")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    AssetButton(
                        title: "All",
                        systemImage: "square.grid.2x2",
                        isSelected: selectedAsset == nil
                    ) {
                        selectedAsset = nil
                    }

                    ForEach(TradeAsset.allCases) { asset in
                        AssetButton(
                            title: asset.displayName,
                            systemImage: asset.systemImage,
                            isSelected: selectedAsset == asset
                        ) {
                            selectedAsset = asset
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
                ContentUnavailableView(
                    "No Active Trades",
                    systemImage: "tray",
                    description: Text("Tap + to add a trade.")
                )
            } else {
                ForEach(filteredTrades) { trade in
                    NavigationLink {
                        TradeDetailView(trade: trade)
                    } label: {
                        TradeCardView(trade: trade)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    TradeDashboardView()
}
