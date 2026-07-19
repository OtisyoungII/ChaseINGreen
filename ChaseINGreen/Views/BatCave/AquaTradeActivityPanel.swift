//
//  AquaTradeActivityPanel.swift
//  ChaseINGreen
//
//  Broker-confirmed Aqua Funding account and position workspace.
//

import SwiftUI

struct AquaTradeActivityPanel: View {
    let connection: MatchTraderConnectionFeatures?
    let positionsResponse: MatchTraderPositionsResponse?
    let brokerAccounts: [BrokerAccountResponse]
    let selectedMarketSymbol: String
    let positionSize: PositionSizeBlock?
    let isLoading: Bool
    let errorMessage: String?
    let accessToken: String
    let onRefresh: () async -> Void
    let onClearBackendTrades: () async throws -> BackendTradeClearResponse
    let onMarketSymbolSelected: (String) -> Void

    @State private var selectedAccountId: String?
    @State private var selectedPosition: MatchTraderLivePosition?
    @State private var aquaInstruments: [MatchTraderInstrument] = []
    @State private var selectedInstrumentSymbol = ""
    @State private var isLoadingInstruments = false
    @State private var instrumentError: String?
    @State private var showingMarketEntry = false
    @State private var isExpanded = false
    @State private var showAllAccounts = false
    @State private var showResetConfirmation = false
    @State private var isResetting = false
    @State private var resetMessage: String?
    @State private var resetError: String?

    private var connectedAccounts: [MatchTraderConnectedAccount] {
        connection?.accounts ?? []
    }

    private var positionAccounts: [MatchTraderPositionAccount] {
        positionsResponse?.accounts ?? []
    }

    private var activeAccountIds: Set<String> {
        Set(
            connectedAccounts.compactMap { account in
                let positionAccount = matchingPositionAccount(
                    account
                )

                let positionCount = positionAccount?.count
                    ?? positionAccount?.positions?.count
                    ?? 0

                return positionCount > 0
                    ? accountIdentifier(account)
                    : nil
            }
        )
    }

    private var activeConnectedAccounts: [MatchTraderConnectedAccount] {
        connectedAccounts.filter { account in
            guard let accountId = accountIdentifier(account) else {
                return false
            }

            return activeAccountIds.contains(accountId)
        }
    }

    private var displayedAccounts: [MatchTraderConnectedAccount] {
        showAllAccounts
            ? connectedAccounts
            : activeConnectedAccounts
    }

    private var effectiveSelectedAccountId: String? {
        if let selectedAccountId {
            return selectedAccountId
        }

        return displayedAccounts.first.flatMap(accountIdentifier)
            ?? positionAccounts.first(where: {
                $0.available == true
            })?.accountId
    }

    private var selectedPositionAccount: MatchTraderPositionAccount? {
        guard let effectiveSelectedAccountId else {
            return positionAccounts.first
        }

        return positionAccounts.first {
            positionAccountIdentifiers($0).contains(
                normalizedAccountIdentifier(
                    effectiveSelectedAccountId
                )
            )
        }
    }

    private var selectedPositions: [MatchTraderLivePosition] {
        selectedPositionAccount?.positions ?? []
    }

    private var effectiveInstrument: MatchTraderInstrument? {
        aquaInstruments.first {
            $0.symbol.caseInsensitiveCompare(
                selectedInstrumentSymbol
            ) == .orderedSame
        }
        ?? aquaInstruments.first {
            $0.symbol.caseInsensitiveCompare(
                selectedMarketSymbol
            ) == .orderedSame
        }
        ?? aquaInstruments.first
    }

