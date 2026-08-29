//
//  TradingWorkspaceView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import SwiftUI

struct TradingWorkspaceView: View {
    private enum AuthorizationState {
        case loading
        case allowed
        case denied
    }

    @StateObject private var viewModel = TradingWorkspaceViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var authorizationState: AuthorizationState = .loading
    @State private var authorizationRequestID = UUID()
    @State private var workspaceSymbol: WatchSymbol
    @State private var customSymbolText = ""
    @FocusState private var isCustomSymbolFocused: Bool
    @State private var krakenInstruments: [KrakenInstrument] = []
    @State private var isKrakenTraderExpanded = false

    private var customSymbolSuggestions: [WatchSymbol] {
        if isKrakenContext {
            let query = customSymbolText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            guard !query.isEmpty else { return [] }
            let krakenMatches = krakenInstruments
                .filter {
                    $0.canonicalSymbol.localizedCaseInsensitiveContains(query)
                        || $0.displaySymbol.localizedCaseInsensitiveContains(query)
                        || $0.alternateSymbol.localizedCaseInsensitiveContains(query)
                        || $0.base.localizedCaseInsensitiveContains(query)
                }
                .map {
                    WatchSymbol(
                        requestSymbol: $0.canonicalSymbol,
                        displayName: $0.displaySymbol,
                        tradeSymbol: $0.canonicalSymbol,
                        systemImage: "bitcoinsign.circle.fill",
                        isCustom: true
                    )
                }
            let publicMatches = WatchSymbol.suggestions(
                matching: customSymbolText,
                limit: 6
            )
            var seen = Set<String>()
            return (krakenMatches + publicMatches)
                .filter {
                    seen.insert(WatchSymbol.comparisonKey($0.requestSymbol)).inserted
                }
                .prefix(8)
                .map { $0 }
        }
        return WatchSymbol.suggestions(
            matching: customSymbolText,
            limit: 6
        )
    }

    private var isKrakenContext: Bool {
        (selectedAccountProvider ?? "").lowercased().contains("kraken")
    }
    @State private var symbolInputError: String?
    @State private var selectedAquaAccountID: String?
    @State private var selectedAquaDirection: String?
    @State private var aquaInstruments: [MatchTraderInstrument] = []
    @State private var aquaContextActive = false
    @State private var selectedAccountProvider: String?
    @State private var selectedAccountContextID: String?
    @State private var selectedAccountDisplayName: String?
    @State private var selectedFocusedPositionID: String?
    @State private var workspaceLoadTask: Task<Void, Never>?
    @State private var journals: [TradeJournalResponse] = []
    @State private var journalError: String?
    @State private var selectedJournal: TradeJournalResponse?
    @State private var journalNotes = ""
    @State private var isSavingJournal = false
    @State private var activeTradePrompt: TradeActionPrompt?
    @ObservedObject private var alertNavigation =
        TradeAlertNavigationStore.shared

