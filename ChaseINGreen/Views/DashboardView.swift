//
//  DashboardView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 4/16/26.
//

import SwiftUI

struct DashboardView: View {
    let accessToken: String

    @State private var selectedAsset: TradeAsset? = nil
    @State private var showingQuickEntry = false
    @State private var draftTrade = TradeDraft()
    @State private var activeTrades: [Trade] = Trade.sampleData

    private var filteredTrades: [Trade] {
        guard let selectedAsset else { return activeTrades }
        return activeTrades.filter { $0.asset == selectedAsset }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    assetShortcutSection
                    activeTradesSection
                }
                .padding()
            }
            .navigationTitle("Trade Home")
            .sheet(isPresented: $showingQuickEntry) {
                quickEntrySheet
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

            HStack(spacing: 12) {
                statCard(
                    title: "Open Trades",
                    value: "\(activeTrades.count)",
                    systemImage: "chart.line.uptrend.xyaxis"
                )

                statCard(
                    title: "Filtered",
                    value: "\(filteredTrades.count)",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            }

            Button {
                draftTrade = TradeDraft(asset: selectedAsset ?? .bitcoin)
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

    private var assetShortcutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assets")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    assetButton(
                        title: "All",
                        systemImage: "square.grid.2x2.fill",
                        isSelected: selectedAsset == nil
                    ) {
                        selectedAsset = nil
                    }

                    ForEach(TradeAsset.allCases) { asset in
                        assetButton(
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
            HStack {
                Text("Trades In Progress")
                    .font(.headline)

                Spacer()

                if let selectedAsset {
                    Text(selectedAsset.displayName)
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
                    description: Text("Tap an asset or use Quick Log Trade to add one.")
                )
            } else {
                ForEach($activeTrades) { $trade in
                    if selectedAsset == nil || trade.asset == selectedAsset {
                        TradeRowCard(
                            trade: $trade,
                            onTapLogTime: {
                                draftTrade = TradeDraft(from: trade)
                                showingQuickEntry = true
                            }
                        )
                    }
                }
            }
        }
    }

    private var quickEntrySheet: some View {
        NavigationStack {
            Form {
                Section("Asset") {
                    Picker("Asset", selection: $draftTrade.asset) {
                        ForEach(TradeAsset.allCases) { asset in
                            Text(asset.displayName).tag(asset)
                        }
                    }
                }

                Section("Direction") {
                    Picker("Direction", selection: $draftTrade.direction) {
                        ForEach(TradeDirection.allCases) { direction in
                            Text(direction.displayName).tag(direction)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Trade Info") {
                    TextField("Entry Price", text: $draftTrade.entryPrice)
                        .keyboardType(.decimalPad)

                    TextField("Current Price", text: $draftTrade.currentPrice)
                        .keyboardType(.decimalPad)

                    DatePicker("Opened Time", selection: $draftTrade.openedAt)

                    TextField("Stop Loss", text: $draftTrade.stopLoss)
                        .keyboardType(.decimalPad)

                    TextField("Take Profit", text: $draftTrade.takeProfit)
                        .keyboardType(.decimalPad)
                }

                Section("Notes") {
                    TextField("Notes", text: $draftTrade.notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Quick Trade Entry")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showingQuickEntry = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let newTrade = Trade(
                            asset: draftTrade.asset,
                            direction: draftTrade.direction,
                            entryPrice: draftTrade.entryPrice,
                            currentPrice: draftTrade.currentPrice,
                            stopLoss: draftTrade.stopLoss,
                            takeProfit: draftTrade.takeProfit,
                            openedAt: draftTrade.openedAt,
                            notes: draftTrade.notes
                        )

                        if let index = activeTrades.firstIndex(where: { $0.id == draftTrade.id }) {
                            activeTrades[index] = newTrade
                        } else {
                            activeTrades.insert(newTrade, at: 0)
                        }

                        showingQuickEntry = false
                    }
                    .disabled(draftTrade.entryPrice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    private func assetButton(
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
}

// MARK: - Trade Row Card

private struct TradeRowCard: View {
    @Binding var trade: Trade
    let onTapLogTime: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(trade.asset.displayName, systemImage: trade.asset.systemImage)
                    .font(.headline)

                Spacer()

                Text(trade.direction.displayName)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
            }

            HStack {
                metric("Entry", trade.entryPrice)
                metric("Now", trade.currentPrice)
                metric("Time", trade.openedAt.formatted(date: .omitted, time: .shortened))
            }

            if !trade.notes.isEmpty {
                Text(trade.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Button {
                onTapLogTime()
            } label: {
                Label("Update Trade", systemImage: "pencil.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value.isEmpty ? "--" : value)
                .font(.subheadline.bold())
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Local Models

private enum TradeAsset: String, CaseIterable, Identifiable {
    case gold
    case bitcoin
    case oil
    case silver
    case ethereum

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gold: return "Gold"
        case .bitcoin: return "Bitcoin"
        case .oil: return "Oil"
        case .silver: return "Silver"
        case .ethereum: return "Ethereum"
        }
    }

    var systemImage: String {
        switch self {
        case .gold: return "medal.fill"
        case .bitcoin: return "bitcoinsign.circle.fill"
        case .oil: return "drop.fill"
        case .silver: return "circle.fill"
        case .ethereum: return "e.circle.fill"
        }
    }
}

private enum TradeDirection: String, CaseIterable, Identifiable {
    case buy
    case sell

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}

private struct Trade: Identifiable, Equatable {
    let id: UUID
    var asset: TradeAsset
    var direction: TradeDirection
    var entryPrice: String
    var currentPrice: String
    var stopLoss: String
    var takeProfit: String
    var openedAt: Date
    var notes: String

    init(
        id: UUID = UUID(),
        asset: TradeAsset,
        direction: TradeDirection,
        entryPrice: String,
        currentPrice: String = "",
        stopLoss: String = "",
        takeProfit: String = "",
        openedAt: Date = .now,
        notes: String = ""
    ) {
        self.id = id
        self.asset = asset
        self.direction = direction
        self.entryPrice = entryPrice
        self.currentPrice = currentPrice
        self.stopLoss = stopLoss
        self.takeProfit = takeProfit
        self.openedAt = openedAt
        self.notes = notes
    }

    static let sampleData: [Trade] = [
        Trade(
            asset: .bitcoin,
            direction: .buy,
            entryPrice: "68425.50",
            currentPrice: "68610.20",
            stopLoss: "67980.00",
            takeProfit: "69200.00",
            openedAt: .now.addingTimeInterval(-3200),
            notes: "Watching continuation."
        ),
        Trade(
            asset: .gold,
            direction: .sell,
            entryPrice: "2361.80",
            currentPrice: "2357.40",
            stopLoss: "2368.40",
            takeProfit: "2348.20",
            openedAt: .now.addingTimeInterval(-5400),
            notes: "Short from resistance."
        ),
        Trade(
            asset: .oil,
            direction: .buy,
            entryPrice: "81.24",
            currentPrice: "81.66",
            stopLoss: "80.70",
            takeProfit: "82.10",
            openedAt: .now.addingTimeInterval(-1900),
            notes: "Momentum push after reclaim."
        )
    ]
}

private struct TradeDraft {
    var id: UUID? = nil
    var asset: TradeAsset = .bitcoin
    var direction: TradeDirection = .buy
    var entryPrice: String = ""
    var currentPrice: String = ""
    var stopLoss: String = ""
    var takeProfit: String = ""
    var openedAt: Date = .now
    var notes: String = ""

    init() {}

    init(asset: TradeAsset) {
        self.asset = asset
    }

    init(from trade: Trade) {
        self.id = trade.id
        self.asset = trade.asset
        self.direction = trade.direction
        self.entryPrice = trade.entryPrice
        self.currentPrice = trade.currentPrice
        self.stopLoss = trade.stopLoss
        self.takeProfit = trade.takeProfit
        self.openedAt = trade.openedAt
        self.notes = trade.notes
    }
}

#Preview {
    DashboardView(accessToken: "dummy-access-token")
}