    private var instrumentLoadKey: String {
        "\(isExpanded)-\(effectiveSelectedAccountId ?? "none")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if isExpanded {
                if connection == nil {
                    emptyState(
                        title: "Connect Aqua Funding",
                        message: "Once connected, this area will show only broker-confirmed Aqua accounts and live positions."
                    )
                } else {
                    accountScopePicker

                    if displayedAccounts.isEmpty && !showAllAccounts {
                        emptyState(
                            title: "No Active Aqua Accounts",
                            message: "None of the connected Aqua accounts currently has a broker-confirmed open position. Choose All Accounts only when you need to inspect or select an inactive account."
                        )
                    } else {
                        accountPicker
                    }

                    marketEntrySection

                    if isLoading {
                        ProgressView("Loading live Aqua activity...")
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else if let errorMessage {
                        aquaErrorCard(errorMessage)
                    } else if positionsResponse?.success == false {
                        aquaErrorCard(
                            positionsResponse?.summary
                                ?? positionsResponse?.headline
                                ?? "Aqua live trading access is unavailable."
                        )
                    } else if selectedPositions.isEmpty {
                        emptyState(
                            title: "No Open Aqua Positions",
                            message: "This selected account currently has no broker-confirmed open positions. Stored manual trades are not mixed into this list."
                        )
                    } else {
                        positionSummary

                        ForEach(selectedPositions) { position in
                            positionRow(position)
                        }
                    }
                }

                cleanStartSection

                if let resetMessage {
                    statusBanner(
                        resetMessage,
                        color: .green,
                        systemImage: "checkmark.circle.fill"
                    )
                }

                if let resetError {
                    statusBanner(
                        resetError,
                        color: .red,
                        systemImage: "exclamationmark.triangle.fill"
                    )
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.softGold.opacity(0.25), lineWidth: 1)
        }
        .task {
            selectFirstAccountIfNeeded()
        }
        .task(id: instrumentLoadKey) {
            guard isExpanded else {
                return
            }

            await loadEffectiveInstruments()
        }
        .onChange(of: connectedAccountKey) {
            selectFirstAccountIfNeeded()
        }
        .onChange(of: showAllAccounts) {
            selectFirstAccountIfNeeded()
        }
        .sheet(item: $selectedPosition) { position in
            AquaPositionManagementSheet(
                position: position,
                accountId: position.accountId
                    ?? effectiveSelectedAccountId
                    ?? "",
                accountTitle: accountTitle(
                    accountId: position.accountId
                        ?? effectiveSelectedAccountId
                ),
                accessToken: accessToken
            ) {
                await onRefresh()
            }
        }
        .sheet(isPresented: $showingMarketEntry) {
            if let accountId = effectiveSelectedAccountId {
                if let effectiveInstrument {
                    AquaMarketEntrySheet(
                        accountId: accountId,
                        accountTitle: accountTitle(
                            accountId: accountId
                        ),
                        instrument: effectiveInstrument,
                        balanceHealth: selectedPositionAccount?.balanceHealth,
                        analysisPositionSize: positionSize,
                        accessToken: accessToken
                    ) {
                        await onRefresh()
                    }
                }
            }
        }
        .confirmationDialog(
            "Clear the entire stored trade database?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                "Clear Backend Trade Records",
                role: .destructive
            ) {
                Task {
                    await clearBackendTrades()
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This administrator action permanently removes every stored ChaseInGreen trade for every user, including records stuck as active, plus their linked trade journals. Live Aqua positions are separate and remain available from the broker."
            )
        }
    }

    private var header: some View {
        Button {
            let expanding = !isExpanded

            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }

            if expanding {
                Task {
                    await onRefresh()
                }
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                headerText

                Spacer(minLength: 12)

                if !activeAccountIds.isEmpty {
                    Text("\(activeAccountIds.count) active")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.10))
                        .clipShape(Capsule())
                }