    private let versionOneCards: [TradingWorkspaceCard] = [
        .traderOS,
        .quoteSource,
        .timeframes,
        .openTrades,
        .journal,
    ]
    
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
        _selectedAccountProvider = State(initialValue: broker)
        _selectedAccountContextID = State(initialValue: accountKey)
        _selectedFocusedPositionID = State(initialValue: focusedPositionID)
        _workspaceSymbol = State(
            initialValue: Self.resolveSymbol(symbol)
        )
    }
    
    private var selectedSymbol: String {
        workspaceSymbol.tradeSymbol.uppercased()
    }
    
    private var selectedSymbolTrades: [LoggedTradeResponse] {
        selectedContextTrades.filter {
            WatchSymbol.comparisonKey($0.symbol)
                == WatchSymbol.comparisonKey(selectedSymbol)
        }
    }

    private var selectedContextTrades: [LoggedTradeResponse] {
        guard let provider = selectedAccountProvider?
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !provider.isEmpty else {
            return viewModel.openTrades
        }

        let providerIdentity = normalizedProviderIdentity(provider)
        return viewModel.openTrades.filter { trade in
            let tradeProvider = normalizedProviderIdentity(trade.providerKey)
            let providerMatches = tradeProvider == providerIdentity
                || (providerIdentity == "aqua" && tradeProvider == "matchtrader")
                || (providerIdentity == "matchtrader" && tradeProvider == "aqua")
            let accountMatches = selectedAccountContextID == nil
                || trade.connectionId == selectedAccountContextID
                || trade.brokerAccountId == selectedAccountContextID
                || trade.canonicalAccountId == selectedAccountContextID
                || trade.accountGroupKey == selectedAccountContextID
            return providerMatches && accountMatches
        }
    }

    private func normalizedProviderIdentity(_ value: String) -> String {
        let compact = value.lowercased().filter(\.isLetter)
        if compact.contains("kraken") { return "kraken" }
        if compact.contains("aqua") { return "aqua" }
        if compact.contains("matchtrader") { return "matchtrader" }
        if compact.contains("interactivebrokers") || compact == "ibkr" {
            return "ibkr"
        }
        return compact
    }
    
    private var sortedOpenTrades: [LoggedTradeResponse] {
        selectedSymbolTrades + selectedContextTrades.filter {
            WatchSymbol.comparisonKey($0.symbol)
                != WatchSymbol.comparisonKey(selectedSymbol)
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
        aquaContextActive
            || isAquaProvider(selectedAccountProvider)
    }

    private var effectiveBroker: String? {
        selectedAccountProvider
            ?? (isAquaWorkspace && selectedAquaAccountID != nil
                ? "Aqua Funding"
                : broker)
    }

    private var effectiveAccountKey: String? {
        selectedAccountContextID
            ?? (isAquaWorkspace ? selectedAquaAccountID : accountKey)
    }

    private var effectiveDirection: String? {
        isAquaWorkspace ? selectedAquaDirection : direction
    }

    private var activeTradeAlert: TradeNotificationRoute? {
        followsTradeAlerts ? alertNavigation.activeRoute : nil
    }

    private var effectiveFocusedPositionID: String? {
        activeTradeAlert?.positionId ?? selectedFocusedPositionID
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

    private var selectableBrokerAccounts: [BrokerAccountResponse] {
        viewModel.brokerAccounts.filter {
            $0.isActive
                && $0.normalizedParticipationState == "active"
                && !isTerminalAccountStatus($0.accountStatus)
        }
    }

    private var selectedInstrumentIsAquaTradable: Bool {
        guard isAquaWorkspace, selectedAquaAccountID != nil else {
            return false
        }
        return aquaInstruments.contains {
            $0.symbol.caseInsensitiveCompare(selectedSymbol) == .orderedSame
        }
    }

    private var selectedContextBrokerAccount: BrokerAccountResponse? {
        guard let selectedAccountContextID else { return nil }
        return viewModel.brokerAccounts.first {
            $0.accountId == selectedAccountContextID
        }
    }

    private var selectedProviderPositionSymbols: [WatchSymbol] {
        guard let selectedAccountProvider, !isAquaWorkspace else { return [] }
        let provider = selectedAccountProvider.lowercased()
        var seen = Set<String>()
        return viewModel.openTrades.compactMap { trade in
            let tradeProvider = (trade.platform ?? "").lowercased()
            let accountMatches = selectedAccountContextID == nil
                || trade.brokerAccountId == selectedAccountContextID
                || trade.accountGroupKey == selectedAccountContextID
            let providerMatches = !tradeProvider.isEmpty && (
                tradeProvider.contains(provider)
                || provider.contains(tradeProvider)
                || (provider.contains("ibkr")
                    && tradeProvider.contains("interactive broker"))
            )
            guard accountMatches,
                  providerMatches,
                  let symbol = WatchSymbol.resolve(trade.symbol),
                  seen.insert(symbol.requestSymbol).inserted else {
                return nil
            }
            return symbol
        }
    }

    private var workspaceErrorForDisplay: String? {
        guard let workspaceError = viewModel.errorMessage else {
            return nil
        }

        let normalizedWorkspaceError = workspaceError
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedAquaError = viewModel.aquaActivityError?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // The Aqua panel already presents this retryable failure. Avoid a
        // second identical card immediately below it.
        return normalizedWorkspaceError == normalizedAquaError
            ? nil
            : workspaceError
    }
    
    var body: some View {
        Group {
            switch authorizationState {
            case .loading:
                AppBackground {
                    ProgressView("Verifying internal access...")
                        .tint(AppTheme.gold)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            case .allowed:
                authorizedWorkspace
            case .denied:
                AppBackground {
                    AppUnavailableView(
                        title: "Internal Workspace",
                        systemImage: "lock.shield",
                        message: "This workspace is available only to authorized internal testers."
                    )
                    .padding()
                }
            }
        }
        .task {
            print(
                "[Navigation] from=trade-home to=trader-workspace "
                + "reason=user-or-authorized-route"
            )
            await verifyInternalAccess(showLoading: true)
        }
    }

    private var authorizedWorkspace: some View {
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
                            accessToken: accessToken,
                            focusedProvider: selectedAccountProvider,
                            focusedAccountID: selectedAccountContextID,
                            onProviderSelected: { provider in
                                selectManagedProvider(provider)
                            },
                            onAccountSelected: { provider, accountID, displayName in
                                selectManagedAccount(
                                    provider: provider,
                                    accountID: accountID,
                                    displayName: displayName
                                )
                            },
                            onConnectionDisconnected: { provider, connectionID in
                                reconcileDisconnectedConnection(
                                    provider: provider,
                                    connectionID: connectionID
                                )
                            }
                        ) {
                            await refreshWorkspaceAndAqua()
                        }

                        AquaTradeActivityPanel(
                            connection: viewModel.aquaConnection,
                            accountRosterResponse: viewModel.aquaAccountRoster,
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
                                // Deselecting an Aqua account returns to the
                                // Aqua roster; it must not resurrect the
                                // provider from the original navigation route.
                                selectedAccountProvider = "Aqua Funding"
                                selectedAccountContextID = accountId
                                selectedAccountDisplayName = accountId
                                selectedAquaDirection = nil
                                aquaInstruments = []

                                guard let accountId else {
                                    viewModel.clearSelectedAquaActivity()
                                    return
                                }

                                Task {
                                    await viewModel.loadAquaActivity(
                                        accessToken: accessToken,
                                        accountId: accountId
                                    )
                                    await loadWorkspace(force: false)
                                }
                            },
                            onPositionSelected: { symbol, accountId, side, positionId in
                                aquaContextActive = true
                                selectedAquaAccountID = accountId
                                selectedAccountProvider = "Aqua Funding"
                                selectedAccountContextID = accountId
                                selectedAccountDisplayName = accountId
                                selectedAquaDirection = normalizedDirection(side)
                                selectedFocusedPositionID = positionId
                                switchWorkspace(
                                    to: Self.resolveSymbol(symbol)
                                )
                            }
                        )

                        if viewModel.isLoading,
                           !viewModel.openTrades.isEmpty {
                            OpenPositionsPanel(
                                trades: viewModel.openTrades,
                                marks: viewModel.portfolioMarks
                            )
                        }

                        if viewModel.isLoading {
                            ProgressView("Loading Trader Workspace...")
                                .frame(maxWidth: .infinity, minHeight: 180)
                        } else if let errorMessage = workspaceErrorForDisplay {
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
            print("[RefreshOwner] owner=workspace trigger=navigation")
            // Trader OS owns workspace startup. Aqua must never gate the
            // initial Bat Cave render.
            async let workspaceLoad: Void = loadWorkspace(force: false)

            // Aqua health is lightweight and provides saved connection/account
            // metadata without triggering the expensive all-account positions
            // scan.
            async let aquaHealthLoad: Void = viewModel.loadAquaActivity(
                accessToken: accessToken,
                fetchPositions: false,
                accountId: nil
            )

            // Only fetch live Aqua positions automatically when navigation
            // explicitly targets a particular Aqua account.
            if incomingAquaWorkspace,
               let selectedAquaAccountID {
                async let selectedLoad: Void = viewModel.loadAquaActivity(
                    accessToken: accessToken,
                    fetchPositions: true,
                    accountId: selectedAquaAccountID,
                    reconcileProtectionEvents: false
                )
                _ = await (
                    workspaceLoad,
                    aquaHealthLoad,
                    selectedLoad
                )
            } else {
                _ = await (workspaceLoad, aquaHealthLoad)
            }

            await loadJournals()
        }
        .onChange(of: alertNavigation.activeRoute) {
            guard let route = activeTradeAlert else {
                return
            }

            Task {
                await followTradeAlert(route)
            }
        }
        .sheet(item: $selectedJournal) { journal in
            journalEditor(journal)
        }
        .sheet(item: $activeTradePrompt) { prompt in
            TradeActionSheet(
                prompt: prompt,
                currentQuotePrice: viewModel.portfolioMarks[prompt.trade.id]?.currentPrice
                    ?? prompt.trade.currentPrice,
                accessToken: accessToken,
                onComplete: {
                    await loadWorkspace(force: true)
                }
            )
        }
    }

    @MainActor
    private func verifyInternalAccess(showLoading: Bool) async {
        let requestID = UUID()
        authorizationRequestID = requestID
        var wasAlreadyAllowed: Bool = {
            if case .allowed = authorizationState {
                return true
            }
            return false
        }()
        if let cached = AppRefreshCoordinator.shared.cachedProfile(
            accessToken: accessToken
        ), InternalWorkspaceRoutePolicy.permits(
            .deepLink,
            authorization: cached.internalWorkspaceAuthorization
        ) {
            authorizationState = .allowed
            wasAlreadyAllowed = true
        }
        if showLoading && !wasAlreadyAllowed {
            authorizationState = .loading
        }
        do {
            let user: APIService.CurrentUserResponse
            if let fresh = AppRefreshCoordinator.shared.freshCachedProfile(
                accessToken: accessToken
            ) {
                user = fresh
                print("[RefreshCoordinator] event=workspace-profile action=used-fresh-cache")
            } else {
                user = try await AppRefreshCoordinator.shared.revalidateProfile(
                    accessToken: accessToken,
                    trigger: "workspace-authorization"
                )
            }
            guard authorizationRequestID == requestID else { return }
            let isAllowed = InternalWorkspaceRoutePolicy.permits(
                .deepLink,
                authorization: user.internalWorkspaceAuthorization
            )
            authorizationState = isAllowed ? .allowed : .denied
            if !isAllowed {
                dismiss()
            }
        } catch {
            guard authorizationRequestID == requestID else { return }
            let nsError = error as NSError
            let isAuthoritativeDenial =
                nsError.domain == "APIService"
                && (nsError.code == 401 || nsError.code == 403)

            if isAuthoritativeDenial || !wasAlreadyAllowed {
                authorizationState = .denied
                dismiss()
            }
        }
    }

    @MainActor
    private func loadJournals() async {
        do {
            journals = try await APIService.shared
                .fetchTradeJournals(accessToken: accessToken)
            journalError = nil
        } catch {
            journalError = error.localizedDescription
        }
    }

    private func loadWorkspace(force: Bool) async {
        await viewModel.load(
            symbol: selectedSymbol,
            direction: effectiveDirection,
            broker: effectiveBroker,
            accountKey: effectiveAccountKey,
            useMatchTraderQuote: selectedInstrumentIsAquaTradable,
            matchTraderAccountID: selectedAquaAccountID,
            startingBalance: selectedContextBrokerAccount?.startingBalance,
            currentBalance: selectedContextBrokerAccount?.equity
                ?? selectedContextBrokerAccount?.balance,
            accessToken: accessToken,
            force: force
        )
    }

    private func refreshWorkspaceAndAqua() async {
        await viewModel.loadAquaActivity(
            accessToken: accessToken,
            fetchPositions: false,
            accountId: nil,
            force: true
        )

        if let selectedAquaAccountID {
            async let selectedLoad: Void = viewModel.loadAquaActivity(
                accessToken: accessToken,
                accountId: selectedAquaAccountID,
                force: true
            )
            async let workspaceLoad: Void = loadWorkspace(force: true)
            _ = await (
                selectedLoad,
                workspaceLoad
            )
        } else {
            await loadWorkspace(force: true)
        }
    }

    private func refreshAquaOnly() async {
        await viewModel.loadAquaActivity(
            accessToken: accessToken,
            fetchPositions: false,
            accountId: nil,
            force: true
        )

        if let selectedAquaAccountID {
            await viewModel.loadAquaActivity(
                accessToken: accessToken,
                accountId: selectedAquaAccountID,
                force: true
            )
        }
    }

    private func refreshLiveAquaPosition() async {
        guard let selectedAquaAccountID else {
            return
        }

        await viewModel.loadAquaActivity(
            accessToken: accessToken,
            accountId: selectedAquaAccountID,
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
        selectedAccountProvider = "Aqua Funding"
        selectedAccountContextID = route.accountId
        selectedAccountDisplayName = route.accountId
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

                if let selectedAccountDisplayName {
                    pill(selectedAccountDisplayName, tint: AppTheme.softGold)
                }
            }
            
            Text(viewModel.workspace?.effectiveSummary ?? "Trader OS command center for AI, broker quote source, timeframes, open trades, accounts, calendar, ML insights, journal, and stats.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)

            NavigationLink {
                MarketDetailView(
                    requestSymbol: workspaceSymbol.requestSymbol,
                    displayName: workspaceSymbol.displayName,
                    tradeSymbol: workspaceSymbol.tradeSymbol,
                    accessToken: accessToken,
                    broker: effectiveBroker,
                    accountKey: effectiveAccountKey
                )
            } label: {
                Label(
                    "Open chart, all timeframes, and Heikin Ashi",
                    systemImage: "chart.xyaxis.line"
                )
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)
            }

            workspaceSymbolPicker
        }
    }

    private var workspaceSymbolPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Switch Market")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.secondaryText)

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

            if isKrakenContext {
                krakenTraderDisclosure
            } else {
                customSymbolEntry
                customSymbolFeedback
                selectedAccountPositionStrip
            }

            if isAquaWorkspace, selectedAquaAccountID != nil {
                Label(
                    "Aqua execution instruments",
                    systemImage: "checkmark.shield.fill"
                )
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)

                Text(
                    "These are execution shortcuts for the selected account. Live Market above remains available for global analysis."
                )
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)

                if aquaInstruments.isEmpty {
                    Text("Account instrument catalog is not loaded yet.")
                        .font(.caption)
                } else {
                    aquaInstrumentStrip
                }

                if !aquaInstruments.isEmpty,
                   !selectedInstrumentIsAquaTradable {
                    Label(
                        "Analysis only — not tradable on selected Aqua account",
                        systemImage: "eye.fill"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                }
            }

            Text("Changing the ticker reloads Trader OS, timeframes, prediction context, and risk sizing without leaving the Bat Cave.")
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.top, 4)
    }

    private var customSymbolEntry: some View {
        HStack(spacing: 8) {
                TextField("Any ticker", text: $customSymbolText)
                    .autocorrectionDisabled()
                    .focused($isCustomSymbolFocused)
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
                    isCustomSymbolFocused = false
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
    }

    @ViewBuilder
    private var customSymbolFeedback: some View {
            if !customSymbolSuggestions.isEmpty {
                workspaceSuggestionStrip(customSymbolSuggestions)
            }

            if let symbolInputError {
                Text(symbolInputError)
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }
    }

    @ViewBuilder
    private var selectedAccountPositionStrip: some View {
            if !selectedProviderPositionSymbols.isEmpty {
                Label(
                    "Selected account positions",
                    systemImage: "briefcase.fill"
                )
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)
                workspaceSuggestionStrip(selectedProviderPositionSymbols)
            }
    }

    private var krakenTraderDisclosure: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                isKrakenTraderExpanded.toggle()
                if isKrakenTraderExpanded && krakenInstruments.isEmpty {
                    Task { await loadKrakenInstrumentUniverse() }
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("KRAKEN TRADER")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.softGold)
                        Text(
                            selectedAccountDisplayName
                                ?? "Kraken selected • choose an account when ready"
                        )
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                        Text("\(selectedContextTrades.count) current position\(selectedContextTrades.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: isKrakenTraderExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(AppTheme.softGold)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isKrakenTraderExpanded {
                Text("Search Kraken's cached instrument catalog or inspect a current position. Market analysis remains independent from account selection.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText)
                customSymbolEntry
                customSymbolFeedback
                selectedAccountPositionStrip
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                        isCustomSymbolFocused = false
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
        workspaceLoadTask?.cancel()
        workspaceLoadTask = Task {
            // A symbol/account pair has its own cache key. It does not need
            // to destroy and force-reload every other Trader OS component.
            await loadWorkspace(force: false)
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

            if let heartbeats = viewModel.brokerHealth?.connections, !heartbeats.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(uniqueHeartbeats(heartbeats)) { heartbeat in
                            Button {
                                selectHeartbeat(heartbeat)
                            } label: {
                                brokerHeartbeatTile(heartbeat)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else if let companies = viewModel.brokerHealth?.companies, !companies.isEmpty {
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

            if !selectableBrokerAccounts.isEmpty {
                Text("Execution Accounts")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.secondaryText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(selectableBrokerAccounts) { account in
                            Button {
                                selectBrokerAccount(account)
                            } label: {
                                brokerAccountContextTile(account)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
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

    private func brokerHeartbeatTile(_ heartbeat: BrokerHeartbeat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Circle()
                    .fill(healthColor(heartbeat.dataState))
                    .frame(width: 9, height: 9)
                Text(heartbeat.displayName ?? displayBrokerName(heartbeat.provider))
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
            }
            Text("\(heartbeat.connectionState.uppercased()) • \(heartbeat.dataState.uppercased())")
                .font(.caption2.bold())
                .foregroundStyle(healthColor(heartbeat.dataState))
            Text("\(heartbeat.positionCount) open position\(heartbeat.positionCount == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
            if let pnl = heartbeat.unrealizedPnl {
                Text("\(pnl.formatted(.currency(code: "USD"))) unrealized")
                    .font(.caption2)
                    .foregroundStyle(pnl >= 0 ? .green : .red)
            }
            if let lastSync = heartbeat.lastSuccessfulSync {
                Text("Last sync \(lastSync)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding()
        .frame(width: 210, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    selectedAccountContextID == heartbeat.connectionId
                        ? AppTheme.softGold
                        : Color.clear,
                    lineWidth: 2
                )
        }
    }

    private func uniqueHeartbeats(_ values: [BrokerHeartbeat]) -> [BrokerHeartbeat] {
        var seen = Set<String>()
        return values.filter { seen.insert($0.connectionId.lowercased()).inserted }
    }

    private func brokerAccountContextTile(
        _ account: BrokerAccountResponse
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(account.accountName ?? account.accountId)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
            Text(displayBrokerName(account.broker))
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.softGold)
            Text((account.accountStatus ?? "active").uppercased())
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
            if let equity = account.equity ?? account.balance {
                Text(equity.formatted(.currency(code: account.currency ?? "USD")))
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.primaryText)
            }
        }
        .padding()
        .frame(width: 190, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    selectedAccountContextID == account.accountId
                        ? AppTheme.softGold
                        : Color.clear,
                    lineWidth: 2
                )
        }
    }

    private func selectHeartbeat(_ heartbeat: BrokerHeartbeat) {
        selectedAccountProvider = heartbeat.provider
        selectedAccountDisplayName = heartbeat.displayName
        if isAquaProvider(heartbeat.provider) {
            aquaContextActive = true
            selectedAquaAccountID = nil
            selectedAccountContextID = nil
            aquaInstruments = []
            viewModel.clearSelectedAquaActivity()
        } else {
            aquaContextActive = false
            selectedAquaAccountID = nil
            selectedAccountContextID = heartbeat.connectionId
        }
        print(
            "[AccountContext] provider=\(heartbeat.provider) "
            + "connection=\(heartbeat.connectionId) cache=preserved"
        )
        if isKrakenProvider(heartbeat.provider), isKrakenTraderExpanded {
            Task { await loadKrakenInstrumentUniverse() }
        }
        Task { await loadWorkspace(force: false) }
    }

    private func selectManagedProvider(_ provider: String) {
        selectedAccountProvider = provider
        selectedAccountContextID = nil
        selectedAccountDisplayName = nil
        selectedFocusedPositionID = nil
        aquaContextActive = isAquaProvider(provider)
        selectedAquaAccountID = nil
        if isKrakenProvider(provider), isKrakenTraderExpanded {
            Task { await loadKrakenInstrumentUniverse() }
        }
        Task { await loadWorkspace(force: false) }
    }

    private func selectManagedAccount(
        provider: String,
        accountID: String,
        displayName: String
    ) {
        selectedAccountProvider = provider
        selectedAccountContextID = accountID
        selectedAccountDisplayName = displayName
        selectedFocusedPositionID = nil
        aquaContextActive = isAquaProvider(provider)
        selectedAquaAccountID = aquaContextActive ? accountID : nil
        if isKrakenProvider(provider), isKrakenTraderExpanded {
            Task { await loadKrakenInstrumentUniverse() }
        }
        Task { await loadWorkspace(force: false) }
    }

    private func selectBrokerAccount(_ account: BrokerAccountResponse) {
        selectedAccountProvider = account.broker
        selectedAccountContextID = account.accountId
        selectedAccountDisplayName = account.accountName ?? account.accountId
        if isAquaProvider("\(account.broker) \(account.platform ?? "")") {
            aquaContextActive = true
            selectedAquaAccountID = account.accountId
            aquaInstruments = []
            Task {
                async let accountLoad: Void = viewModel.loadAquaActivity(
                    accessToken: accessToken,
                    accountId: account.accountId
                )
                async let workspaceLoad: Void = loadWorkspace(force: false)
                _ = await (accountLoad, workspaceLoad)
            }
        } else {
            aquaContextActive = false
            selectedAquaAccountID = nil
            if isKrakenProvider(account.broker), isKrakenTraderExpanded {
                Task { await loadKrakenInstrumentUniverse() }
            }
            Task { await loadWorkspace(force: false) }
        }
    }

    private func isKrakenProvider(_ value: String?) -> Bool {
        (value ?? "").lowercased().contains("kraken")
    }

    private func reconcileDisconnectedConnection(
        provider: String,
        connectionID: String
    ) {
        guard isKrakenProvider(provider),
              selectedAccountContextID == connectionID else {
            return
        }
        selectedAccountContextID = nil
        selectedAccountDisplayName = nil
        selectedFocusedPositionID = nil
        selectedAccountProvider = "kraken"
        print(
            "[AccountContext] provider=kraken connection=..."
            + "\(connectionID.suffix(8)) action=disconnected-focus-cleared"
        )
    }

    @MainActor
    private func loadKrakenInstrumentUniverse() async {
        do {
            krakenInstruments = try await AppRefreshCoordinator.shared
                .krakenInstruments(accessToken: accessToken)
                .instruments
            print(
                "[InstrumentUniverse] provider=kraken cached="
                + "\(krakenInstruments.count)"
            )
        } catch {
            // Account selection remains valid even when metadata refresh is
            // unavailable. Existing positions and generic research stay up.
            print("[InstrumentUniverse] provider=kraken action=unavailable-preserved")
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
        case "healthy", "connected", "synced", "active", "live":
            return .green
        case "partial", "warning", "degraded":
            return .yellow
        case "offline", "error", "failed", "disconnected":
            return .red
        default:
            return .gray
        }
    }

    private func isAquaProvider(_ value: String?) -> Bool {
        let normalized = (value ?? "").lowercased()
        return normalized.contains("aqua")
            || normalized.contains("match trader")
            || normalized.contains("match-trader")
            || normalized.contains("match_trader")
    }

    private func isTerminalAccountStatus(_ value: String?) -> Bool {
        let normalized = (value ?? "").lowercased()
        return [
            "breached", "closed", "disabled", "expired",
            "failed", "inactive", "terminated",
        ].contains { normalized.contains($0) }
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
                    ForEach(versionOneCards) { card in
                        workspaceCard(card)
                            .frame(minHeight: 330, alignment: .top)
                    }
                }
            } else {
                VStack(spacing: 14) {
                    ForEach(versionOneCards) { card in
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
                    ("Tracked Open", "\(selectedContextTrades.count)"),
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
                if let journalError {
                    Text(journalError)
                        .foregroundStyle(.red)
                } else if journals.isEmpty {
                    Text("No journal entries yet. Confirmed broker trades will appear here for review.")
                        .lineLimit(4)
                } else {
                    detailGrid([
                        ("Entries", "\(journals.count)"),
                        ("Latest", journals.first?.symbol ?? "--"),
                        ("Learning", "Connected")
                    ])

                    ForEach(Array(journals.prefix(3))) { journal in
                        journalSummary(journal)
                    }
                }
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
        Button {
            selectedFocusedPositionID = trade.externalPositionId
                ?? trade.id.uuidString
            activeTradePrompt = .editTrade(trade)
        } label: {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(
                    viewModel.portfolioMarks[trade.id]?.displaySymbol
                        ?? trade.marketDisplaySymbol
                )
                    .font(.headline.bold())
                    .foregroundStyle(trade.symbol.uppercased() == selectedSymbol ? AppTheme.softGold : AppTheme.primaryText)

                Spacer()

                if let pnl = viewModel.portfolioMarks[trade.id]?.netPnl
                    ?? viewModel.portfolioMarks[trade.id]?.openPnl
                    ?? trade.netPnl
                    ?? trade.openPnl {
                    Text(formatMoney(pnl))
                        .font(.caption.bold())
                        .foregroundStyle(pnl >= 0 ? .green : .red)
                }
            }

            HStack(spacing: 14) {
                detailMini(
                    title: "Entry",
                    value: trade.knownEntryPrice.map(formatPrice) ?? "Unavailable"
                )
                detailMini(
                    title: "Current",
                    value: formatPrice(
                        viewModel.portfolioMarks[trade.id]?.currentPrice
                            ?? trade.currentPrice
                    )
                )
                detailMini(title: "Qty", value: trade.quantity == nil ? "--" : String(format: "%.2f", trade.quantity!))
            }

            if let broker = trade.platform {
                Text("Broker: \(broker)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Text(
                trade.providerKey == "kraken"
                    ? "Tap to review this broker-authoritative position. Kraken execution remains disabled."
                    : "Tap to manage this tracked trade."
            )
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.vertical,4)
        }
        .buttonStyle(.plain)
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
        if let selectedContextBrokerAccount {
            return selectedContextBrokerAccount
        }
        return nonAquaBrokerAccounts.first { account in
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

                Text(
                    "Review the selected market, quote, timeframe, and open-position context."
                )
                .foregroundStyle(AppTheme.secondaryText)

                Divider()

                ScrollView{
                    if card == .journal {
                        journalDetailContent
                    } else {
                        cardContent(card)
                    }
                }
            }
            .padding()
            .frame(maxWidth:760, maxHeight:700)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius:24))
            .padding()
        }
    }

    private func journalSummary(
        _ journal: TradeJournalResponse
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(journal.symbol ?? "Trade")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.primaryText)
                Text(journal.broker ?? "ChaseINGreen Journal")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            if let pnl = journal.netPnl {
                Text(formatMoney(pnl))
                    .font(.caption.bold())
                    .foregroundStyle(pnl >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }

    private var journalDetailContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if journals.isEmpty {
                Text("Confirmed trades will appear here without creating a second history source.")
                    .foregroundStyle(AppTheme.secondaryText)
            }

            ForEach(journals) { journal in
                Button {
                    journalNotes = journal.notes ?? ""
                    selectedJournal = journal
                } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        journalSummary(journal)
                        if let notes = journal.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                                .lineLimit(3)
                        }
                        Text("Review journal")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.softGold)
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func journalEditor(
        _ journal: TradeJournalResponse
    ) -> some View {
        NavigationStack {
            Form {
                Section("Confirmed trade") {
                    LabeledContent("Symbol", value: journal.symbol ?? "--")
                    LabeledContent("Broker", value: journal.broker ?? "--")
                    if let pnl = journal.netPnl {
                        LabeledContent("Net P/L", value: formatMoney(pnl))
                    }
                }

                Section("Your notes") {
                    TextEditor(text: $journalNotes)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle("Trade Journal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        selectedJournal = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSavingJournal ? "Saving…" : "Save") {
                        Task {
                            await saveJournal(journal)
                        }
                    }
                    .disabled(isSavingJournal)
                }
            }
        }
    }

    @MainActor
    private func saveJournal(
        _ journal: TradeJournalResponse
    ) async {
        isSavingJournal = true
        defer { isSavingJournal = false }

        do {
            let updated = try await APIService.shared
                .updateTradeJournal(
                    id: journal.id,
                    notes: journalNotes.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    accessToken: accessToken
                )

            if let index = journals.firstIndex(where: {
                $0.id == updated.id
            }) {
                journals[index] = updated
            }
            selectedJournal = nil
            journalError = nil
        } catch {
            journalError = error.localizedDescription
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
