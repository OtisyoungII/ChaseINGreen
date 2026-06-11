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
    @State private var brokerAccounts: [BrokerAccountResponse] = []
    
    private var filteredTrades: [LoggedTradeResponse] {
        guard let selectedSymbol else { return activeTrades }
        return activeTrades.filter { $0.symbol.uppercased() == selectedSymbol.rawValue }
    }
    
    private var activeSymbolForSheet: String {
        selectedSymbol?.rawValue ?? "TQQQ"
    }
    
    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection
                        assetPickerSection
                        activeTradesSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Trades")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingNewTradeSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(AppTheme.gold)
                    }
                }
            }
            .sheet(isPresented: $showingNewTradeSheet) {
                TradeEntrySheet(
                    symbol: activeSymbolForSheet,
                    currentPrice: nil,
                    brokerAccounts: brokerAccounts,
                    accessToken: accessToken
                ) { payload in
                    Task {
                        await saveTrade(payload)
                    }
                }
            }
            .task {
                await loadBrokerAccounts()
                await loadTrades()
            }
            .refreshable {
                await loadTrades()
            }
        }
    }
    
    private func loadBrokerAccounts() async {
        do {
            brokerAccounts = try await APIService.shared.fetchBrokerAccounts(accessToken: accessToken)
        } catch {
            errorMessage = "Could not load broker accounts: \(error.localizedDescription)"
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trade Monitor")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.primaryText)
            
            Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.danger)
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
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.softGold)
            
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
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.softGold)
            
            if filteredTrades.isEmpty {
                AppUnavailableView(
                    title: "No Open Trades",
                    systemImage: "tray",
                    message: selectedSymbol == nil
                    ? "Tap + to add your first trade."
                    : "Use Quick Log Trade to add one for \(selectedSymbol?.displayName ?? "this symbol")."
                )
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
            
            _ = try await APIService.shared.createTrade(
                payload,
                accessToken: accessToken
            )
            
            let tradeLogPayload = TradeLogCreateRequest(
                symbol: payload.symbol,
                broker: payload.platform,
                accountType: inferAccountType(from: payload.platform),
                accountSize: payload.accountSize,
                direction: payload.direction == "long" ? "buy" : "sell",
                intent: "enter",
                entryPrice: payload.entryPrice,
                exitPrice: nil,
                stopLoss: payload.stopLoss,
                takeProfit: payload.takeProfit,
                positionSize: payload.quantity,
                riskAmount: nil,
                setupType: nil,
                marketPhase: nil,
                timeframe: nil,
                reasons: [],
                warnings: [],
                emotions: [],
                mistakes: [],
                confidence: "medium",
                outcome: "open",
                notes: payload.notes,
                instructionsCompleted: true,
                bypassInstructions: false,
                allowInstructionReplay: false,
                userConfirmedUnderstanding: false
            )
            
            _ = try? await APIService.shared.createTradeLog(
                tradeLogPayload,
                accessToken: accessToken
            )
            
            await loadTrades()
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
}

#Preview {
    TradeDashboardView(accessToken: "dummy-access-token")
}