                Image(
                    systemName: isExpanded
                        ? "chevron.up.circle.fill"
                        : "chevron.down.circle.fill"
                )
                .foregroundStyle(AppTheme.softGold)
            }
        }
        .buttonStyle(.plain)
    }

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(
                "Aqua Trader",
                systemImage: "wave.3.right.circle.fill"
            )
            .font(.title3.bold())
            .foregroundStyle(AppTheme.softGold)

            Text(
                isExpanded
                    ? "Broker-confirmed accounts and positions only. Select a position to manage it."
                    : "Open the dedicated Aqua trader. Connected accounts stay out of the normal workspace."
            )
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var refreshButton: some View {
        Button {
            Task {
                await onRefresh()
            }
        } label: {
            Label("Refresh Aqua", systemImage: "arrow.clockwise")
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(AppTheme.softGold.opacity(0.14))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private var accountScopePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    accountScopeButtons

                    Spacer()

                    refreshButton
                }

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        accountScopeButtons
                    }

                    refreshButton
                }
            }

            Text(
                showAllAccounts
                    ? "All connected accounts are visible only while you are intentionally browsing this Aqua trader."
                    : "Only accounts with open broker positions are shown."
            )
            .font(.caption2)
            .foregroundStyle(AppTheme.secondaryText)
        }
    }

    @ViewBuilder
    private var accountScopeButtons: some View {
        scopeButton(
            "Live (\(activeConnectedAccounts.count))",
            selected: !showAllAccounts
        ) {
            showAllAccounts = false
        }

        scopeButton(
            "All Accounts (\(connectedAccounts.count))",
            selected: showAllAccounts
        ) {
            showAllAccounts = true
        }
    }

    private func scopeButton(
        _ title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(
                    selected
                        ? AppTheme.primaryText
                        : AppTheme.secondaryText
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    selected
                        ? AppTheme.softGold.opacity(0.14)
                        : Color.secondary.opacity(0.06)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var accountPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(displayedAccounts) { account in
                    let accountId = accountIdentifier(account)

                    Button {
                        selectedAccountId = accountId
                    } label: {
                        accountTile(
                            account,
                            isSelected: accountId
                                == effectiveSelectedAccountId
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var marketEntrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoadingInstruments {
                ProgressView("Loading this account's Aqua instruments...")
                    .font(.caption)
            } else if let instrumentError {
                Text(instrumentError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if aquaInstruments.isEmpty {
                Text(
                    "Aqua did not return any tradable instruments for this account."
                )
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            } else {
                Picker(
                    "Aqua Instrument",
                    selection: $selectedInstrumentSymbol
                ) {
                    ForEach(aquaInstruments) { instrument in
                        Text(instrumentLabel(instrument))
                            .tag(instrument.symbol)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedInstrumentSymbol) {
                    guard !selectedInstrumentSymbol.isEmpty else {
                        return
                    }

                    onMarketSymbolSelected(
                        selectedInstrumentSymbol
                    )
                }
            }

            Button {
                showingMarketEntry = true
            } label: {
                HStack {
                    Label(
                        "New \(effectiveInstrument?.symbol.uppercased() ?? "Aqua") Market Trade",
                        systemImage: "plus.circle.fill"
                    )
                    .font(.caption.bold())

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                }
                .foregroundStyle(AppTheme.deepBlack)
                .padding(12)
                .background(AppTheme.softGold)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(
                effectiveSelectedAccountId == nil
                    || effectiveInstrument == nil
                    || isLoadingInstruments
                    || selectedPositionAccount?.available == false
                    || isLoading
            )

            Text(
                "Only instruments returned by this selected Aqua account are shown. Aqua executes immediately at the broker's current market price and still requires final BUY or SELL confirmation."
            )
            .font(.caption2)
            .foregroundStyle(AppTheme.secondaryText)
        }
    }

    @MainActor
    private func loadEffectiveInstruments() async {
        guard let accountId = effectiveSelectedAccountId else {
            aquaInstruments = []
            selectedInstrumentSymbol = ""
            return
        }

        isLoadingInstruments = true
        instrumentError = nil

        defer {
            isLoadingInstruments = false
        }

        do {
            let response = try await APIService.shared
                .fetchMatchTraderInstruments(
                    accountId: accountId,
                    accessToken: accessToken
                )

            guard response.success == true else {
                throw AquaActivityError.operationFailed(
                    response.summary
                        ?? response.headline
                        ?? "Aqua instruments are unavailable."
                )
            }

            aquaInstruments = (response.instruments ?? [])
                .filter {
                    $0.tradable != false
                        && !$0.symbol.isEmpty
                }
                .sorted {
                    $0.symbol.localizedStandardCompare(
                        $1.symbol
                    ) == .orderedAscending
                }

            if let current = aquaInstruments.first(where: {
                $0.symbol.caseInsensitiveCompare(
                    selectedMarketSymbol
                ) == .orderedSame
            }) {
                selectedInstrumentSymbol = current.symbol
            } else {
                selectedInstrumentSymbol = (
                    aquaInstruments.first?.symbol
                    ?? ""
                )
            }
        } catch {
            aquaInstruments = []
            selectedInstrumentSymbol = ""
            instrumentError = error.localizedDescription
        }
    }

    private func instrumentLabel(
        _ instrument: MatchTraderInstrument
    ) -> String {
        let display = instrument.displayName?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard let display,
              !display.isEmpty,
              display.caseInsensitiveCompare(
                instrument.symbol
              ) != .orderedSame else {
            return instrument.symbol.uppercased()
        }

        return "\(instrument.symbol.uppercased()) — \(display)"
    }

    private func accountTile(
        _ account: MatchTraderConnectedAccount,
        isSelected: Bool
    ) -> some View {
        let positionAccount = matchingPositionAccount(
            account
        )
        let positionCount = positionAccount?.count
            ?? positionAccount?.positions?.count
            ?? 0
        let balanceHealth = positionAccount?.balanceHealth

        return VStack(alignment: .leading, spacing: 5) {
            Text(richAccountTitle(account))
                .font(.caption.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text("Login \(account.tradingAccountId ?? "—")")
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)

            if let offerName = account.offerName,
               !offerName.isEmpty {
                Text(offerName)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }

            let accountContext = [
                account.accountType,
                account.group,
                account.leverage.map {
                    "1:\($0.formatted(.number.precision(.fractionLength(0))))"
                }
            ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")

            if !accountContext.isEmpty {
                Text(accountContext)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }

            if let balance = balanceHealth?.balance {
                Text("Balance \(currency(balance))")
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.primaryText)
            } else if let initialDeposit = account.initialDeposit {
                Text("Starting \(currency(initialDeposit))")
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.primaryText)
            }

            if let equity = balanceHealth?.equity {
                Text("Equity \(currency(equity))")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            if positionAccount?.available == false {
                Label(
                    "Trading access unavailable",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption2.bold())
                .foregroundStyle(.orange)
            } else {
                Label(
                    "\(positionCount) open",
                    systemImage: positionCount > 0
                        ? "chart.line.uptrend.xyaxis"
                        : "checkmark.circle"
                )
                .font(.caption2.bold())
                .foregroundStyle(positionCount > 0 ? .orange : .green)
            }
        }
        .padding(12)
        .frame(width: 190, alignment: .leading)
        .background(
            isSelected
                ? AppTheme.softGold.opacity(0.14)
                : Color.secondary.opacity(0.06)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isSelected
                        ? AppTheme.softGold.opacity(0.55)
                        : Color.clear,
                    lineWidth: 1
                )
        }
    }

    private var positionSummary: some View {
        HStack(spacing: 10) {
            summaryMetric(
                "Open",
                "\(selectedPositions.count)"
            )
            summaryMetric(
                "Net P/L",
                currency(
                    selectedPositions
                        .compactMap { $0.netProfit ?? $0.profit }
                        .reduce(0, +)
                )
            )
            summaryMetric(
                "Volume",
                selectedPositions
                    .compactMap(\.volume)
                    .reduce(0, +)
                    .formatted(
                        .number.precision(.fractionLength(2))
                    )
            )
        }
    }

    private func positionRow(
        _ position: MatchTraderLivePosition
    ) -> some View {
        Button {
            selectedPosition = position
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(position.symbol.uppercased())
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.primaryText)

                    Text((position.side ?? "—").uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(
                            position.side?.lowercased() == "long"
                                ? .green
                                : .red
                        )

                    Spacer()

                    Text(
                        currency(
                            position.netProfit
                                ?? position.profit
                                ?? 0
                        )
                    )
                    .font(.headline.bold())
                    .foregroundStyle(
                        (position.netProfit ?? position.profit ?? 0) >= 0
                            ? .green
                            : .red
                    )
                }

                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 95), spacing: 10)
                    ],
                    spacing: 8
                ) {
                    positionMetric("Volume", number(position.volume))
                    positionMetric("Open", price(position.openPrice))
                    positionMetric("Current", price(position.currentPrice))
                    positionMetric("Stop", price(position.stopLoss))
                    positionMetric("Target", price(position.takeProfit))
                }

                HStack {
                    Text("Position \(position.positionId ?? "—")")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)

                    Spacer()

                    Label("Manage", systemImage: "slider.horizontal.3")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.softGold)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var cleanStartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text("System Clean Start")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text(
                "Empty the backend logged-trades table for every user so all ChaseInGreen dashboards show zero stored trades. Live Aqua positions come from the broker and remain separate."
            )
            .font(.caption2)
            .foregroundStyle(AppTheme.secondaryText)

            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Label(
                    isResetting
                        ? "Clearing Backend Trades..."
                        : "Clear All Backend Trades",
                    systemImage: "trash"
                )
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding(11)
                .background(Color.red.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isResetting)
        }
    }

    @MainActor
    private func clearBackendTrades() async {
        isResetting = true
        resetMessage = nil
        resetError = nil

        defer {
            isResetting = false
        }

        do {
            let response = try await onClearBackendTrades()

            guard response.success != false else {
                throw AquaActivityError.operationFailed(
                    response.summary
                        ?? response.headline
                        ?? "Backend trade cleanup failed."
                )
            }

            resetMessage = response.summary
                ?? "Stored test trades were removed."

            await onRefresh()
        } catch {
            resetError = error.localizedDescription
        }
    }

    private var connectedAccountKey: String {
        let accounts = connectedAccounts
            .compactMap(accountIdentifier)
            .joined(separator: "|")

        let active = activeAccountIds
            .sorted()
            .joined(separator: "|")

        return accounts + "::" + active
    }

    private func selectFirstAccountIfNeeded() {
        let validIds = Set(
            displayedAccounts.compactMap(accountIdentifier)
        )

        if selectedAccountId == nil
            || !validIds.contains(selectedAccountId ?? "") {
            selectedAccountId = displayedAccounts.first.flatMap(
                accountIdentifier
            )
        }
    }

    private func accountIdentifier(
        _ account: MatchTraderConnectedAccount
    ) -> String? {
        account.tradingAccountId
            ?? account.accountUUID
            ?? account.accountName
    }

    private func connectedAccountIdentifiers(
        _ account: MatchTraderConnectedAccount
    ) -> Set<String> {
        Set(
            [
                account.tradingAccountId,
                account.accountUUID,
                account.accountName
            ]
            .compactMap { value in
                value.map(normalizedAccountIdentifier)
            }
            .filter { !$0.isEmpty }
        )
    }

    private func positionAccountIdentifiers(
        _ account: MatchTraderPositionAccount
    ) -> Set<String> {
        Set(
            [
                account.accountId,
                account.tradingAccountId,
                account.accountUUID,
                account.accountName
            ]
            .compactMap { value in
                value.map(normalizedAccountIdentifier)
            }
            .filter { !$0.isEmpty }
        )
    }

    private func matchingPositionAccount(
        _ account: MatchTraderConnectedAccount
    ) -> MatchTraderPositionAccount? {
        let identifiers = connectedAccountIdentifiers(
            account
        )

        return positionAccounts.first { positionAccount in
            !identifiers.isDisjoint(
                with: positionAccountIdentifiers(
                    positionAccount
                )
            )
        }
    }

    private func normalizedAccountIdentifier(
        _ value: String
    ) -> String {
        value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        .lowercased()
    }

    private func connectedAccount(
        accountId: String?
    ) -> MatchTraderConnectedAccount? {
        guard let accountId else {
            return nil
        }

        return connectedAccounts.first {
            accountIdentifier($0) == accountId
        }
    }

    private func richAccountTitle(
        _ account: MatchTraderConnectedAccount
    ) -> String {
        let fallbackAccount = brokerAccounts.first { brokerAccount in
            let accountId = accountIdentifier(account)

            return brokerAccount.accountId == accountId
                || brokerAccount.accountNumber == accountId
        }

        let size = compactAccountSize(
            account.initialDeposit
                ?? fallbackAccount?.startingBalance
                ?? fallbackAccount?.balance
        )
        let stage = accountStage(account)

        let richTitle = [size, "Aqua", stage]
            .compactMap { $0 }
            .joined(separator: " • ")

        if richTitle != "Aqua" {
            return richTitle
        }

        return account.accountName
            ?? account.offerName
            ?? "Aqua Account"
    }

    private func accountTitle(
        accountId: String?
    ) -> String {
        guard let account = connectedAccount(accountId: accountId) else {
            return accountId.map { "Aqua • \($0)" }
                ?? "Aqua Account"
        }

        return richAccountTitle(account)
    }

    private func compactAccountSize(
        _ value: Double?
    ) -> String? {
        guard let value, value > 0 else {
            return nil
        }

        if value >= 1_000_000 {
            return "$" + (value / 1_000_000).formatted(
                .number.precision(.fractionLength(0...1))
            ) + "M"
        }

        if value >= 1_000 {
            return "$" + (value / 1_000).formatted(
                .number.precision(.fractionLength(0...1))
            ) + "K"
        }

        return value.formatted(.currency(code: "USD"))
    }

    private func accountStage(
        _ account: MatchTraderConnectedAccount
    ) -> String? {
        let context = [
            account.offerName,
            account.offerDescription,
            account.accountType
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()

        if context.contains("funded") {
            return "Funded"
        }

        if context.contains("evaluation")
            || context.contains("challenge") {
            return "Evaluation"
        }

        if account.systemDemo == true
            || account.offerDemo == true {
            return "Demo"
        }

        if context.contains("real")
            || context.contains("live") {
            return "Live"
        }

        return nil
    }

    private func aquaErrorCard(
        _ rawMessage: String
    ) -> some View {
        let authenticationError = rawMessage.contains("401")
            || rawMessage.lowercased().contains("authentication")

        return VStack(alignment: .leading, spacing: 7) {
            Label(
                authenticationError
                    ? "Aqua Trading Session Needs Reconnect"
                    : "Aqua Activity Unavailable",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption.bold())
            .foregroundStyle(.orange)

            Text(
                authenticationError
                    ? "The app connection exists, but Aqua rejected the saved trading credential. Reconnect Aqua, then refresh this panel."
                    : rawMessage
            )
            .font(.caption2)
            .foregroundStyle(AppTheme.secondaryText)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func emptyState(
        title: String,
        message: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)

            Text(message)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func summaryMetric(
        _ title: String,
        _ value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func positionMetric(
        _ title: String,
        _ value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusBanner(
        _ message: String,
        color: Color,
        systemImage: String
    ) -> some View {
        Label(message, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(color)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func currency(_ value: Double) -> String {
        value.formatted(
            .currency(code: "USD")
                .precision(.fractionLength(2))
        )
    }

    private func price(_ value: Double?) -> String {
        guard let value else {
            return "—"
        }
        return value.formatted(
            .number.precision(.fractionLength(2...5))
        )
    }

    private func number(_ value: Double?) -> String {
        guard let value else {
            return "—"
        }
        return value.formatted(
            .number.precision(.fractionLength(0...4))
        )
    }
}

private struct AquaMarketEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    let accountId: String
    let accountTitle: String
    let instrument: MatchTraderInstrument
    let balanceHealth: MatchTraderBalanceHealthFeatures?
    let analysisPositionSize: PositionSizeBlock?
    let accessToken: String
    let onComplete: () async -> Void

    @State private var side = "BUY"
    @State private var volumeText = ""
    @State private var stopLossText = ""
    @State private var takeProfitText = ""
    @State private var trailingDistanceText = "0"
    @State private var accountPositionSize: PositionSizeBlock?
    @State private var isLoadingRisk = true
    @State private var isWorking = false
    @State private var showingConfirmation = false
    @State private var errorMessage: String?

    private var effectivePositionSize: PositionSizeBlock? {
        accountPositionSize ?? analysisPositionSize
    }

    private var symbol: String {
        instrument.symbol.uppercased()
    }

    private var volume: Double? {
        Double(volumeText)
    }

    private var isTradingBlocked: Bool {
        balanceHealth?.tradingAllowed == false
            || effectivePositionSize?.tradeAllowed == false
    }

    private var canReview: Bool {
        guard let volume, volume > 0 else {
            return false
        }

        return effectivePositionSize != nil
            && !isLoadingRisk
            && !isTradingBlocked
            && !isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Immediate Market Order") {
                    LabeledContent("Account", value: accountTitle)
                    LabeledContent("Instrument", value: symbol.uppercased())

                    if let minimumVolume = instrument.minimumVolume {
                        LabeledContent(
                            "Broker minimum",
                            value: format(minimumVolume)
                        )
                    }

                    if let maximumVolume = instrument.maximumVolume {
                        LabeledContent(
                            "Broker maximum",
                            value: format(maximumVolume)
                        )
                    }

                    if let volumeStep = instrument.volumeStep {
                        LabeledContent(
                            "Broker volume step",
                            value: format(volumeStep)
                        )
                    }

                    Picker("Side", selection: $side) {
                        Text("BUY").tag("BUY")
                        Text("SELL").tag("SELL")
                    }
                    .pickerStyle(.segmented)

                    Text(
                        "Aqua does not offer a future entry price here. This order executes immediately at the broker's available market price."
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }

                Section("Account-Specific Risk Size") {
                    if isLoadingRisk {
                        ProgressView("Calculating from this Aqua account...")
                    } else if let size = effectivePositionSize {
                        if let recommended = size.recommendedSize {
                            LabeledContent(
                                "Recommended",
                                value: format(recommended)
                            )
                        }

                        if let maximum = size.maxSize {
                            LabeledContent(
                                "Maximum",
                                value: format(maximum)
                            )
                        }

                        if let dollarRisk = size.dollarRisk {
                            LabeledContent(
                                "Dollar Risk",
                                value: dollarRisk.formatted(
                                    .currency(code: "USD")
                                )
                            )
                        }

                        TextField("Volume", text: $volumeText)
                            .keyboardType(.decimalPad)

                        if let summary = size.summary {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        ForEach(size.warnings ?? [], id: \.self) { warning in
                            Label(
                                warning,
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(.caption)
                            .foregroundStyle(.orange)
                        }
                    } else {
                        Text("Risk sizing could not be loaded. This live order remains blocked until it is available.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if isTradingBlocked {
                        Label(
                            "Trading is blocked by the account or risk calculator.",
                            systemImage: "hand.raised.fill"
                        )
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    }
                }

                Section("Optional Protection") {
                    TextField("Stop Loss", text: $stopLossText)
                        .keyboardType(.decimalPad)
                    TextField("Take Profit", text: $takeProfitText)
                        .keyboardType(.decimalPad)
                    TextField(
                        "Trailing Distance (0 = off)",
                        text: $trailingDistanceText
                    )
                    .keyboardType(.decimalPad)
                }

                Section("Final Review") {
                    Text(
                        "Trader OS and WAIT READY are decision support only. They never submit this order. You choose the side, size, account, and final confirmation."
                    )
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)

                    Button("Review \(side) Market Order") {
                        reviewOrder()
                    }
                    .disabled(!canReview)
                }

                if let errorMessage {
                    Section("Could Not Open Position") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Aqua Trade")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .disabled(isWorking)
            .task {
                await loadAccountRiskSize()
            }
            .confirmationDialog(
                "Submit \(side) market order?",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    "Submit \(side) \(format(volume)) \(symbol.uppercased())",
                    role: side == "SELL" ? .destructive : nil
                ) {
                    Task {
                        await submitOrder()
                    }
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "Send an immediate \(side) order for \(format(volume)) \(symbol.uppercased()) to \(accountTitle)? The fill price can move before Aqua accepts it."
                )
            }
        }
    }

    @MainActor
    private func loadAccountRiskSize() async {
        isLoadingRisk = true
        errorMessage = nil

        defer {
            isLoadingRisk = false
        }

        do {
            let response = try await APIService.shared.fetchPositionSize(
                symbol: symbol,
                broker: "Aqua Funding",
                accountKey: accountId,
                accountBalance: balanceHealth?.balance,
                accountEquity: balanceHealth?.equity
                    ?? balanceHealth?.balance,
                buyingPower: balanceHealth?.buyingPower,
                bestProbability: analysisPositionSize?.confidence,
                riskScore: analysisPositionSize?.riskScore,
                sizeProfile: analysisPositionSize?.sizeProfile,
                propFirm: true,
                accessToken: accessToken
            )

            accountPositionSize = response.positionSize

            if let recommended = response.positionSize?.recommendedSize,
               recommended > 0 {
                volumeText = format(recommended)
            }
        } catch {
            accountPositionSize = nil
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func reviewOrder() {
        errorMessage = nil

        guard let size = effectivePositionSize else {
            errorMessage = "Load the account-specific risk size before reviewing this order."
            return
        }

        guard let volume, volume > 0 else {
            errorMessage = "Enter a valid volume greater than zero."
            return
        }

        if let minimum = size.minSize,
           volume < minimum {
            errorMessage = "Volume is below the calculated minimum of \(format(minimum))."
            return
        }

        if let brokerMinimum = instrument.minimumVolume,
           volume < brokerMinimum {
            errorMessage = "Volume is below Aqua's minimum of \(format(brokerMinimum)) for \(symbol)."
            return
        }

        if let maximum = size.maxSize,
           volume > maximum {
            errorMessage = "Volume exceeds the calculated maximum of \(format(maximum))."
            return
        }

        if let brokerMaximum = instrument.maximumVolume,
           volume > brokerMaximum {
            errorMessage = "Volume exceeds Aqua's maximum of \(format(brokerMaximum)) for \(symbol)."
            return
        }

        guard !isTradingBlocked else {
            errorMessage = "The account or risk calculator currently blocks this trade."
            return
        }

        showingConfirmation = true
    }

    @MainActor
    private func submitOrder() async {
        guard let volume, volume > 0 else {
            errorMessage = "Enter a valid volume greater than zero."
            return
        }

        let trailingDistance = Double(trailingDistanceText) ?? 0

        guard trailingDistance >= 0 else {
            errorMessage = "Trailing distance cannot be negative."
            return
        }

        isWorking = true
        errorMessage = nil

        defer {
            isWorking = false
        }

        do {
            let response = try await APIService.shared
                .openMatchTraderMarketPosition(
                    MatchTraderMarketEntryRequest(
                        broker: "Aqua Funding",
                        accountId: accountId,
                        symbol: symbol.uppercased(),
                        side: side,
                        volume: volume,
                        stopLoss: Double(stopLossText),
                        takeProfit: Double(takeProfitText),
                        trailingDistance: trailingDistance,
                        userConfirmed: true
                    ),
                    accessToken: accessToken
                )

            guard response.success == true else {
                throw AquaActivityError.operationFailed(
                    response.message
                        ?? response.warnings
                        ?? "Aqua rejected the market order."
                )
            }

            await onComplete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func format(_ value: Double?) -> String {
        guard let value else {
            return "—"
        }

        return value.formatted(
            .number.precision(.fractionLength(0...6))
        )
    }
}

private struct AquaPositionManagementSheet: View {
    @Environment(\.dismiss) private var dismiss

    let position: MatchTraderLivePosition
    let accountId: String
    let accountTitle: String
    let accessToken: String
    let onComplete: () async -> Void

    @State private var stopLossText = ""
    @State private var takeProfitText = ""
    @State private var closePercent = 25
    @State private var pendingAction: AquaPositionAction?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Live Position") {
                    LabeledContent("Account", value: accountTitle)
                    LabeledContent("Symbol", value: position.symbol)
                    LabeledContent(
                        "Side",
                        value: (position.side ?? "—").uppercased()
                    )
                    LabeledContent(
                        "Volume",
                        value: format(position.volume)
                    )
                    LabeledContent(
                        "Open Price",
                        value: format(position.openPrice)
                    )
                    LabeledContent(
                        "Current Price",
                        value: format(position.currentPrice)
                    )
                }

                Section("Protection") {
                    TextField("Stop Loss", text: $stopLossText)
                        .keyboardType(.decimalPad)
                    TextField("Take Profit", text: $takeProfitText)
                        .keyboardType(.decimalPad)

                    Button("Review SL / TP Change") {
                        pendingAction = .modifyProtection
                    }

                    Button("Review Move to Break Even") {
                        pendingAction = .breakEven
                    }
                }

                Section("Reduce Position") {
                    Picker("Close", selection: $closePercent) {
                        Text("25%").tag(25)
                        Text("50%").tag(50)
                        Text("75%").tag(75)
                    }
                    .pickerStyle(.segmented)

                    Button("Review Partial Close") {
                        pendingAction = .partialClose(closePercent)
                    }
                }

                Section("Close Position") {
                    Button(
                        "Review Full Close",
                        role: .destructive
                    ) {
                        pendingAction = .fullClose
                    }
                }

                if let errorMessage {
                    Section("Could Not Complete Action") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Manage Aqua Position")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .disabled(isWorking)
            .onAppear {
                stopLossText = input(position.stopLoss)
                takeProfitText = input(position.takeProfit)
            }
            .confirmationDialog(
                pendingAction?.title ?? "Confirm Aqua Action",
                isPresented: Binding(
                    get: { pendingAction != nil },
                    set: { if !$0 { pendingAction = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let pendingAction {
                    Button(
                        pendingAction.confirmButtonTitle,
                        role: pendingAction.isDestructive
                            ? .destructive
                            : nil
                    ) {
                        Task {
                            await execute(pendingAction)
                        }
                    }
                }

                Button("Cancel", role: .cancel) {
                    pendingAction = nil
                }
            } message: {
                Text(
                    pendingAction?.message(
                        symbol: position.symbol,
                        account: accountTitle
                    ) ?? ""
                )
            }
        }
    }

    @MainActor
    private func execute(
        _ action: AquaPositionAction
    ) async {
        guard let positionId = position.positionId,
              !accountId.isEmpty else {
            errorMessage = "The live Aqua position or account ID is missing."
            pendingAction = nil
            return
        }

        let stopLoss = Double(stopLossText)
        let takeProfit = Double(takeProfitText)

        if action == .modifyProtection,
           stopLoss == nil,
           takeProfit == nil {
            errorMessage = "Enter a stop loss, take profit, or both."
            pendingAction = nil
            return
        }

        isWorking = true
        errorMessage = nil

        defer {
            isWorking = false
            pendingAction = nil
        }

        do {
            let response = try await APIService.shared
                .manageMatchTraderPosition(
                    MatchTraderPositionManagementRequest(
                        broker: "Aqua Funding",
                        accountId: accountId,
                        positionId: positionId,
                        action: action.apiAction,
                        stopLoss: action == .modifyProtection
                            ? stopLoss
                            : nil,
                        takeProfit: action == .modifyProtection
                            ? takeProfit
                            : nil,
                        volume: nil,
                        closePercent: action.closePercent,
                        userConfirmed: true
                    ),
                    accessToken: accessToken
                )

            guard response.success == true else {
                throw AquaActivityError.operationFailed(
                    response.message
                        ?? response.warnings
                        ?? "Aqua rejected the position change."
                )
            }

            await onComplete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func input(_ value: Double?) -> String {
        guard let value else {
            return ""
        }
        return value.formatted(
            .number.precision(.fractionLength(0...5))
        )
    }

    private func format(_ value: Double?) -> String {
        input(value).isEmpty ? "—" : input(value)
    }
}

private enum AquaPositionAction: Equatable {
    case modifyProtection
    case breakEven
    case partialClose(Int)
    case fullClose

    var apiAction: String {
        switch self {
        case .modifyProtection:
            return "modify_sl_tp"
        case .breakEven:
            return "move_to_break_even"
        case .partialClose:
            return "close_percent"
        case .fullClose:
            return "close_position"
        }
    }

    var closePercent: Int? {
        switch self {
        case .partialClose(let percent):
            return percent
        default:
            return nil
        }
    }

    var title: String {
        switch self {
        case .modifyProtection:
            return "Confirm Live SL / TP Change"
        case .breakEven:
            return "Move Stop to Break Even?"
        case .partialClose(let percent):
            return "Close \(percent)% of This Position?"
        case .fullClose:
            return "Close the Entire Position?"
        }
    }

    var confirmButtonTitle: String {
        switch self {
        case .modifyProtection:
            return "Update Live Position"
        case .breakEven:
            return "Move Stop to Break Even"
        case .partialClose(let percent):
            return "Close \(percent)%"
        case .fullClose:
            return "Close Entire Position"
        }
    }

    var isDestructive: Bool {
        switch self {
        case .partialClose, .fullClose:
            return true
        default:
            return false
        }
    }

    func message(
        symbol: String,
        account: String
    ) -> String {
        "This will send a live \(symbol) position change to \(account) through Aqua Funding."
    }
}

private enum AquaActivityError: LocalizedError {
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .operationFailed(let message):
            return message
        }
    }
}
