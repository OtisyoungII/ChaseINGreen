//
//  DashboardView.swift
//  ChaseINGreen
//
//  by: Otis Young
//

import SwiftUI

private struct AccountTradeGroup: Identifiable {
    let id: String
    let broker: String
    let accountName: String
    let maxDrawdownLimit: Double?
    let trades: [LoggedTradeResponse]
    let openPnl: Double

    var tradeCount: Int { trades.count }

    /// Position volume is only additive when every live position represents
    /// the same instrument. Account balance is deliberately not a substitute
    /// for trade size.
    var brokerConfirmedVolume: Double? {
        let symbols = Set(
            trades.map {
                $0.symbol.trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()
            }
        )
        guard symbols.count == 1 else { return nil }

        let volumes = trades.compactMap(\.quantity)
        guard volumes.count == trades.count else { return nil }

        return volumes.reduce(0) { partial, volume in
            partial + abs(volume)
        }
    }

    /// Aqua funded-account impact is measured against the saved account's
    /// actual maximum drawdown budget. Cash-account and unknown-rule groups
    /// intentionally remain unavailable instead of inventing a percentage.
    var drawdownImpactPercent: Double? {
        guard isAquaFundedAccount,
              let maxDrawdownLimit,
              maxDrawdownLimit > 0 else {
            return nil
        }
        return (openPnl / maxDrawdownLimit) * 100
    }

    private var isAquaFundedAccount: Bool {
        let source = broker.lowercased()
        return source.contains("aqua") || source.contains("match")
    }
}

private enum ProfitProtectionError: LocalizedError {
    case rejected(String)

    var errorDescription: String? {
        switch self {
        case .rejected(let message): return message
        }
    }
}

struct DashboardView: View {
    let accessToken: String

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("chaseingreen.custom.watchlist.v1") private var customWatchlistData = ""

    @State private var selectedSymbol: WatchSymbol = WatchSymbol.presets[0]
    @State private var customSymbolText = ""

    private var customSymbolSuggestions: [WatchSymbol] {
        WatchSymbol.suggestions(
            matching: customSymbolText,
            limit: 6
        )
    }
    
    @State private var showingQuickEntry = false
    @State private var activePrompt: TradeActionPrompt?

    @State private var trades: [LoggedTradeResponse] = []
    @State private var tradeStats: TradeStatsSummaryResponse?
    @State private var showingPaywall = false
    @State private var backendStatus = "Checking..."
    @State private var errorMessage: String?
    @State private var currentQuote: QuoteResponse?
    @State private var currentTradeAlert: TradeAlertResponse?
    @State private var alertTargetTradeID: UUID?
    @State private var pendingProfitProtectionTrade: LoggedTradeResponse?
    @State private var pendingProtectionPositionIDs = Set<String>()
    @State private var protectionResultMessage: String?
    @State private var lastQuoteUpdate: Date?
    @State private var lastQuoteFetchTime: Date?
    @State private var lastQuoteFetchSymbol: String?
    @State private var isLoadingDashboard = false
    @State private var isAdmin = false
    @State private var isSecret = false
    @State private var workspaceAuthorization: InternalWorkspaceAuthorization?
    @State private var currentUserRequestID = UUID()
    @State private var userPlan = "free"
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
    @State private var lastAquaTruthRefreshTime: Date?
    @State private var isRefreshingAquaTruth = false
    @State private var isRefreshingTradeAlerts = false
    @State private var symbolRequestID = UUID()
    

    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    
    private var normalizedPlan: String {
        userPlan.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSecretOrAdmin: Bool {
        InternalWorkspaceRoutePolicy.permits(
            .dashboard,
            authorization: workspaceAuthorization
        )
    }

    private var canUseTradeAI: Bool {
        isSecretOrAdmin
    }

    private var tierLabel: String {
        if isAdmin { return "Admin" }
        if isSecret { return "Secret" }
        if normalizedPlan == "gold" { return "Gold" }
        if normalizedPlan == "premium" { return "Premium" }
        return "Free"
    }

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

        return selectedDashboardWatchlist.symbols.compactMap { raw in
            WatchSymbol.resolve(raw)
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
            let matchingAccount = brokerAccounts.first { account in
                accountMatchesTradeGroup(
                    account: account,
                    groupKey: key,
                    trade: first
                )
            }
            let openPnl = groupTrades.compactMap { estimatedOpenPnl(for: $0) }.reduce(0, +)

            return AccountTradeGroup(
                id: key,
                broker: broker,
                accountName: accountName,
                maxDrawdownLimit: matchingAccount?.maxDrawdownLimit,
                trades: groupTrades,
                openPnl: openPnl
            )
        }
        .sorted { $0.broker < $1.broker }
    }

