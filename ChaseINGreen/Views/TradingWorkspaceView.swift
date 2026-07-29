//
//  TradingWorkspaceView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import SwiftUI

struct TradingWorkspaceView: View {
    @StateObject private var viewModel = TradingWorkspaceViewModel()
    @State private var workspaceSymbol: WatchSymbol
    @State private var customSymbolText = ""

    private var customSymbolSuggestions: [WatchSymbol] {
        WatchSymbol.suggestions(
            matching: customSymbolText,
            limit: 6
        )
    }
    @State private var symbolInputError: String?
    @State private var selectedAquaAccountID: String?
    @State private var selectedAquaDirection: String?
    @State private var aquaInstruments: [MatchTraderInstrument] = []
    @State private var aquaContextActive = false
    @ObservedObject private var alertNavigation =
        TradeAlertNavigationStore.shared
    
    let accessToken: String
    let symbol: String
    let direction: String?
    let broker: String?
    let accountKey: String?
    let focusedPositionID: String?
    let followsTradeAlerts: Bool
    
    init(
        accessToken: String,
        symbol: String = "TQQQ",
        direction: String? = nil,
        broker: String? = nil,
        accountKey: String? = nil,
        focusedPositionID: String? = nil,
        followsTradeAlerts: Bool = false
    ) {
        self.accessToken = accessToken
        self.symbol = symbol.uppercased()
        self.direction = direction
        self.broker = broker
        self.accountKey = accountKey
        self.focusedPositionID = focusedPositionID
        self.followsTradeAlerts = followsTradeAlerts
        _selectedAquaAccountID = State(
            initialValue: accountKey
        )
        _selectedAquaDirection = State(
            initialValue: Self.normalizedDirectionValue(direction)
        )
        _workspaceSymbol = State(
            initialValue: Self.resolveSymbol(symbol)
        )
    }
    
    private var selectedSymbol: String {
        workspaceSymbol.tradeSymbol.uppercased()
    }
    
    private var selectedSymbolTrades: [LoggedTradeResponse] {
        viewModel.openTrades.filter {
            $0.symbol.uppercased() == selectedSymbol.uppercased()
        }
    }
    
    private var sortedOpenTrades: [LoggedTradeResponse] {
        selectedSymbolTrades + viewModel.openTrades.filter {
            $0.symbol.uppercased() != selectedSymbol.uppercased()
        }
    }
    
    private var selectedSymbolOpenPnl: Double {
        selectedSymbolTrades.compactMap { $0.netPnl ?? $0.openPnl }.reduce(0, +)
    }

    private var incomingAquaWorkspace: Bool {
        let context = (broker ?? "").lowercased()
        return context.contains("aqua")
            || context.contains("match trader")
            || context.contains("match-trader")
    }

    private var isAquaWorkspace: Bool {
        aquaContextActive || incomingAquaWorkspace
    }

    private var effectiveBroker: String? {
        isAquaWorkspace ? "Aqua Funding" : broker
    }

    private var effectiveAccountKey: String? {
        isAquaWorkspace ? selectedAquaAccountID : accountKey
    }

    private var effectiveDirection: String? {
        isAquaWorkspace ? selectedAquaDirection : direction
    }

    private var activeTradeAlert: TradeNotificationRoute? {
        followsTradeAlerts ? alertNavigation.activeRoute : nil
    }

    private var effectiveFocusedPositionID: String? {
        activeTradeAlert?.positionId ?? focusedPositionID
    }

