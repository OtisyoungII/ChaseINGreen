//
//  DashboardView.swift
//  ChaseINGreen
//
//  by: Otis Young
//

import SwiftUI

private struct WatchSymbol: Identifiable, Hashable, Codable {
    let requestSymbol: String
    let displayName: String
    let tradeSymbol: String
    let systemImage: String
    let isCustom: Bool

    var id: String { requestSymbol }

    init(
        requestSymbol: String,
        displayName: String,
        tradeSymbol: String,
        systemImage: String,
        isCustom: Bool = false
    ) {
        self.requestSymbol = requestSymbol
        self.displayName = displayName
        self.tradeSymbol = tradeSymbol
        self.systemImage = systemImage
        self.isCustom = isCustom
    }

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
            systemImage: "star.circle.fill",
            isCustom: true
        )
    }
}

private struct AccountTradeGroup: Identifiable {
    let id: String
    let broker: String
    let accountName: String
    let accountSize: Double?
    let trades: [LoggedTradeResponse]
    let openPnl: Double

    var tradeCount: Int { trades.count }

    var accountImpactPercent: Double? {
        guard let accountSize, accountSize > 0 else { return nil }
        return (openPnl / accountSize) * 100
    }
}

struct DashboardView: View {
    let accessToken: String

    @AppStorage("chaseingreen.custom.watchlist.v1") private var customWatchlistData = ""

    @State private var selectedSymbol: WatchSymbol = WatchSymbol.presets[0]
    @State private var customSymbolText = ""
    
    @State private var showingQuickEntry = false
    @State private var activePrompt: TradeActionPrompt?

    @State private var trades: [LoggedTradeResponse] = []
    @State private var tradeStats: TradeStatsSummaryResponse?
    @State private var backendStatus = "Checking..."
    @State private var errorMessage: String?
    @State private var currentQuote: QuoteResponse?
    @State private var currentTradeAlert: TradeAlertResponse?
    @State private var lastQuoteUpdate: Date?
    @State private var lastQuoteFetchTime: Date?
    @State private var lastQuoteFetchSymbol: String?
    @State private var isLoadingDashboard = false
    @State private var isAdmin = false
    @FocusState private var isSymbolSearchFocused: Bool
    
    @State private var showingWatchlist = false
    @State private var dashboardWatchlists: [WatchlistResponse] = []
    @State private var selectedDashboardWatchlistId: UUID?
    @State private var lastDashboardWatchlistFetchTime: Date?
    @State private var brokerAccounts: [BrokerAccountResponse] = []
    @State private var preTradeContext: PreTradeContextResponse?
    @State private var preTradeLoading = false
    @State private var preTradeError: String?
    @State private var tradeOpportunity: TradeOpportunityResponse?
    @State private var tradeOpportunityError: String?
    

    private let refreshTimer = Timer.publish(every: 120, on: .main, in: .common).autoconnect()

    private var customWatchlist: [WatchSymbol] {
        guard let data = customWatchlistData.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([WatchSymbol].self, from: data) else {
            return []
        }

        return decoded
    }

    private var fullWatchlist: [WatchSymbol] {
        var seen = Set<String>()
        var combined: [WatchSymbol] = []

        for symbol in WatchSymbol.presets + customWatchlist {
            let key = symbol.requestSymbol.uppercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            combined.append(symbol)
        }

        return combined
    }

    private var quickWatchlist: [WatchSymbol] {
        Array(fullWatchlist.prefix(12))
    }

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
    
    private var selectedDashboardWatchlist: WatchlistResponse? {
        if let selectedDashboardWatchlistId,
           let match = dashboardWatchlists.first(where: { $0.id == selectedDashboardWatchlistId }) {
            return match
        }

        return dashboardWatchlists.first
    }

    private var selectedDashboardWatchSymbols: [WatchSymbol] {
        guard let selectedDashboardWatchlist else { return [] }

        return selectedDashboardWatchlist.symbols.map { raw in
            if let preset = fullWatchlist.first(where: {
                $0.requestSymbol.uppercased() == raw.uppercased()
                || $0.displayName.uppercased() == raw.uppercased()
                || $0.tradeSymbol.uppercased() == raw.uppercased()
            }) {
                return preset
            }

            return WatchSymbol.custom(raw)
        }
    }