    private func accountMatchesTradeGroup(
        account: BrokerAccountResponse,
        groupKey: String,
        trade: LoggedTradeResponse
    ) -> Bool {
        let candidates = [
            account.accountId,
            account.accountNumber,
            account.accountName,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        let tradeKeys = [
            groupKey,
            trade.brokerAccountId,
            trade.brokerAccountName,
            trade.accountGroupKey,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        return tradeKeys.contains { candidates.contains($0) }
    }

    private var activeSymbolForSheet: String {
        selectedSymbol.tradeSymbol
    }
    private var activeBrokerForWorkspace: String? {
        filteredTrades.first?.platform
    }

    private var activeAccountKeyForWorkspace: String? {
        filteredTrades.first?.accountGroupKey
        ?? filteredTrades.first?.brokerAccountId
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
                    pnlSummarySection
                    if canUseTradeAI {
                        preTradeContextSection
                        tradeOpportunitySection
                    }
                    
                    tradeStatsSection
                    calendarShortcutSection
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
                Button {
                    showingPaywall = true
                } label: {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(AppTheme.gold)
                }
                .accessibilityLabel("Subscriptions")
            }

            ToolbarItem(placement: trailingToolbarPlacement) {
                NavigationLink {
                    AboutView()
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(AppTheme.gold)
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            SubscriptionPaywallView(accessToken: accessToken)
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
        .alert(
            "Protect Profit",
            isPresented: Binding(
                get: { pendingProfitProtectionTrade != nil },
                set: { if !$0 { pendingProfitProtectionTrade = nil } }
            ),
            presenting: pendingProfitProtectionTrade
        ) { trade in
            Button("YES — Exit This Position", role: .destructive) {
                Task { await executeConfirmedProfitProtection(for: trade) }
            }
            .disabled(protectionClosePending(for: trade))

            Button("NO — Keep Position", role: .cancel) {
                Task { await declineProfitProtection(for: trade) }
            }
        } message: { trade in
            Text(profitProtectionMessage(for: trade))
        }
        .alert(
            "Profit Protection",
            isPresented: Binding(
                get: { protectionResultMessage != nil },
                set: { if !$0 { protectionResultMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { protectionResultMessage = nil }
        } message: {
            Text(protectionResultMessage ?? "")
        }
        .task {
            await loadDashboard(forceQuote: true)
        }
        .refreshable {
            await loadDashboard(forceQuote: true)
        }
        .onReceive(refreshTimer) { _ in
            Task {
                await refreshLiveTradeMonitoring()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else {
                return
            }

            // Never render a privileged route from pre-background state.
            // The fresh /me response below may restore it.
            isAdmin = false
            isSecret = false
            workspaceAuthorization = nil
            Task {
                await loadCurrentUser()
                await loadDashboard(forceQuote: false)
            }
        }
        .onChange(of: selectedSymbol) { _, newSymbol in
            let requestID = UUID()
            symbolRequestID = requestID
            clearSymbolSpecificContent()
            Task {
                await loadSymbolSpecificContent(
                    for: newSymbol,
                    requestID: requestID,
                    forceQuote: true
                )
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

            if isSecretOrAdmin {
                NavigationLink {
                    TradingWorkspaceView(
                        accessToken: accessToken,
                        symbol: selectedSymbol.tradeSymbol,
                        direction: nil,
                        broker: activeBrokerForWorkspace,
                        accountKey: nil
                    )
                } label: {
                    Label("Open Trading Workspace", systemImage: "brain.head.profile")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.deepBlack)
                .background(
                    LinearGradient(
                        colors: [AppTheme.softGold, AppTheme.gold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
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
                BrokerAccountsView(accessToken: accessToken)
            } label: {
                Label("Broker Accounts", systemImage: "building.columns.fill")
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

    private var calendarShortcutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Trading Calendar")

            NavigationLink {
                TradingCalendarView(accessToken: accessToken)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.softGold)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.softGold.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 13))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Review Real Trading Performance")
                            .font(.headline.bold())
                            .foregroundStyle(AppTheme.primaryText)

                        Text(
                            "Free and Gold users can review daily broker-linked trades, confirmed P/L, and outcomes needing verification."
                        )
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.gold)
                }
                .padding()
                .background(AppTheme.cardBlack)
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(AppTheme.gold.opacity(0.25), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
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

            if !customSymbolSuggestions.isEmpty {
                symbolSuggestionStrip(customSymbolSuggestions) { item in
                    errorMessage = nil
                    isSymbolSearchFocused = false
                    customSymbolText = ""
                    selectSymbol(item)
                }
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
                guard let watchSymbol = WatchSymbol.resolve(symbol) else {
                    errorMessage = "Enter a real ticker like AAPL, BTC, Gold, or Silver."
                    return
                }

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
                        accessToken: accessToken,

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
        let requestedSymbol = selectedSymbol
        let requestID = symbolRequestID
        do {
            tradeOpportunityError = nil

            let opportunity = try await APIService.shared.fetchTradeOpportunity(
                symbol: requestedSymbol.requestSymbol,
                accessToken: accessToken
            )
            guard requestID == symbolRequestID,
                  selectedSymbol == requestedSymbol,
                  opportunity.symbol.caseInsensitiveCompare(
                    requestedSymbol.requestSymbol
                  ) == .orderedSame else {
                return
            }
            tradeOpportunity = opportunity
            deliverOpportunityNotification(
                opportunity
            )
        } catch {
            guard requestID == symbolRequestID,
                  selectedSymbol == requestedSymbol else {
                return
            }
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
                metricText(
                    "Size",
                    group.brokerConfirmedVolume.map { formatVolume($0) } ?? "--"
                )
                metricText(
                    "DD Impact",
                    group.drawdownImpactPercent.map { formatPercent($0) } ?? "--"
                )
            }

            ForEach(group.trades) { trade in
                if isSecretOrAdmin {
                    NavigationLink {
                        TradingWorkspaceView(
                            accessToken: accessToken,
                            symbol: trade.symbol,
                            direction: trade.direction,
                            broker: trade.platform,
                            accountKey: trade.accountGroupKey
                                ?? trade.brokerAccountId,
                            focusedPositionID: trade.externalPositionId
                        )
                    } label: {
                        groupedTradeNavigationRow(trade)
                    }
                    .buttonStyle(.plain)
                } else {
                    groupedTradeNavigationRow(trade)
                }
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

    private func groupedTradeNavigationRow(
        _ trade: LoggedTradeResponse
    ) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(trade.symbol) • \(trade.direction.uppercased())")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.primaryText)

                Text(trade.brokerAccountName
                    ?? trade.accountGroupKey
                    ?? trade.brokerAccountId
                    ?? "Broker account")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            Text(estimatedOpenPnl(for: trade).map(formatMoney) ?? "--")
                .font(.subheadline.bold())
                .foregroundStyle((estimatedOpenPnl(for: trade) ?? 0) >= 0 ? .green : .red)

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.top, 6)
        .contentShape(Rectangle())
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

    private func symbolSuggestionStrip(
        _ items: [WatchSymbol],
        onSelect: @escaping (WatchSymbol) -> Void
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayName)
                                .font(.caption.bold())

                            Text(item.requestSymbol)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(AppTheme.gold)
                        .background(AppTheme.gold.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
        let cleaned = WatchSymbol.normalizedInput(customSymbolText)

        guard !cleaned.isEmpty else { return }

        guard let resolved = WatchSymbol.resolve(cleaned) else {
            errorMessage = "Enter a real ticker like AAPL, BTC, Gold, or Silver."
            return
        }

        errorMessage = nil

        if resolved.isCustom {
            saveCustomWatchSymbol(resolved)
        }

        selectSymbol(resolved)
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

        // ChaseINGreen core market intelligence is the critical path.
        // Broker/account availability must never block ticker intelligence.
        async let healthLoad: Void = loadHealth()
        async let watchlistLoad: Void = loadDashboardWatchlists(
            force: forceQuote
        )
        async let quoteLoad: Void = loadQuote(
            force: forceQuote
        )

        _ = await (
            healthLoad,
            watchlistLoad,
            quoteLoad
        )

        // Pre-trade intelligence works independently of broker state.
        if canUseTradeAI {
            async let contextLoad: Void = loadPreTradeContext()
            async let opportunityLoad: Void = loadTradeOpportunity()

            _ = await (
                contextLoad,
                opportunityLoad
            )
        } else {
            preTradeContext = nil
            tradeOpportunity = nil
        }

        // Broker services are deliberately NOT part of the market-
        // intelligence critical path.
        Task {
            await loadBrokerAccounts()
            await loadTrades()

            let changed = await refreshAquaTradeTruthIfNeeded()

            if changed {
                await loadTrades()
                await loadTradeStats()
                await loadTradeAlert()
            }
        }
    }

    @MainActor
    private func clearSymbolSpecificContent() {
        currentQuote = nil
        currentTradeAlert = nil
        preTradeContext = nil
        preTradeError = nil
        tradeOpportunity = nil
        tradeOpportunityError = nil
        lastQuoteUpdate = nil
    }

    private func loadSymbolSpecificContent(
        for symbol: WatchSymbol,
        requestID: UUID,
        forceQuote: Bool
    ) async {
        let quote: QuoteResponse?
        do {
            quote = try await APIService.shared.fetchQuote(
                for: symbol.requestSymbol,
                accessToken: accessToken,
                forceRefresh: forceQuote
            )
        } catch {
            quote = nil
        }

        guard requestID == symbolRequestID,
              selectedSymbol == symbol else {
            return
        }

        currentQuote = quote
        lastQuoteFetchTime = Date()
        lastQuoteFetchSymbol = symbol.requestSymbol
        lastQuoteUpdate = quote == nil ? nil : Date()

        guard canUseTradeAI else {
            return
        }

        async let contextResult = loadPreTradeContextValue(
            for: symbol
        )
        async let opportunityResult = loadTradeOpportunityValue(
            for: symbol
        )

        let (context, opportunity) = await (
            contextResult,
            opportunityResult
        )

        guard requestID == symbolRequestID,
              selectedSymbol == symbol else {
            return
        }

        preTradeLoading = false
        preTradeContext = context.value
        preTradeError = context.error
        tradeOpportunity = opportunity.value
        tradeOpportunityError = opportunity.error

        if let value = opportunity.value {
            deliverOpportunityNotification(value)
        }

        await loadTradeAlert()
    }

    private func loadPreTradeContextValue(
        for symbol: WatchSymbol
    ) async -> (value: PreTradeContextResponse?, error: String?) {
        do {
            let request = PreTradeContextRequest(
                symbol: symbol.requestSymbol,
                broker: activeBrokerForWorkspace,
                accountKey: activeAccountKeyForWorkspace,
                useMatchTraderQuote: isMatchTraderBroker,
                matchTraderAccountID: activeAccountKeyForWorkspace,
                includeMatchTraderTimeframes: isMatchTraderBroker
            )
            return (
                try await APIService.shared.fetchPreTradeContext(
                    request,
                    accessToken: accessToken
                ),
                nil
            )
        } catch {
            return (nil, error.localizedDescription)
        }
    }

    private func loadTradeOpportunityValue(
        for symbol: WatchSymbol
    ) async -> (value: TradeOpportunityResponse?, error: String?) {
        do {
            return (
                try await APIService.shared.fetchTradeOpportunity(
                    symbol: symbol.requestSymbol,
                    accessToken: accessToken
                ),
                nil
            )
        } catch {
            return (nil, error.localizedDescription)
        }
    }
    private func loadCurrentUser() async {
        let requestID = UUID()
        currentUserRequestID = requestID
        do {
            let user = try await APIService.shared.fetchCurrentUser(accessToken: accessToken)
            guard currentUserRequestID == requestID else { return }
            isAdmin = user.isAdmin
            isSecret = user.isSecret
            workspaceAuthorization = user.internalWorkspaceAuthorization
            userPlan = user.plan ?? "free"
        } catch {
            guard currentUserRequestID == requestID else { return }
            isAdmin = false
            isSecret = false
            workspaceAuthorization = nil
            userPlan = "free"
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

    @MainActor
    private func refreshAquaTradeTruthIfNeeded() async -> Bool {
        guard !isRefreshingAquaTruth else {
            return false
        }

        if let lastAquaTruthRefreshTime,
           Date().timeIntervalSince(lastAquaTruthRefreshTime) < 45 {
            return false
        }

        isRefreshingAquaTruth = true

        defer {
            isRefreshingAquaTruth = false
        }

        do {
            let health = try await APIService.shared
                .fetchMatchTraderAuthHealth(
                    accessToken: accessToken
                )

            guard health.sessionReady else {
                lastAquaTruthRefreshTime = Date()
                return false
            }

            let storedAquaAccountIds = Array(Set(
                trades.compactMap { trade -> String? in
                    guard trade.isOpen else {
                        return nil
                    }

                    let platform = (
                        trade.platform ?? ""
                    ).lowercased()

                    guard platform.contains("match")
                            || platform.contains("aqua") else {
                        return nil
                    }

                    return trade.brokerAccountId
                        ?? trade.accountGroupKey
                }
            ))
            .sorted()
            .prefix(4)

            await withTaskGroup(of: Void.self) { group in
                for accountId in storedAquaAccountIds {
                    group.addTask {
                        do {
                            _ = try await APIService.shared
                                .syncMatchTraderPositions(
                                    MatchTraderSyncRequest(
                                        broker: "Aqua Funding",
                                        accountId: accountId,
                                        symbols: []
                                    ),
                                    accessToken: accessToken
                                )
                        } catch {
                            print(
                                "⚠️ Aqua background reconciliation failed " +
                                "for \(accountId): \(error.localizedDescription)"
                            )
                        }
                    }
                }

                await group.waitForAll()
            }

            lastAquaTruthRefreshTime = Date()
            return !storedAquaAccountIds.isEmpty

        } catch {
            // Dashboard quotes and stored trades remain usable if Aqua is
            // temporarily unavailable. The dedicated Aqua panel surfaces
            // connection errors and supports explicit retry.
            return false
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
            alertTargetTradeID = nil
            return
        }
        let requestID = symbolRequestID
        let requestedSymbol = selectedSymbol

        let request = tradeAlertRequest(
            for: trade
        )

        let brokerSessionOpen = await brokerSessionOpen(
            for: trade
        )

        do {
            errorMessage = nil

            let alert = try await APIService.shared.fetchTradeAlert(
                request,
                accessToken: accessToken
            )
            guard requestID == symbolRequestID,
                  selectedSymbol == requestedSymbol,
                  alert.symbol.caseInsensitiveCompare(trade.symbol) == .orderedSame else {
                return
            }
            currentTradeAlert = alert
            alertTargetTradeID = trade.id
            if brokerSessionOpen != false {
                deliverTradeNotification(
                    alert,
                    trade: trade
                )
            }
        } catch {
            guard requestID == symbolRequestID,
                  selectedSymbol == requestedSymbol else {
                return
            }
            errorMessage = "Could not load trade alert: \(error.localizedDescription)"
        }
    }

    private func tradeAlertRequest(
        for trade: LoggedTradeResponse
    ) -> TradeAlertRequest {
        TradeAlertRequest(
            positionId: trade.externalPositionId,
            tradeId: trade.id.uuidString,
            accountId: trade.brokerAccountId ?? trade.accountGroupKey,
            symbol: trade.symbol,
            direction: trade.direction,
            entryPrice: trade.entryPrice,
            currentBrokerPrice: trade.currentPrice
                ?? (
                    trade.symbol.caseInsensitiveCompare(
                        selectedSymbol.requestSymbol
                    ) == .orderedSame
                        ? currentQuote?.price
                        : nil
                ),
            currentAppPrice: (
                trade.symbol.caseInsensitiveCompare(
                    selectedSymbol.requestSymbol
                ) == .orderedSame
                    ? currentQuote?.price
                    : nil
            ),
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
            peakOpenPnl: estimatedPeakOpenPnl(for: trade),
            realizedPnl: trade.realizedPnl,
            maxDailyLossAllowed: trade.maxDailyLossAllowed,
            maxTotalLossAllowed: trade.maxTotalLossAllowed,
            payoutTarget: trade.payoutTarget,
            notes: trade.notes
        )
    }

    private func refreshLiveTradeMonitoring() async {
        guard !isRefreshingTradeAlerts else {
            return
        }

        isRefreshingTradeAlerts = true
        defer {
            isRefreshingTradeAlerts = false
        }

        await loadQuote(force: false)

        if canUseTradeAI {
            await loadTradeOpportunity()
        }

        await loadTrades()

        if await refreshAquaTradeTruthIfNeeded() {
            await loadTrades()
        }

        await refreshOpenTradeNotifications()
    }

    private func refreshOpenTradeNotifications() async {
        var seen = Set<String>()
        var monitored = 0

        for trade in trades where trade.isOpen {
            let requestID = symbolRequestID
            let key = [
                trade.platform ?? "broker",
                trade.accountGroupKey
                    ?? trade.brokerAccountId
                    ?? "account",
                trade.symbol,
                trade.externalPositionId ?? trade.id.uuidString,
            ]
            .joined(separator: ":")
            .lowercased()

            guard seen.insert(key).inserted else {
                continue
            }

            guard monitored < 8 else {
                break
            }
            monitored += 1

            do {
                let brokerSessionOpen = await brokerSessionOpen(
                    for: trade
                )

                let alert = try await APIService.shared
                    .fetchTradeAlert(
                        tradeAlertRequest(for: trade),
                        accessToken: accessToken
                    )

                if brokerSessionOpen != false {
                    deliverTradeNotification(
                        alert,
                        trade: trade
                    )
                }

                if trade.symbol.caseInsensitiveCompare(
                    selectedSymbol.requestSymbol
                ) == .orderedSame,
                   requestID == symbolRequestID {
                    currentTradeAlert = alert
                    alertTargetTradeID = trade.id
                }
            } catch {
                continue
            }
        }
    }

    private func brokerSessionOpen(
        for trade: LoggedTradeResponse
    ) async -> Bool? {
        let broker = (trade.platform ?? "")
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        guard broker.contains("aqua")
                || broker.contains("match trader")
                || broker.contains("matchtrader"),
              let accountId = trade.brokerAccountId
                ?? trade.accountGroupKey,
              !accountId.isEmpty else {
            return nil
        }

        if let cached = APIService.shared
            .cachedMatchTraderSessionOpen(
                accountId: accountId,
                symbol: trade.symbol,
                accessToken: accessToken
            ) {
            return cached
        }

        do {
            _ = try await APIService.shared
                .fetchMatchTraderInstruments(
                    accountId: accountId,
                    accessToken: accessToken
                )

            return APIService.shared
                .cachedMatchTraderSessionOpen(
                    accountId: accountId,
                    symbol: trade.symbol,
                    accessToken: accessToken
                )
        } catch {
            return nil
        }
    }

    private func deliverTradeNotification(
        _ alert: TradeAlertResponse,
        trade: LoggedTradeResponse
    ) {
        guard alert.notificationEligible != false else {
            return
        }
        let severity = alert.severity.lowercased()
        let alertType = alert.alertType.lowercased()
        let decision = alert.decision.lowercased()
        let actionable = alert.needsUserResponse
            || alert.flashAlert == true
            || alert.soundAlert == true
            || [
                "critical",
                "danger",
                "high",
                "warning",
            ].contains(severity)
            || [
                "account_protection",
                "danger",
                "exit",
                "stop_loss",
            ].contains(alertType)
            || [
                "close",
                "exit",
                "protect",
                "reduce",
                "take_partial",
            ].contains(decision)

        guard actionable else {
            return
        }

        let accountKey = trade.accountGroupKey
            ?? trade.brokerAccountId
            ?? trade.platform
            ?? "account"
        let positionKey = trade.externalPositionId ?? trade.id.uuidString
        let key = "trade.\(accountKey).\(trade.symbol).\(positionKey)"
            .lowercased()
        let fingerprint = [
            alertType,
            severity,
            decision,
        ].joined(separator: "|")
        let critical = severity == "critical"
            || alertType == "exit"
            || alertType == "account_protection"

        ChaseTradeNotifications.deliver(
            key: key,
            fingerprint: fingerprint,
            title: "\(trade.symbol) • \(alert.title)",
            body: alert.message,
            critical: critical,
            routeUserInfo: [
                "symbol": trade.symbol,
                "broker": trade.platform ?? "Aqua Funding",
                "account_id": trade.brokerAccountId
                    ?? trade.accountGroupKey
                    ?? "",
                "position_id": trade.externalPositionId ?? "",
                "side": trade.direction,
                "decision": alert.decision,
            ]
        )
    }

    private func deliverOpportunityNotification(
        _ opportunity: TradeOpportunityResponse
    ) {
        let bias = opportunity.bias.lowercased()
        let action = opportunity.action.lowercased()
        let directional = [
            "bullish",
            "bearish",
            "buy",
            "sell",
            "long",
            "short",
        ].contains(bias)
            || [
                "buy",
                "sell",
                "enter",
                "long",
                "short",
            ].contains(action)
        let probability = opportunity.probabilityPercent ?? 0

        guard directional,
              !opportunity.isConsolidation,
              probability >= 70 else {
            return
        }

        let fingerprint = [
            opportunity.bias,
            opportunity.trend ?? "",
            opportunity.pressure ?? "",
            opportunity.setupQuality,
            opportunity.setupType,
            opportunity.action,
        ]
        .map { $0.lowercased() }
        .joined(separator: "|")

        ChaseTradeNotifications.deliver(
            key: "opportunity.\(opportunity.symbol.lowercased())",
            fingerprint: fingerprint,
            title: "\(opportunity.symbol) trade opportunity changed",
            body: opportunity.alertText,
            cooldown: 15 * 60
        )
    }
    private func loadPreTradeContext() async {
        preTradeLoading = true
        preTradeError = nil

        do {
            let request = PreTradeContextRequest(
                symbol: selectedSymbol.requestSymbol,
                broker: activeBrokerForWorkspace,
                accountKey: activeAccountKeyForWorkspace,
                useMatchTraderQuote: isMatchTraderBroker,
                matchTraderAccountID: activeAccountKeyForWorkspace,
                includeMatchTraderTimeframes: isMatchTraderBroker
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

    private var isMatchTraderBroker: Bool {
        let clean = (activeBrokerForWorkspace ?? "")
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        return clean.contains("aqua")
            || clean.contains("match trader")
            || clean.contains("matchtrader")
    }
    private func handleAlertResponse(_ option: String) {
        guard let trade = alertTargetTradeID.flatMap({ targetID in
            trades.first { $0.id == targetID && $0.isOpen }
        }) ?? filteredTrades.first else {
            errorMessage = "No active trade available."
            return
        }

        let lower = option.lowercased()

        if lower.contains("review protection") {
            activePrompt = .stopLoss(trade)
            return
        }

        if lower.contains("exit this position")
            || lower == "yes"
            || lower.contains("protect profit") {
            guard isAquaTrade(trade),
                  trade.externalPositionId != nil,
                  trade.brokerAccountId != nil
                    || trade.accountGroupKey != nil else {
                errorMessage = "This alert is not linked to an exact live Aqua position."
                return
            }
            pendingProfitProtectionTrade = trade
            return
        }

        if lower == "no" || lower.contains("keep position") {
            Task { await declineProfitProtection(for: trade) }
            return
        }

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

    private func isAquaTrade(_ trade: LoggedTradeResponse) -> Bool {
        let provider = (trade.platform ?? "").lowercased()
        return provider.contains("aqua") || provider.contains("match")
    }

    private func protectionClosePending(for trade: LoggedTradeResponse) -> Bool {
        guard let positionID = trade.externalPositionId else { return false }
        return pendingProtectionPositionIDs.contains(positionID)
    }

    private func profitProtectionMessage(for trade: LoggedTradeResponse) -> String {
        let current = estimatedOpenPnl(for: trade)
        let peak = estimatedPeakOpenPnl(for: trade)
        let giveback = peak.flatMap { peakValue -> Double? in
            guard peakValue > 0, let current else { return nil }
            return max(peakValue - current, 0)
        }
        let givebackPercent = giveback.flatMap { value -> Double? in
            guard let peak, peak > 0 else { return nil }
            return value / peak * 100
        }
        let impact = current.flatMap { value -> Double? in
            guard let size = trade.accountSize, size > 0 else { return nil }
            return value / size * 100
        }

        return [
            "\(trade.symbol) • \(trade.brokerAccountName ?? trade.brokerAccountId ?? "Aqua account")",
            "Peak profit: \(peak.map(formatMoney) ?? "Unavailable")",
            "Current profit: \(current.map(formatMoney) ?? "Unavailable")",
            "Giveback: \(giveback.map(formatMoney) ?? "Unavailable")\(givebackPercent.map { " (\(formatPercent($0)))" } ?? "")",
            "Account impact: \(impact.map(formatPercent) ?? "Unavailable")",
            "Exit only this broker position?",
        ].joined(separator: "\n")
    }

    @MainActor
    private func executeConfirmedProfitProtection(
        for trade: LoggedTradeResponse
    ) async {
        guard let positionID = trade.externalPositionId,
              let accountID = trade.brokerAccountId ?? trade.accountGroupKey,
              pendingProtectionPositionIDs.insert(positionID).inserted else {
            pendingProfitProtectionTrade = nil
            return
        }
        pendingProfitProtectionTrade = nil
        defer { pendingProtectionPositionIDs.remove(positionID) }

        do {
            let live = try await APIService.shared.fetchMatchTraderPositions(
                MatchTraderSyncRequest(
                    broker: "Aqua Funding",
                    accountId: accountID,
                    symbols: [trade.symbol]
                ),
                accessToken: accessToken,
                forceRefresh: true
            )
            let exactPosition = live.accounts?
                .first(where: { ($0.accountId ?? $0.tradingAccountId) == accountID })?
                .positions?
                .first(where: {
                    $0.positionId == positionID
                        && $0.symbol.caseInsensitiveCompare(trade.symbol) == .orderedSame
                })

            guard exactPosition != nil else {
                await loadDashboard(forceQuote: false)
                protectionResultMessage = "That exact \(trade.symbol) position is no longer open. Nothing was submitted."
                return
            }

            let response = try await APIService.shared.manageMatchTraderPosition(
                MatchTraderPositionManagementRequest(
                    broker: "Aqua Funding",
                    accountId: accountID,
                    positionId: positionID,
                    action: "close_position",
                    stopLoss: nil,
                    takeProfit: nil,
                    trailingDistance: nil,
                    volume: nil,
                    closePercent: nil,
                    userConfirmed: true
                ),
                accessToken: accessToken
            )
            guard response.success == true else {
                throw ProfitProtectionError.rejected(
                    response.message ?? response.warnings ?? "Aqua rejected the close."
                )
            }
            protectionResultMessage = response.message ?? "Aqua confirmed the close request for \(trade.symbol)."
            await loadDashboard(forceQuote: false)
        } catch {
            protectionResultMessage = "The position remains open. \(error.localizedDescription)"
            await loadDashboard(forceQuote: false)
        }
    }

    @MainActor
    private func declineProfitProtection(for trade: LoggedTradeResponse) async {
        pendingProfitProtectionTrade = nil
        let currentPrice = trade.currentPrice ?? currentQuote?.price
        guard let currentPrice else {
            protectionResultMessage = "Kept \(trade.symbol) open. No broker order was submitted."
            return
        }
        _ = try? await APIService.shared.updateBrokerPrice(
            tradeId: trade.id,
            currentPrice: currentPrice,
            notes: "Profit protection recommendation declined; position kept open.",
            accessToken: accessToken
        )
        protectionResultMessage = "Kept \(trade.symbol) open. No broker order was submitted."
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

    private func estimatedPeakOpenPnl(for trade: LoggedTradeResponse) -> Double? {
        guard let bestPrice = trade.bestPrice,
              let quantity = trade.quantity else { return nil }
        let move = trade.direction.lowercased() == "short"
            ? trade.entryPrice - bestPrice
            : bestPrice - trade.entryPrice
        return move * quantity * contractMultiplier(for: trade.symbol)
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

    private func formatVolume(_ value: Double) -> String {
        String(format: "%.4g", value)
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