    private var nonAquaBrokerAccounts: [BrokerAccountResponse] {
        viewModel.brokerAccounts.filter { account in
            let context = [
                account.broker,
                account.platform,
                account.propFirmName
            ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

            return !context.contains("aqua")
                && !context.contains("match trader")
                && !context.contains("match-trader")
        }
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        
                        BrokerDiagnosticsPanel(
                            accessToken: accessToken
                        ) {
                            await refreshWorkspaceAndAqua()
                        }
                        
                        brokerHealthPanel

                        BrokerManagementPanel(
                            selectedSymbol: selectedSymbol,
                            accessToken: accessToken
                        ) {
                            await refreshWorkspaceAndAqua()
                        }

                        AquaTradeActivityPanel(
                            connection: viewModel.aquaConnection,
                            positionsResponse: viewModel.aquaPositions,
                            brokerAccounts: viewModel.brokerAccounts,
                            selectedAccountID: selectedAquaAccountID,
                            selectedMarketSymbol: workspaceSymbol.tradeSymbol,
                            positionSize: viewModel.positionSize?.positionSize,
                            focusedPositionID: effectiveFocusedPositionID,
                            isLoading: viewModel.isLoadingAquaActivity,
                            errorMessage: viewModel.aquaActivityError,
                            protectionMessage: (
                                viewModel.aquaProtectionNotice
                            ),
                            accessToken: accessToken,
                            onRefresh: {
                                await refreshAquaOnly()
                            },
                            onLivePositionRefresh: {
                                await refreshLiveAquaPosition()
                            },
                            onClearBackendTrades: {
                                try await viewModel.clearAllBackendTrades(
                                    accessToken: accessToken
                                )
                            },
                            onMarketSymbolSelected: { symbol in
                                aquaContextActive = true
                                switchWorkspace(
                                    to: Self.resolveSymbol(symbol)
                                )
                            },
                            onInstrumentsChanged: { instruments in
                                aquaInstruments = instruments
                                if !instruments.isEmpty {
                                    aquaContextActive = true
                                }
                            },
                            onAccountSelected: { accountId in
                                aquaContextActive = true
                                selectedAquaAccountID = accountId

                                Task {
                                    await viewModel.loadAquaActivity(
                                        accessToken: accessToken,
                                        accountId: accountId
                                    )
                                    await loadWorkspace(force: true)
                                }
                            },
                            onPositionSelected: { symbol, accountId, side in
                                aquaContextActive = true
                                selectedAquaAccountID = accountId
                                selectedAquaDirection = normalizedDirection(side)
                                switchWorkspace(
                                    to: Self.resolveSymbol(symbol)
                                )
                            }
                        )

                        if viewModel.isLoading {
                            ProgressView("Loading Trader Workspace...")
                                .frame(maxWidth: .infinity, minHeight: 180)
                        } else if let errorMessage = viewModel.errorMessage {
                            errorCard(errorMessage)
                        } else {
                            cardDeck(isWide: proxy.size.width >= 760)
                        }
                    }
                    .padding()
                    .frame(maxWidth: proxy.size.width >= 760 ? 1180 : .infinity)
                    .frame(maxWidth: .infinity)
                }
                