    private var accountGroups: [AccountTradeGroup] {
        let grouped = Dictionary(grouping: filteredTrades) { trade in
            trade.accountGroupKey
            ?? trade.brokerAccountId
            ?? "\(trade.platform ?? "Unknown")-\(trade.brokerAccountName ?? "")-\(trade.accountSize.map { String($0) } ?? "unknown")"
        }

        return grouped.map { key, groupTrades in
            let first = groupTrades[0]
            let broker = first.platform ?? "Unknown Broker"
            let accountName = first.brokerAccountName
            ?? first.accountGroupKey
            ?? first.brokerAccountId
            ?? "Ungrouped Account"
            let accountSize = first.accountSize
            let openPnl = groupTrades.compactMap { estimatedOpenPnl(for: $0) }.reduce(0, +)

            return AccountTradeGroup(
                id: key,
                broker: broker,
                accountName: accountName,
                accountSize: accountSize,
                trades: groupTrades,
                openPnl: openPnl
            )
        }
        .sorted { $0.broker < $1.broker }
    }

    private var activeSymbolForSheet: String {
        selectedSymbol.tradeSymbol
    }

    private var selectedOpenPnl: Double {
        filteredTrades.compactMap { estimatedOpenPnl(for: $0) }.reduce(0, +)
    }

    private var selectedAccountSize: Double? {
        filteredTrades.compactMap(\.accountSize).first
    }

    private var selectedOpenPnlPercent: Double? {
        guard let selectedAccountSize, selectedAccountSize > 0 else { return nil }
        return (selectedOpenPnl / selectedAccountSize) * 100
    }

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    brandHeroSection

                    if currentTradeAlert?.flashAlert == true {
                        emergencyTopStrip
                    }