                if let zoomedCard = viewModel.zoomedCard {
                    zoomOverlay(card: zoomedCard)
                }
            }
        }
        .task {
            await viewModel.loadAquaActivity(
                accessToken: accessToken,
                fetchPositions: true,
                accountId: effectiveAccountKey
            )
            adoptActiveAquaContextIfNeeded()
            await loadWorkspace(force: false)
        }
        .onChange(of: alertNavigation.activeRoute) {
            guard let route = activeTradeAlert else {
                return
            }

            Task {
                await followTradeAlert(route)
            }
        }
    }

    private func loadWorkspace(force: Bool) async {
        await viewModel.load(
            symbol: selectedSymbol,
            direction: effectiveDirection,
            broker: effectiveBroker,
            accountKey: effectiveAccountKey,
            useMatchTraderQuote: isAquaWorkspace,
            matchTraderAccountID: selectedAquaAccountID,
            accessToken: accessToken,
            force: force
        )
    }

    private func refreshWorkspaceAndAqua() async {
        await viewModel.loadAquaActivity(
            accessToken: accessToken,
            accountId: effectiveAccountKey,
            force: true
        )
        adoptActiveAquaContextIfNeeded()
        await loadWorkspace(force: true)
    }

    private func refreshAquaOnly() async {
        await viewModel.loadAquaActivity(
            accessToken: accessToken,
            accountId: effectiveAccountKey,
            force: true
        )
        adoptActiveAquaContextIfNeeded()
    }

    private func refreshLiveAquaPosition() async {
        await viewModel.loadAquaActivity(
            accessToken: accessToken,
            accountId: effectiveAccountKey,
            force: true,
            reconcileProtectionEvents: false
        )
    }

    @MainActor
    private func followTradeAlert(
        _ route: TradeNotificationRoute
    ) async {
        aquaContextActive = true
        selectedAquaAccountID = route.accountId
        selectedAquaDirection = normalizedDirection(route.side)

        let nextSymbol = Self.resolveSymbol(route.symbol)
        let symbolChanged = workspaceSymbol != nextSymbol
        workspaceSymbol = nextSymbol

        await viewModel.loadAquaActivity(
            accessToken: accessToken,
            accountId: route.accountId
        )

        if symbolChanged || viewModel.workspace == nil {
            await loadWorkspace(force: false)
        }
    }

    private func adoptActiveAquaContextIfNeeded() {
        guard incomingAquaWorkspace || aquaContextActive else {
            return
        }

        let availableAccounts = viewModel.aquaPositions?.accounts?.filter {
            $0.available == true
                && $0.effectivePositionCount > 0
        } ?? []

        guard !availableAccounts.isEmpty else {
            return
        }

        let account = availableAccounts.first(where: { candidate in
            guard let selectedAquaAccountID else {
                return false
            }

            return [
                candidate.accountId,
                candidate.tradingAccountId,
                candidate.accountUUID
            ]
            .compactMap { $0 }
            .contains(selectedAquaAccountID)
        }) ?? availableAccounts[0]

        aquaContextActive = true
        if selectedAquaAccountID == nil {
            selectedAquaAccountID = account.accountId
                ?? account.tradingAccountId
                ?? account.accountUUID
        }

        if let matching = account.positions?.first(where: {
            $0.symbol.caseInsensitiveCompare(selectedSymbol) == .orderedSame
        }) {
            selectedAquaDirection = normalizedDirection(matching.side)
        } else if let firstPosition = account.positions?.first {
            workspaceSymbol = Self.resolveSymbol(firstPosition.symbol)
            selectedAquaDirection = normalizedDirection(firstPosition.side)
        }
    }

    private func normalizedDirection(_ value: String?) -> String? {
        Self.normalizedDirectionValue(value)
    }

    private static func normalizedDirectionValue(
        _ value: String?
    ) -> String? {
        let clean = (value ?? "").lowercased()
        if clean.contains("buy") || clean.contains("long") { return "long" }
        if clean.contains("sell") || clean.contains("short") { return "short" }
        return nil
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bat Cave")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.primaryText)
            
            HStack(spacing: 10) {
                Label(workspaceSymbol.displayName, systemImage: "scope")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.softGold)
                
                if let effectiveDirection {
                    pill(effectiveDirection.uppercased(), tint: AppTheme.primaryText)
                }

                if let effectiveBroker {
                    pill(effectiveBroker, tint: AppTheme.secondaryText)
                }
            }
            
            Text(viewModel.workspace?.effectiveSummary ?? "Trader OS command center for AI, broker quote source, timeframes, open trades, accounts, calendar, ML insights, journal, and stats.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)

            workspaceSymbolPicker
        }
    }

    private var workspaceSymbolPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Switch Market")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.secondaryText)

            if isAquaWorkspace {
                Label(
                    "Aqua instruments are account-specific",
                    systemImage: "checkmark.shield.fill"
                )
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)

                Text(
                    "Switch among the instruments returned by the selected Aqua account. Account changes remain available in Aqua Trader."
                )
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)

                if aquaInstruments.isEmpty {
                    ProgressView("Loading this account's instruments...")
                        .font(.caption)
                } else {
                    aquaInstrumentStrip
                }
            } else {
                ScrollViewReader { reader in
                    HStack(spacing: 8) {
                        marketStepButton(
                            systemImage: "chevron.left",
                            offset: -1,
                            items: WatchSymbol.presets,
                            reader: reader
                        )

                        ScrollView(.horizontal, showsIndicators: true) {
                            HStack(spacing: 8) {
                                ForEach(WatchSymbol.presets) { item in
                                    Button {
                                        switchWorkspace(to: item)
                                    } label: {
                                        Text(item.displayName)
                                            .font(.caption.bold())
                                            .foregroundStyle(
                                                workspaceSymbol == item
                                                    ? AppTheme.deepBlack
                                                    : AppTheme.primaryText
                                            )
                                            .padding(.horizontal, 11)
                                            .padding(.vertical, 8)
                                            .background(
                                                workspaceSymbol == item
                                                    ? AppTheme.softGold
                                                    : Color.secondary.opacity(0.08)
                                            )
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .id(item.id)
                                }
                            }
                        }

                        marketStepButton(
                            systemImage: "chevron.right",
                            offset: 1,
                            items: WatchSymbol.presets,
                            reader: reader
                        )
                    }
                }

                HStack(spacing: 8) {
                    TextField("Any ticker", text: $customSymbolText)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 11)
                        .padding(.vertical, 9)
                        .background(Color.secondary.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 11))

                    Button("Load") {
                        guard let custom = WatchSymbol.resolve(customSymbolText) else {
                            symbolInputError = "Enter a real ticker like AAPL, BTC, Gold, or Silver."
                            return
                        }
                        symbolInputError = nil
                        switchWorkspace(to: custom)
                        customSymbolText = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.softGold)
                    .disabled(
                        customSymbolText
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    )
                }

                if !customSymbolSuggestions.isEmpty {
                    workspaceSuggestionStrip(customSymbolSuggestions)
                }

                if let symbolInputError {
                    Text(symbolInputError)
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
            }

            Text("Changing the ticker reloads Trader OS, timeframes, prediction context, and risk sizing without leaving the Bat Cave.")
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.top, 4)
    }

    private func marketStepButton(
        systemImage: String,
        offset: Int,
        items: [WatchSymbol],
        reader: ScrollViewProxy
    ) -> some View {
        Button {
            guard !items.isEmpty else {
                return
            }

            let currentIndex = items.firstIndex(of: workspaceSymbol) ?? 0
            let nextIndex = min(
                max(currentIndex + offset, 0),
                items.count - 1
            )
            let next = items[nextIndex]

            switchWorkspace(to: next)
            withAnimation {
                reader.scrollTo(next.id, anchor: .center)
            }
        } label: {
            Image(systemName: systemImage)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppTheme.softGold)
        .foregroundStyle(AppTheme.deepBlack)
    }

    private var aquaInstrumentStrip: some View {
        ScrollViewReader { reader in
            HStack(spacing: 8) {
                Button {
                    guard let currentIndex = aquaInstruments.firstIndex(
                        where: {
                            $0.symbol.caseInsensitiveCompare(selectedSymbol)
                                == .orderedSame
                        }
                    ), currentIndex > aquaInstruments.startIndex else {
                        return
                    }

                    let previous = aquaInstruments[
                        aquaInstruments.index(before: currentIndex)
                    ]
                    switchWorkspace(to: Self.resolveSymbol(previous.symbol))
                    withAnimation {
                        reader.scrollTo(previous.symbol, anchor: .center)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.softGold)
                .foregroundStyle(AppTheme.deepBlack)

                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 8) {
                        ForEach(aquaInstruments) { instrument in
                            Button {
                                switchWorkspace(
                                    to: Self.resolveSymbol(instrument.symbol)
                                )
                            } label: {
                                Text(instrument.symbol.uppercased())
                                    .font(.caption.bold())
                                    .foregroundStyle(
                                        instrument.symbol.caseInsensitiveCompare(
                                            selectedSymbol
                                        ) == .orderedSame
                                            ? AppTheme.deepBlack
                                            : AppTheme.primaryText
                                    )
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 8)
                                    .background(
                                        instrument.symbol.caseInsensitiveCompare(
                                            selectedSymbol
                                        ) == .orderedSame
                                            ? AppTheme.softGold
                                            : Color.secondary.opacity(0.08)
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .id(instrument.symbol)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Button {
                    guard let currentIndex = aquaInstruments.firstIndex(
                        where: {
                            $0.symbol.caseInsensitiveCompare(selectedSymbol)
                                == .orderedSame
                        }
                    ) else {
                        return
                    }

                    let nextIndex = aquaInstruments.index(after: currentIndex)
                    guard nextIndex < aquaInstruments.endIndex else {
                        return
                    }

                    let next = aquaInstruments[nextIndex]
                    switchWorkspace(to: Self.resolveSymbol(next.symbol))
                    withAnimation {
                        reader.scrollTo(next.symbol, anchor: .center)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.softGold)
                .foregroundStyle(AppTheme.deepBlack)
            }
        }
    }

    private func workspaceSuggestionStrip(
        _ items: [WatchSymbol]
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    Button {
                        symbolInputError = nil
                        customSymbolText = ""
                        switchWorkspace(to: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayName)
                                .font(.caption.bold())

                            Text(item.requestSymbol)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .foregroundStyle(AppTheme.softGold)
                        .background(AppTheme.softGold.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func switchWorkspace(
        to item: WatchSymbol
    ) {
        workspaceSymbol = item

        Task {
            await loadWorkspace(force: true)
        }
    }

    private static func resolveSymbol(
        _ raw: String
    ) -> WatchSymbol {
        WatchSymbol.resolve(raw) ?? WatchSymbol.custom(raw)
    }

    private var brokerHealthPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Broker Health", systemImage: "heart.text.square.fill")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.softGold)

                Spacer()

                Text("\(viewModel.brokerHealth?.healthyConnections ?? 0)/\(viewModel.brokerHealth?.connectionCount ?? 0) healthy")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.secondaryText)
            }

            if let companies = viewModel.brokerHealth?.companies, !companies.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(companies.keys.sorted(), id: \.self) { key in
                            if let company = companies[key] {
                                brokerHealthTile(
                                    brokerKey: key,
                                    health: company
                                )
                            }
                        }
                    }
                }
            } else {
                Text("No broker connection health loaded yet. Sync a broker to start showing live account status.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        }
    }

    private func brokerHealthTile(
        brokerKey: String,
        health: BrokerCompanyHealth
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Circle()
                    .fill(healthColor(health.status))
                    .frame(width: 9, height: 9)

                Text(displayBrokerName(brokerKey))
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
            }

            Text((health.status ?? "unknown").uppercased())
                .font(.caption2.bold())
                .foregroundStyle(healthColor(health.status))

            Text("\(health.connected ?? 0)/\(health.total ?? 0) connections")
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding()
        .frame(width: 150, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func healthColor(_ status: String?) -> Color {
        switch (status ?? "").lowercased() {
        case "healthy", "connected", "synced", "active":
            return .green
        case "partial", "warning", "degraded":
            return .yellow
        case "offline", "error", "failed", "disconnected":
            return .red
        default:
            return .gray
        }
    }

    private func displayBrokerName(_ value: String) -> String {
        switch value.lowercased() {
        case "aqua_funded":
            return "Aqua"
        case "trade_the_pool":
            return "TTP"
        case "match_trader":
            return "Match-Trader"
        case "ibkr":
            return "IBKR"
        case "crypto_com":
            return "Crypto.com"
        case "trade_station":
            return "TradeStation"
        default:
            return value
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }
    
    private func cardDeck(isWide: Bool) -> some View {
        Group {
            if isWide {
                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(minimum: 340, maximum: 520),
                            spacing: 16,
                            alignment: .top
                        )
                    ],
                    alignment: .leading,
                    spacing: 16
                ) {
                    ForEach(TradingWorkspaceCard.allCases) { card in
                        workspaceCard(card)
                            .frame(minHeight: 330, alignment: .top)
                    }
                }
            } else {
                VStack(spacing: 14) {
                    ForEach(TradingWorkspaceCard.allCases) { card in
                        workspaceCard(card)
                    }
                }
            }
        }
    }
    
    private func workspaceCard(_ card: TradingWorkspaceCard) -> some View {
        Button {
            viewModel.zoom(card)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(card.title, systemImage: card.systemImage)
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.softGold)
                    
                    Spacer()
                    
                    Text(selectedSymbol)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.secondaryText)
                }
                
                Divider()
                
                cardContent(card)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                tapHint
            }
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var tapHint: some View {
        Text("Tap for details")
            .font(.caption2.bold())
            .foregroundStyle(AppTheme.softGold)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    @ViewBuilder
    private func cardContent(_ card: TradingWorkspaceCard) -> some View {
        switch card {
        case .traderOS:
            TraderOSWorkspaceCard(traderOS: viewModel.traderOS, selectedSymbol: selectedSymbol)

        case .positionSize:
            PositionSizeWorkspaceCard(positionSize: viewModel.positionSize, selectedSymbol: selectedSymbol)

        case .quoteSource:
            QuoteSourceWorkspaceCard(quote: viewModel.traderOS?.quoteResolution, selectedSymbol: selectedSymbol)

        case .timeframes:
            TimeframesWorkspaceCard(multiTimeframe: viewModel.traderOS?.multiTimeframe, selectedSymbol: selectedSymbol)
            
        case .liveMonitor:
            VStack(alignment: .leading, spacing: 8) {
                Text("Trade Doctor")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.primaryText)
                
                if selectedSymbolTrades.isEmpty {
                    Text("No tracked open trade for \(selectedSymbol).")
                    Text("Pre-trade context only until broker sync confirms a live position.")
                } else {
                    detailGrid([
                        ("Symbol Trades", "\(selectedSymbolTrades.count)"),
                        ("Symbol P/L", formatMoney(selectedSymbolOpenPnl)),
                        ("All Open", "\(viewModel.openTrades.count)")
                    ])
                    
                    ForEach(Array(selectedSymbolTrades.prefix(4)), id: \.id) { trade in
                        tradeRow(trade)
                    }
                }
            }
            
        case .openTrades:
            VStack(alignment: .leading, spacing: 8) {
                detailGrid([
                    ("Tracked Open", "\(viewModel.openTrades.count)"),
                    ("\(selectedSymbol)", "\(selectedSymbolTrades.count)"),
                    ("Symbol P/L", formatMoney(selectedSymbolOpenPnl))
                ])
                
                if selectedSymbolTrades.isEmpty {
                    Text("No open \(selectedSymbol) trade found.")
                        .foregroundStyle(AppTheme.softGold)
                }
                
                ForEach(Array(sortedOpenTrades.prefix(6)), id: \.id) { trade in
                    tradeRow(trade)
                }
            }
            
        case .calendar:
            if let calendar = viewModel.calendar {
                detailGrid([
                    ("Days", "\(calendar.summary.totalDays)"),
                    ("Green", "\(calendar.summary.greenDays)"),
                    ("Red", "\(calendar.summary.redDays)"),
                    ("Win Rate", "\(Int(calendar.summary.winRate.rounded()))%")
                ])
            } else {
                Text("Calendar not loaded yet.")
            }
            
        case .brokerAccounts:
            VStack(alignment: .leading, spacing: 10) {
                let selectedAccount = selectedBrokerAccount()
                let selectedPreset = selectedAccount.flatMap {
                    BrokerPreset.from($0.broker) ?? BrokerPreset.from($0.platform)
                }

                detailGrid([
                    ("Accounts", "\(nonAquaBrokerAccounts.count)"),
                    ("Current", selectedPreset?.displayName ?? selectedAccount?.broker ?? broker ?? "Auto"),
                    ("Type", accountTypeLabel(for: selectedAccount))
                ])

                if nonAquaBrokerAccounts.isEmpty {
                    Text("No non-Aqua broker accounts loaded. Aqua accounts stay inside Aqua Live Activity.")
                        .foregroundStyle(AppTheme.softGold)
                }

                ForEach(Array(nonAquaBrokerAccounts.prefix(5)), id: \.id) { account in
                    accountRow(account)
                }
            }
            
        case .stats:
            if let stats = viewModel.tradeStats {
                let netPnl = stats.totalNetPnl ?? stats.totalRealizedPnl
                
                detailGrid([
                    ("Closed", "\(stats.totalClosedTrades)"),
                    ("Win Rate", formatPercent(stats.winRate)),
                    ("Net P/L", formatMoney(netPnl)),
                    ("Open P/L", formatMoney(stats.totalOpenPnl))
                ])
            } else {
                Text("Stats not loaded yet.")
            }
            
        case .journal:
            VStack(alignment: .leading, spacing: 8) {
                Text("Journal intelligence feeds Trader OS, calendar, memory, profile, coaching, and ML insights.")
                    .lineLimit(4)
                
                detailGrid([
                    ("Behavior", "Tracked"),
                    ("Coaching", "Connected"),
                    ("Memory", "Learning")
                ])
            }
            
        case .mlInsights:
            MLInsightsCard(
                memory: viewModel.mlInsights?.memory,
                patterns: viewModel.mlInsights?.patterns,
                profile: viewModel.mlInsights?.profile,
                calendar: viewModel.mlInsights?.calendar,
                message: viewModel.mlInsights?.message
            )
        }
    }

    private func tradeRow(_ trade: LoggedTradeResponse) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(trade.symbol.uppercased())
                    .font(.headline.bold())
                    .foregroundStyle(trade.symbol.uppercased() == selectedSymbol ? AppTheme.softGold : AppTheme.primaryText)

                Spacer()

                if let pnl = trade.netPnl ?? trade.openPnl {
                    Text(formatMoney(pnl))
                        .font(.caption.bold())
                        .foregroundStyle(pnl >= 0 ? .green : .red)
                }
            }

            HStack(spacing: 14) {
                detailMini(title: "Entry", value: formatPrice(trade.entryPrice))
                detailMini(title: "Current", value: formatPrice(trade.currentPrice))
                detailMini(title: "Qty", value: trade.quantity == nil ? "--" : String(format: "%.2f", trade.quantity!))
            }

            if let broker = trade.platform {
                Text("Broker: \(broker)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Text("Future: tap trade → manage, partial close, notes, screenshots, AI review.")
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.vertical,4)
    }

    private func accountRow(_ account: BrokerAccountResponse) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(account.accountName ?? account.accountId)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                Text(BrokerPreset.from(account.broker)?.displayName ?? account.broker)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.softGold)
            }

            HStack(spacing:16) {
                detailMini(title: "Equity", value: formatMoney(account.equity ?? account.balance))
                detailMini(title: "Daily DD", value: formatMoney(account.dailyDrawdownRemaining))
                detailMini(title: "Max DD", value: formatMoney(account.maxDrawdownRemaining))
            }
        }
        .padding(.vertical,4)
    }

    private func detailGrid(_ rows:[(String,String)]) -> some View {
        VStack(alignment:.leading, spacing:8) {
            ForEach(rows.indices,id:\.self) { index in
                HStack {
                    Text(rows[index].0)
                        .foregroundStyle(AppTheme.secondaryText)

                    Spacer()

                    Text(rows[index].1)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
        }
    }

    private func detailMini(title:String,value:String) -> some View {
        VStack(alignment:.leading,spacing:2){
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)

            Text(value)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.primaryText)
        }
    }

    private func pill(_ text:String,tint:Color)->some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(tint)
            .padding(.horizontal,10)
            .padding(.vertical,5)
            .background(AppTheme.cardBackground)
            .clipShape(Capsule())
    }

    private func timeframeIcon(_ value:String?) -> String {
        let clean = (value ?? "").lowercased()

        if clean.contains("bull") || clean.contains("up") || clean.contains("long") { return "🟢" }
        if clean.contains("bear") || clean.contains("down") || clean.contains("short") { return "🔴" }
        if clean.contains("wait") || clean.contains("mixed") || clean.contains("chop") { return "🟡" }

        return "⚪️"
    }

    private func selectedBrokerAccount() -> BrokerAccountResponse? {
        nonAquaBrokerAccounts.first { account in
            if let accountKey {
                return account.accountId.lowercased() == accountKey.lowercased()
                || account.accountName?.lowercased() == accountKey.lowercased()
            }

            if let broker {
                return account.broker.lowercased() == broker.lowercased()
                || account.platform?.lowercased() == broker.lowercased()
            }

            return false
        }
    }

    private func accountTypeLabel(for account: BrokerAccountResponse?) -> String {
        guard let account else { return "Auto Detect" }

        let preset = BrokerPreset.from(account.broker) ?? BrokerPreset.from(account.platform)

        if preset?.isPropFirm == true { return "Prop Firm" }
        if preset?.isCryptoExchange == true { return "Crypto Exchange" }

        return "Brokerage"
    }

    private func zoomOverlay(card: TradingWorkspaceCard) -> some View {
        ZStack {
            Color.black.opacity(0.60)
                .ignoresSafeArea()

            VStack(alignment:.leading,spacing:18){
                HStack{
                    Label(card.title, systemImage: card.systemImage)
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.softGold)

                    Spacer()

                    Button {
                        viewModel.closeZoom()
                    } label: {
                        Image(systemName:"xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.gold)
                    }
                }

                Text("Workspace Details")
                    .font(.headline)
                    .foregroundStyle(AppTheme.primaryText)

                Text("""
This screen is becoming the central Bat Cave for every trading decision.

Eventually every card will open its own screen:

• Trader OS
• Broker Accounts
• Calendar
• Journal
• Statistics
• Open Trades
• Live Trade Monitor
• ML Insights
• Quote Source
• Timeframes

Everything will drill into deeper analytics instead of static cards.
""")
                .foregroundStyle(AppTheme.secondaryText)

                Divider()

                ScrollView{
                    cardContent(card)
                        .frame(maxWidth:.infinity, alignment:.leading)
                }
            }
            .padding()
            .frame(maxWidth:760, maxHeight:700)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius:24))
            .padding()
        }
    }

    private func errorCard(_ message:String)->some View{
        VStack(alignment:.leading,spacing:8){
            Text("Workspace Error")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.softGold)

            Text(message)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius:18))
    }

    private func formatPrice(_ value:Double?)->String{
        guard let value else { return "--" }
        return String(format:"%.2f",value)
    }

    private func formatPercent(_ value:Double?)->String{
        guard let value else { return "--" }
        return String(format:"%.1f%%",value)
    }

    private func formatMoney(_ value:Double?)->String{
        guard let value else { return "--" }
        return String(format:"%@%.2f", value >= 0 ? "+$" : "-$", abs(value))
    }
}