                    headerSection
                    symbolSearchSection
                    symbolShortcutSection
                    selectedWatchlistShortcutSection
                    quoteSection
                    preTradeContextSection
                    pnlSummarySection
                    tradeOpportunitySection
                    tradeStatsSection
                    accountGroupsSection
                    tradeAlertSection
                    activeTradesSection
                }
                .padding()
            }
        }
        .navigationTitle("Trade Home")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: trailingToolbarPlacement) {
                NavigationLink {
                    AboutView()
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(AppTheme.gold)
                }
            }
        }
        #if os(iOS)
        .toolbarBackground(.hidden, for: .navigationBar)
        #endif
        .sheet(isPresented: $showingQuickEntry) {
            quickTradeSheet
        }
        .sheet(item: $activePrompt) { prompt in
            TradeActionSheet(
                prompt: prompt,
                currentQuotePrice: currentQuote?.price,
                accessToken: accessToken
            ) {
                await loadDashboard(forceQuote: false)
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
            }
        }
        .onChange(of: selectedSymbol) { _, _ in
            Task {
                currentTradeAlert = nil
                await loadDashboard(forceQuote: true)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: selectedSymbol.systemImage)
                    .font(.title2)
                    .foregroundStyle(AppTheme.gold)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.cardBlack)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppTheme.cardStroke, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("TradeChaser")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.primaryText)
                    
                    Text(Date.now.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            
            Text("Engine: \(backendStatus)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.danger)
            }
            if isAdmin {
                NavigationLink {
                    AdminHomeView(accessToken: accessToken)
                } label: {
                    Label("Admin Panel", systemImage: "shield.lefthalf.filled")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.deepBlack)
                .background(AppTheme.gold)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            HStack(spacing: 12) {
                statCard(title: "Open Trades", value: "\(trades.count)", systemImage: "chart.line.uptrend.xyaxis")
                statCard(title: "Watching", value: selectedSymbol.displayName, systemImage: selectedSymbol.systemImage)
            }
            
            Button {
                showingQuickEntry = true
            }
            label: {
                Label("Quick Log Trade", systemImage: "plus.circle.fill")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.deepBlack)
            .background(
                LinearGradient(
                    colors: [AppTheme.gold, AppTheme.softGold],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            NavigationLink {
                BrokerAccountsView(
                    accessToken: accessToken
                )
            } label: {
                Label(
                    "Broker Accounts",
                    systemImage: "building.columns.fill"
                )
                .font(.headline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.gold)
            .background(AppTheme.cardBlack)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.gold.opacity(0.35), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
        }
    }
    

    private var tradeStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Trade Performance")

            if let stats = tradeStats {
                let displayPnl = stats.totalNetPnl ?? stats.totalRealizedPnl
                let grossPnl = stats.totalGrossPnl ?? stats.totalRealizedPnl
                let totalCosts = (stats.totalCommissionPaid ?? 0) + (stats.totalFeesPaid ?? 0)

                HStack(spacing: 12) {
                    statCard(title: "Win Rate", value: formatPercent(stats.winRate), systemImage: "target")
                    statCard(title: "Net P/L", value: formatMoney(displayPnl), systemImage: displayPnl >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                }

                HStack(spacing: 12) {
                    statCard(title: "Gross P/L", value: formatMoney(grossPnl), systemImage: "chart.line.uptrend.xyaxis")
                    statCard(title: "Costs", value: formatMoney(-abs(totalCosts)), systemImage: "minus.circle.fill")
                }

                HStack(spacing: 12) {
                    statCard(title: "Closed Trades", value: "\(stats.totalClosedTrades)", systemImage: "checkmark.circle.fill")
                    statCard(title: "Protected Wins", value: "\(stats.protectedProfitTrades)", systemImage: "shield.checkered")
                }

                HStack(spacing: 12) {
                    statCard(title: "Avg Win", value: stats.avgWin.map { formatMoney($0) } ?? "--", systemImage: "plus.circle.fill")
                    statCard(title: "Avg Loss", value: stats.avgLoss.map { formatMoney($0) } ?? "--", systemImage: "minus.circle.fill")
                }

                Text("Net P/L subtracts broker costs when available. Gross P/L is before commission, spread, swap, routing, and other fees.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                unavailableCard(
                    title: "No Performance Yet",
                    message: "Your trade performance will appear after trades are logged and closed."
                )
            }
        }
    }
    
    private var selectedWatchlistShortcutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Selected Watchlist")

                Spacer()

                if dashboardWatchlists.count > 1 {
                    Picker("Watchlist", selection: Binding(
                        get: { selectedDashboardWatchlistId },
                        set: { newValue in
                            selectedDashboardWatchlistId = newValue
                        }
                    )) {
                        ForEach(dashboardWatchlists) { watchlist in
                            Text(watchlist.title).tag(UUID?.some(watchlist.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.gold)
                }
            }

            if selectedDashboardWatchSymbols.isEmpty {
                unavailableCard(
                    title: "No Symbols Saved",
                    message: "Open Full Watchlist to add symbols."
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(selectedDashboardWatchSymbols) { symbol in
                            symbolButton(
                                title: symbol.displayName,
                                systemImage: symbol.systemImage,
                                isSelected: selectedSymbol == symbol
                            ) {
                                selectSymbol(symbol)
                            }
                        }
                    }
                }
            }
        }
    }

    private var symbolSearchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Search Any Ticker")

            HStack(spacing: 10) {
                customSymbolTextField

                Button {
                    searchCustomSymbol()
                } label: {
                    Text("Search")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.deepBlack)
                .background(AppTheme.gold)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(customSymbolText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(customSymbolText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }

            Button {
                isSymbolSearchFocused = false
                showingWatchlist = true
            } label: {
                Label("Open Full Watchlist", systemImage: "list.bullet.rectangle.fill")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.gold)
            .background(AppTheme.cardBlack)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.gold.opacity(0.35), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text("Search matches presets first so NQ, ES, Gold, Silver, Oil, and Bitcoin route to the correct market symbols. Custom symbols can be saved in the full watchlist.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .sheet(isPresented: $showingWatchlist, onDismiss: {
            Task {
                await loadDashboardWatchlists(force: true)
            }
        }) {
            WatchlistView(accessToken: accessToken) { symbol in
                let watchSymbol = WatchSymbol.custom(symbol)
                selectSymbol(watchSymbol)
                showingWatchlist = false
            }
        }
    }
    
    private var trailingToolbarPlacement: ToolbarItemPlacement {
    #if os(iOS)
        return .topBarTrailing
    #else
        return .automatic
    #endif
    }

    private var symbolShortcutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Watchlist")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(quickWatchlist) { symbol in
                        symbolButton(
                            title: symbol.displayName,
                            systemImage: symbol.systemImage,
                            isSelected: selectedSymbol == symbol
                        ) {
                            selectSymbol(symbol)
                        }
                    }

                    Button {
                        showingWatchlist = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.gold)

                            Text("More")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        .frame(width: 86, height: 86)
                        .background(AppTheme.cardBlack)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(AppTheme.gold.opacity(0.45), lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var quoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Live Market")

            if let quote = currentQuote {
                NavigationLink {
                    MarketDetailView(
                        requestSymbol: selectedSymbol.requestSymbol,
                        displayName: selectedSymbol.displayName,
                        tradeSymbol: selectedSymbol.tradeSymbol,
                        accessToken: accessToken
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(selectedSymbol.displayName)
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
                            marketMetric("Open", quote.open)
                            marketMetric("High", quote.high)
                            marketMetric("Low", quote.low)
                        }

                        HStack {
                            marketMetric("Prev Close", quote.previousClose)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Volume")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)

                                Text(formatVolume(quote.volume))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(AppTheme.primaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Text("\(quote.priceLabel) • \(quote.freshness) • \(quote.marketState ?? "Unknown")")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)

                        if let lastQuoteUpdate {
                            Text("Updated \(lastQuoteUpdate.formatted(date: .omitted, time: .standard))")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        Text("Tap for full market view")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.gold)
                    }
                    .padding()
                    .background(AppTheme.cardBlack)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(AppTheme.gold.opacity(0.45), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
            } else {
                unavailableCard(
                    title: "No Market Price",
                    message: "Search a symbol or pull down to refresh the current watchlist price."
                )
            }
        }
    }
    private var preTradeContextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Pre-Trade Context")

            if preTradeLoading {
                ProgressView()
                    .tint(AppTheme.gold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.cardBlack)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else if let preTradeContext {
                PreTradeContextCard(
                    context: preTradeContext,
                    isLoading: preTradeLoading,
                    errorMessage: preTradeError
                ) {
                    Task {
                        await loadPreTradeContext()
                    }
                }
            } else if let preTradeError {
                unavailableCard(
                    title: "Pre-Trade Context Unavailable",
                    message: preTradeError
                )
            } else {
                unavailableCard(
                    title: "No Pre-Trade Context",
                    message: "Pre-trade setup will load for \(selectedSymbol.displayName)."
                )
            }
        }
    }
    private var tradeOpportunitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Trade Opportunity")

            if let tradeOpportunity {
                TradeOpportunityCard(opportunity: tradeOpportunity)
            } else if let tradeOpportunityError {
                unavailableCard(title: "Trade Opportunity Unavailable", message: tradeOpportunityError)
            } else {
                unavailableCard(title: "No Opportunity Yet", message: "Opportunity engine will load for \(selectedSymbol.displayName).")
            }
        }
    }
    
    private func loadTradeOpportunity() async {
        do {
            tradeOpportunityError = nil

            tradeOpportunity = try await APIService.shared.fetchTradeOpportunity(
                symbol: selectedSymbol.requestSymbol,
                accessToken: accessToken
            )
        } catch {
            tradeOpportunity = nil
            tradeOpportunityError = error.localizedDescription
        }
    }
    
    
    private var pnlSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Selected Symbol P/L")

            HStack(spacing: 12) {
                statCard(
                    title: "Open P/L",
                    value: formatMoney(selectedOpenPnl),
                    systemImage: selectedOpenPnl >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
                )

                statCard(
                    title: "Account Impact",
                    value: selectedOpenPnlPercent.map { formatPercent($0) } ?? "--",
                    systemImage: "percent"
                )
            }

            Text("P/L uses broker/current price when available. Account totals group trades by broker account key.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var accountGroupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Grouped Account P/L")

            if accountGroups.isEmpty {
                unavailableCard(
                    title: "No Account Groups",
                    message: "Open trades will group here by broker account key."
                )
            } else {
                ForEach(accountGroups) { group in
                    accountGroupCard(group)
                }
            }
        }
    }

    private var tradeAlertSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Trade Alert")

            if let alert = currentTradeAlert {
                TradeAlertCard(
                    alert: alert,
                    onSelectOption: handleAlertResponse
                )
            } else {
                unavailableCard(
                    title: "No Active Alert",
                    message: "Alerts appear when there is an open trade for \(selectedSymbol.displayName)."
                )
            }
        }
    }

    private var activeTradesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Open Trades")

            if filteredTrades.isEmpty {
                unavailableCard(
                    title: "No Open Trades",
                    message: "No open trades for \(selectedSymbol.displayName)."
                )
            } else {
                ForEach(filteredTrades) { trade in
                    VStack(alignment: .leading, spacing: 10) {
                        tradePnlStrip(for: trade)

                        TradeCardView(trade: trade)

                        TradeActionPanel(
                            trade: trade,
                            currentQuotePrice: trade.currentPrice ?? currentQuote?.price
                        ) { prompt in
                            activePrompt = prompt
                        }
                    }
                }
            }
        }
    }

    private func accountGroupCard(_ group: AccountTradeGroup) -> some View {
        let tint: Color = group.openPnl >= 0 ? .green : .red

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.broker)
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)

                    Text(group.accountName)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Text(formatMoney(group.openPnl))
                    .font(.headline.bold())
                    .foregroundStyle(tint)
            }

            HStack {
                metricText("Trades", "\(group.tradeCount)")
                metricText("Account", group.accountSize.map { formatPlainMoney($0) } ?? "--")
                metricText("Impact", group.accountImpactPercent.map { formatPercent($0) } ?? "--")
            }
        }
        .padding()
        .background(AppTheme.cardBlack)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.34), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func tradePnlStrip(for trade: LoggedTradeResponse) -> some View {
        let pnl = estimatedOpenPnl(for: trade)
        let pnlPercent = estimatedOpenPnlPercent(for: trade)
        let tint: Color = (pnl ?? 0) >= 0 ? .green : .red

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Open P/L")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)

                Text(pnl.map { formatMoney($0) } ?? "--")
                    .font(.headline.bold())
                    .foregroundStyle(tint)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Impact")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)

                Text(pnlPercent.map { formatPercent($0) } ?? "--")
                    .font(.headline.bold())
                    .foregroundStyle(tint)
            }
        }
        .padding()
        .background(AppTheme.cardBlack)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var customSymbolTextField: some View {
        let field = TextField("Example: TQQQ, NQ, Gold, BTC", text: $customSymbolText)
            .appTextField()
            .foregroundStyle(AppTheme.primaryText)
            .tint(AppTheme.gold)
            .focused($isSymbolSearchFocused)
            .onSubmit {
                searchCustomSymbol()
            }

    #if os(iOS)
        return field
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .submitLabel(.search)
    #else
        return field
    #endif
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .black, design: .rounded))
            .foregroundStyle(AppTheme.softGold)
    }

    private func unavailableCard(title: String, message: String) -> some View {
        AppUnavailableView(
            title: title,
            systemImage: "tray",
            message: message
        )
    }

    private func searchCustomSymbol() {
        let cleaned = customSymbolText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !cleaned.isEmpty else { return }

        if let existing = fullWatchlist.first(where: {
            $0.requestSymbol.uppercased() == cleaned ||
            $0.displayName.uppercased() == cleaned ||
            $0.tradeSymbol.uppercased() == cleaned
        }) {
            selectSymbol(existing)
        } else {
            let custom = WatchSymbol.custom(cleaned)
            saveCustomWatchSymbol(custom)
            selectSymbol(custom)
        }
    }
    private func loadDashboardWatchlists(force: Bool = false) async {
        if !force,
           let lastFetch = lastDashboardWatchlistFetchTime,
           Date().timeIntervalSince(lastFetch) < 60 {
            return
        }

        do {
            dashboardWatchlists = try await APIService.shared.fetchWatchlists(accessToken: accessToken)
            lastDashboardWatchlistFetchTime = Date()

            if selectedDashboardWatchlistId == nil {
                selectedDashboardWatchlistId = dashboardWatchlists.first?.id
            }
        } catch {
            print("⚠️ Could not load dashboard watchlists: \(error.localizedDescription)")
        }
    }

    

    private func saveCustomWatchSymbol(_ symbol: WatchSymbol) {
        var current = customWatchlist

        guard !current.contains(where: { $0.requestSymbol.uppercased() == symbol.requestSymbol.uppercased() }) else {
            return
        }

        current.append(symbol)
        persistCustomWatchlist(current)
    }


    private func persistCustomWatchlist(_ symbols: [WatchSymbol]) {
        guard let data = try? JSONEncoder().encode(symbols),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        customWatchlistData = json
    }

    private func selectSymbol(_ symbol: WatchSymbol) {
        selectedSymbol = symbol
        customSymbolText = ""
        isSymbolSearchFocused = false
    }

    private func loadDashboard(forceQuote: Bool = false) async {
        guard !isLoadingDashboard else { return }

        isLoadingDashboard = true
        defer { isLoadingDashboard = false }

        await loadCurrentUser()
        await loadHealth()
        await loadBrokerAccounts()
        await loadDashboardWatchlists(force: forceQuote)
        await loadQuote(force: forceQuote)
        await loadPreTradeContext()
        await loadTradeOpportunity()
        await loadTrades()
        await loadTradeStats()
        await loadTradeAlert()
    }
    private func loadCurrentUser() async {
        do {
            let user = try await APIService.shared.fetchCurrentUser(accessToken: accessToken)
            isAdmin = user.isAdmin
        } catch {
            isAdmin = false
        }
    }
    
    private func loadBrokerAccounts() async {
        do {
            brokerAccounts = try await APIService.shared.fetchBrokerAccounts(accessToken: accessToken)
        } catch {
            print("Could not load broker accounts: \(error.localizedDescription)")
        }
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

    private func loadTradeStats() async {
        do {
            errorMessage = nil
            tradeStats = try await APIService.shared.fetchTradeStats(accessToken: accessToken)
        } catch {
            errorMessage = "Could not load trade stats: \(error.localizedDescription)"
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
            openPnl: estimatedOpenPnl(for: trade),
            realizedPnl: trade.realizedPnl,
            maxDailyLossAllowed: trade.maxDailyLossAllowed,
            maxTotalLossAllowed: trade.maxTotalLossAllowed,
            payoutTarget: trade.payoutTarget,
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
    private func loadPreTradeContext() async {
        preTradeLoading = true
        preTradeError = nil

        do {
            let request = PreTradeContextRequest(
                symbol: selectedSymbol.requestSymbol
            )

            preTradeContext = try await APIService.shared.fetchPreTradeContext(
                request,
                accessToken: accessToken
            )
        } catch {
            preTradeContext = nil
            preTradeError = error.localizedDescription
        }

        preTradeLoading = false
    }
    private func handleAlertResponse(_ option: String) {
        guard let trade = filteredTrades.first else {
            errorMessage = "No active trade available."
            return
        }

        let lower = option.lowercased()

        if lower.contains("update broker price") {
            activePrompt = .brokerPrice(trade)
            return
        }

        if lower.contains("still in") {
            Task {
                await markStillIn(trade)
            }
            return
        }

        if lower.contains("got out") {
            activePrompt = .close(trade)
            return
        }

        if lower.contains("took profit") {
            activePrompt = .takeProfitHit(trade)
            return
        }

        if lower.contains("reduced") {
            activePrompt = .reduce(trade)
            return
        }
    }

    private func markStillIn(_ trade: LoggedTradeResponse) async {
        guard let quotePrice = currentQuote?.price else {
            errorMessage = "No quote price available to update this trade."
            return
        }

        do {
            errorMessage = nil

            _ = try await APIService.shared.updateBrokerPrice(
                tradeId: trade.id,
                currentPrice: quotePrice,
                notes: "Still in. App quote used as temporary price check.",
                accessToken: accessToken
            )

            await loadDashboard(forceQuote: false)
        } catch {
            errorMessage = "Could not mark still in: \(error.localizedDescription)"
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

            await loadDashboard(forceQuote: false)
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
    
    private var quickTradeSheet: some View {
        TradeEntrySheet(
            symbol: activeSymbolForSheet,
            currentPrice: currentQuote?.price,
            brokerAccounts: brokerAccounts,
            accessToken: accessToken
        ) { payload in
            Task {
                await saveTrade(payload)
            }
        }
    }

    private func estimatedOpenPnl(for trade: LoggedTradeResponse) -> Double? {
        if let netPnl = trade.netPnl {
            return netPnl
        }

        if let openPnl = trade.openPnl {
            return openPnl
        }

        guard let currentPrice = trade.currentPrice,
              let quantity = trade.quantity else {
            return nil
        }

        let multiplier = contractMultiplier(for: trade.symbol)
        let direction = trade.direction.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if direction == "long" {
            return (currentPrice - trade.entryPrice) * quantity * multiplier
        }

        if direction == "short" {
            return (trade.entryPrice - currentPrice) * quantity * multiplier
        }

        return nil
    }

    private func estimatedOpenPnlPercent(for trade: LoggedTradeResponse) -> Double? {
        guard let pnl = estimatedOpenPnl(for: trade),
              let accountSize = trade.accountSize,
              accountSize > 0 else {
            return nil
        }

        return (pnl / accountSize) * 100
    }

    private func contractMultiplier(for symbol: String) -> Double {
        let normalized = symbol.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        switch normalized {
        case "XAUUSD", "GC=F", "GOLD":
            return 100
        case "XAGUSD", "SI=F", "SILVER":
            return 5000
        case "NQ", "NQ=F":
            return 20
        case "ES", "ES=F":
            return 50
        case "WTI", "CL=F":
            return 1000
        default:
            return 1
        }
    }

    private func statCard(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(AppTheme.gold)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.secondaryText)

                Text(value)
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.cardBlack)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        }
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
                    .foregroundStyle(isSelected ? AppTheme.gold : AppTheme.primaryText)

                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
            }
            .frame(width: 86, height: 86)
            .background(isSelected ? AppTheme.gold.opacity(0.15) : AppTheme.cardBlack)
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? AppTheme.gold : AppTheme.cardStroke, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private func marketMetric(_ title: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            Text(formatPrice(value))
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricText(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)

            Text(value)
                .font(.caption.bold())
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

    private func formatMoney(_ value: Double) -> String {
        String(format: "%@%.2f", value >= 0 ? "+$" : "-$", abs(value))
    }

    private func formatPlainMoney(_ value: Double) -> String {
        String(format: "$%.0f", value)
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%+.2f%%", value)
    }

    private func formatVolume(_ value: Int?) -> String {
        guard let value else { return "--" }
        return "\(value)"
    }

    private func quoteTint(_ quote: QuoteResponse) -> Color {
        guard let percentChange = quote.percentChange else {
            return AppTheme.secondaryText
        }

        if percentChange > 0 {
            return .green
        }

        if percentChange < 0 {
            return .red
        }

        return AppTheme.secondaryText
    }

    private var brandHeroSection: some View {
        HStack(spacing: 14) {
            Image("ChaseINGreenIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: AppTheme.gold.opacity(0.35), radius: 14, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 5) {
                Text("ChaseINGreen")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, AppTheme.softGold, AppTheme.gold],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.75), radius: 1, x: 1, y: 2)

                Text("Trade smarter. Protect profits.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: [
                    .white.opacity(0.14),
                    .white.opacity(0.05),
                    AppTheme.gold.opacity(0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(AppTheme.gold.opacity(0.45), lineWidth: 1.2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: AppTheme.gold.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    private var emergencyTopStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")

            Text("LIVE ACCOUNT WARNING")
                .font(.caption.bold())

            Spacer()

            Text("VERIFY BROKER PRICE")
                .font(.caption2.bold())
        }
        .foregroundStyle(.white)
        .padding()
        .background(
            LinearGradient(
                colors: [.red, .orange],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        DashboardView(accessToken: "dummy-access-token")
    }
}
