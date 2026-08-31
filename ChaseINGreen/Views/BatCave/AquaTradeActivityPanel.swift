//
//  AquaTradeActivityPanel.swift
//  ChaseINGreen
//
//  Broker-confirmed Aqua Funding account and position workspace.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AquaTradeActivityPanel: View {
    let connection: MatchTraderConnectionFeatures?
    let accountRosterResponse: MatchTraderPositionsResponse?
    let positionsResponse: MatchTraderPositionsResponse?
    let brokerAccounts: [BrokerAccountResponse]
    let selectedAccountID: String?
    let selectedMarketSymbol: String
    let positionSize: PositionSizeBlock?
    let focusedPositionID: String?
    let isLoading: Bool
    let errorMessage: String?
    let protectionMessage: String?
    let accessToken: String
    let onRefresh: () async -> Void
    let onLivePositionRefresh: () async -> Void
    let onClearBackendTrades: () async throws -> BackendTradeClearResponse
    let onMarketSymbolSelected: (String) -> Void
    let onInstrumentsChanged: ([MatchTraderInstrument]) -> Void
    let onAccountSelected: (String?) -> Void
    let onPositionSelected: (String, String, String?, String) -> Void

    @State private var selectedPosition: MatchTraderLivePosition?
    @State private var aquaInstruments: [MatchTraderInstrument] = []
    @State private var selectedInstrumentSymbol = ""
    @State private var isLoadingInstruments = false
    @State private var instrumentError: String?
    @State private var latestInstrumentRequestID = UUID()
    @State private var showingMarketEntry = false
    // Live trading controls must be visible without discovering a
    // collapsed disclosure card first.
    @State private var isExpanded = true
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

    private var rosterAccounts: [MatchTraderPositionAccount] {
        accountRosterResponse?.accounts ?? []
    }

    private var activeBrokerAccountIdentifiers: Set<String> {
        Set(
            brokerAccounts
                .filter {
                    $0.normalizedParticipationState == "active"
                        && $0.isActive
                        && !isTerminalAccountStatus($0.accountStatus)
                }
                .flatMap {
                    [$0.accountId, $0.accountNumber, $0.accountName]
                }
                .compactMap { $0 }
                .map(normalizedAccountIdentifier)
        )
    }

    private var tradableAccountIds: Set<String> {
        Set(
            connectedAccounts.compactMap { account -> String? in
                let positionAccount = matchingRosterAccount(account)

                let explicitlyActive = !connectedAccountIdentifiers(account)
                    .isDisjoint(with: activeBrokerAccountIdentifiers)

                // Health contains the complete discovered Match-Trader
                // session, not the user's live working set. If the roster is
                // temporarily unavailable, only persisted ACTIVE accounts may
                // fall back to health identity; never expose all discovered
                // accounts as "tradable."
                guard let positionAccount else {
                    guard explicitlyActive,
                          account.authenticatedForTrading != false,
                          account.systemActive != false else {
                        return nil
                    }
                    return accountIdentifier(account)
                }

                // `available` is the backend's current live-account check.
                // Do not let stale system metadata from an older Aqua roster
                // permanently hide an account that is trading successfully.
                return (positionAccount.participationState ?? "active") == "active"
                    && positionAccount.available == true
                    && !isTerminalAccountStatus(
                        positionAccount.accountStatus
                    )
                    ? accountIdentifier(account)
                    : nil
            }
        )
    }

    private var tradableConnectedAccounts: [MatchTraderConnectedAccount] {
        connectedAccounts.filter { account in
            guard let accountId = accountIdentifier(account) else {
                return false
            }

            return tradableAccountIds.contains(accountId)
        }
    }

    private var displayedAccounts: [MatchTraderConnectedAccount] {
        tradableConnectedAccounts
    }

    private var effectiveSelectedAccountId: String? {
        if let selectedAccountID,
           tradableAccountIds.contains(selectedAccountID) {
            return selectedAccountID
        }

        return nil
    }

    private var selectedPositionAccount: MatchTraderPositionAccount? {
        guard let effectiveSelectedAccountId else {
            return nil
        }

        let live = positionAccounts.first {
            positionAccountIdentifiers($0).contains(
                normalizedAccountIdentifier(
                    effectiveSelectedAccountId
                )
            )
        }
        if live?.available == true {
            return live
        }
        // A timeout/rejection is not a broker-confirmed flat snapshot. Keep
        // the last roster positions visible as stale/retryable evidence.
        return rosterAccounts.first {
            positionAccountIdentifiers($0).contains(
                normalizedAccountIdentifier(effectiveSelectedAccountId)
            )
        } ?? live
    }

    private var selectedPositions: [MatchTraderLivePosition] {
        selectedPositionAccount?.positions ?? []
    }

    private var allTradablePositions: [MatchTraderLivePosition] {
        portfolioAccounts
            .filter {
                $0.available == true
                    && $0.systemActive != false
                    && ($0.participationState ?? "active") == "active"
                    && !isTerminalAccountStatus(
                        $0.accountStatus
                    )
            }
            .flatMap {
                $0.positions ?? []
            }
    }

    private var allTradableTargets: [AquaPositionTarget] {
        var seen = Set<String>()
        return portfolioAccounts
            .filter {
                $0.available == true
                    && $0.systemActive != false
                    && ($0.participationState ?? "active") == "active"
                    && !isTerminalAccountStatus($0.accountStatus)
            }
            .flatMap { account in
                (account.positions ?? []).compactMap { position in
                    guard let resolvedAccountId = position.accountId
                        ?? account.accountId
                        ?? account.tradingAccountId,
                          !resolvedAccountId.isEmpty else { return nil }
                    let target = AquaPositionTarget(
                        position: position,
                        accountId: resolvedAccountId,
                        connectionId: connection?.connectionId
                    )
                    guard seen.insert(target.id).inserted else {
                        return nil
                    }
                    return target
                }
            }
    }

    /// Portfolio state comes from the full ACTIVE roster. The focused account
    /// response may replace only its own roster snapshot; it can never replace
    /// the other accounts in the portfolio.
    private var portfolioAccounts: [MatchTraderPositionAccount] {
        guard let selected = positionAccounts.first,
              selected.available == true else {
            return rosterAccounts
        }
        let selectedIdentifiers = positionAccountIdentifiers(selected)
        var merged = rosterAccounts.filter {
            selectedIdentifiers.isDisjoint(
                with: positionAccountIdentifiers($0)
            )
        }
        merged.append(selected)
        return merged
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

    private var focusedPositionLoadKey: String {
        let positionIds = positionAccounts
            .flatMap { $0.positions ?? [] }
            .map(\.id)
            .sorted()
            .joined(separator: ",")

        return "\(focusedPositionID ?? "none")|\(positionIds)"
    }

    private var selectedPositionUpdateKey: String {
        guard let positionId = selectedPosition?.positionId,
              let live = allTradablePositions.first(where: {
                  $0.positionId == positionId
              }) else {
            return "none"
        }

        return [
            positionId,
            String(live.currentPrice ?? 0),
            String(live.profit ?? live.netProfit ?? 0),
            String(live.stopLoss ?? 0),
            String(live.takeProfit ?? 0),
            String(live.volume ?? 0)
        ].joined(separator: "|")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if isExpanded {
                if let protectionMessage {
                    statusBanner(
                        protectionMessage,
                        color: .green,
                        systemImage: "checkmark.shield.fill"
                    )
                }

                if connection == nil {
                    emptyState(
                        title: "Connect Aqua Funding",
                        message: "Once connected, this area will show only broker-confirmed Aqua accounts and live positions."
                    )
                } else {
                    accountScopePicker

                    if displayedAccounts.isEmpty {
                        emptyState(
                            title: "No Active Aqua Accounts",
                            message: "Choose accounts in Account Command Center to include them in current Aqua trading. Discovered, ignored, and historical accounts stay outside the live portfolio."
                        )
                    } else {
                        accountPicker
                        portfolioSummary
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
                    } else if effectiveSelectedAccountId == nil {
                        emptyState(
                            title: "Select an Aqua Account",
                            message: "Choose any Active Aqua account above to load its broker-confirmed positions and instruments."
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
        .task(id: instrumentLoadKey) {
            guard isExpanded else {
                return
            }

            await loadEffectiveInstruments()
        }
        .task(id: focusedPositionLoadKey) {
            openFocusedPositionIfAvailable()
        }
        .task(id: selectedPosition?.positionId) {
            guard selectedPosition != nil else {
                return
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled,
                      selectedPosition != nil else {
                    return
                }
                await onLivePositionRefresh()
            }
        }
        .onChange(of: selectedPositionUpdateKey) {
            refreshSelectedPositionSnapshot()
        }
        .sheet(item: $selectedPosition) { position in
            AquaPositionManagementSheet(
                position: position,
                matchingTargets: allTradableTargets.filter {
                    WatchSymbol.comparisonKey($0.position.symbol)
                        == WatchSymbol.comparisonKey(position.symbol)
                },
                portfolioTargets: allTradableTargets,
                accountId: position.accountId
                    ?? effectiveSelectedAccountId
                    ?? "",
                accountTitle: accountTitle(
                    accountId: position.accountId
                        ?? effectiveSelectedAccountId
                ),
                instrument: aquaInstruments.first {
                    $0.symbol.caseInsensitiveCompare(
                        position.symbol
                    ) == .orderedSame
                },
                sessionOpen: sessionOpen(for: position.symbol),
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

    private func openFocusedPositionIfAvailable() {
        guard let focusedPositionID,
              !focusedPositionID.isEmpty else {
            return
        }

        guard let match = positionAccounts
            .flatMap({ $0.positions ?? [] })
            .first(where: {
                $0.positionId == focusedPositionID
            }) else {
            return
        }

        if let accountId = match.accountId {
            onAccountSelected(accountId)
        }
        selectedPosition = match
    }

    private func refreshSelectedPositionSnapshot() {
        guard let positionId = selectedPosition?.positionId,
              let live = allTradablePositions.first(where: {
                  $0.positionId == positionId
              }) else {
            return
        }

        selectedPosition = live
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

                if !tradableAccountIds.isEmpty {
                    ViewThatFits(in: .horizontal) {
                        Text(
                            "\(tradableAccountIds.count) active "
                            + (
                                tradableAccountIds.count == 1
                                    ? "account"
                                    : "accounts"
                            )
                        )
                        .lineLimit(1)

                        Label(
                            "\(tradableAccountIds.count)",
                            systemImage: "checkmark.circle.fill"
                        )
                        .lineLimit(1)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.10))
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
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
            .fixedSize(horizontal: false, vertical: true)
        }
        .layoutPriority(1)
    }

    private var refreshButton: some View {
        Button {
            Task {
                await refreshAquaAccountRoster()
            }
        } label: {
            Label("Refresh Aqua", systemImage: "arrow.clockwise")
                .font(.caption.bold())
        }
        .buttonStyle(.borderedProminent)
        .tint(isLoading ? Color.gray : AppTheme.softGold)
        .foregroundStyle(
            isLoading
                ? AppTheme.secondaryText
                : AppTheme.deepBlack
        )
        .disabled(isLoading)
    }

    @MainActor
    private func refreshAquaAccountRoster() async {
        instrumentError = nil

        do {
            let response = try await APIService.shared
                .discoverMatchTraderAccounts(
                    connectionId: connection?.connectionId,
                    accessToken: accessToken
                )

            guard response.success != false else {
                throw AquaActivityError.operationFailed(
                    response.summary
                        ?? response.headline
                        ?? "Aqua account discovery was not accepted."
                )
            }
        } catch {
            instrumentError = error.localizedDescription
        }

        await onRefresh()
    }

    private var accountScopePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(
                    "\(tradableConnectedAccounts.count) Active",
                    systemImage: "checkmark.shield.fill"
                )
                .font(.caption.bold())
                .foregroundStyle(.green)

                Spacer()

                refreshButton
            }

            Text(
                "Only accounts you marked Active appear here. Flat Active accounts remain selectable; Available and Ignored accounts stay in Account Command Center."
            )
            .font(.caption2)
            .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var accountPicker: some View {
        ScrollViewReader { reader in
            HStack(spacing: 8) {
                Button {
                    moveAccountSelection(by: -1, reader: reader)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.softGold)
                .foregroundStyle(AppTheme.deepBlack)

                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 10) {
                        ForEach(displayedAccounts) { account in
                            let accountId = accountIdentifier(account)

                            Button {
                                selectAccount(accountId)
                            } label: {
                                accountTile(
                                    account,
                                    isSelected: accountId
                                        == effectiveSelectedAccountId
                                )
                            }
                            .buttonStyle(.plain)
                            .id(accountId)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Button {
                    moveAccountSelection(by: 1, reader: reader)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.softGold)
                .foregroundStyle(AppTheme.deepBlack)
            }
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
            } else if let effectiveInstrument {
                LabeledContent(
                    "Selected Instrument",
                    value: instrumentLabel(effectiveInstrument)
                )
                .font(.caption)

                LabeledContent(
                    "Market Session",
                    value: effectiveInstrument.sessionOpen.map {
                        $0 ? "Open" : "Market Closed"
                    } ?? "Unknown"
                )
                .font(.caption)
                .foregroundStyle(
                    effectiveInstrument.sessionOpen == false
                        ? Color.orange
                        : AppTheme.primaryText
                )
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
                    || effectiveInstrument?.sessionOpen == false
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

    private var portfolioSummary: some View {
        let totalPnl = allTradablePositions
            .compactMap { $0.netProfit ?? $0.profit }
            .reduce(0, +)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Aqua Portfolio Now")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)

            HStack(spacing: 10) {
                summaryMetric(
                    "Accounts",
                    "\(tradableConnectedAccounts.count)"
                )
                summaryMetric(
                    "Open",
                    "\(allTradablePositions.count)"
                )
                summaryMetric(
                    "Broker P/L",
                    currency(totalPnl)
                )
            }

            Text(
                "Combined visibility only. Trade sizing, drawdown, and execution remain scoped to the selected account."
            )
            .font(.caption2)
            .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @MainActor
    private func loadEffectiveInstruments() async {
        guard let accountId = effectiveSelectedAccountId else {
            latestInstrumentRequestID = UUID()
            aquaInstruments = []
            selectedInstrumentSymbol = ""
            isLoadingInstruments = false
            return
        }

        let requestID = UUID()
        let startedAt = Date()
        latestInstrumentRequestID = requestID
        isLoadingInstruments = true
        instrumentError = nil
        debugInstrumentActivity(
            "start scope=instruments account=\(accountId)"
        )

        do {
            let response = try await APIService.shared
                .fetchMatchTraderInstruments(
                    accountId: accountId,
                    accessToken: accessToken
                )

            guard latestInstrumentRequestID == requestID,
                  effectiveSelectedAccountId == accountId else {
                return
            }

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

            onInstrumentsChanged(aquaInstruments)

            let nextSymbol: String

            if let current = aquaInstruments.first(where: {
                $0.symbol.caseInsensitiveCompare(
                    selectedMarketSymbol
                ) == .orderedSame
            }) {
                nextSymbol = current.symbol
            } else {
                nextSymbol = (
                    aquaInstruments.first?.symbol
                    ?? ""
                )
            }

            selectedInstrumentSymbol = nextSymbol

            // Account execution capability and the global analysis ticker are
            // intentionally independent. Loading an Aqua catalog must never
            // replace the market the trader chose to analyze.
            isLoadingInstruments = false
            debugInstrumentActivity(
                "complete scope=instruments account=\(accountId) elapsed=\(elapsedSeconds(since: startedAt)) count=\(aquaInstruments.count)"
            )
        } catch {
            guard latestInstrumentRequestID == requestID,
                  effectiveSelectedAccountId == accountId else {
                return
            }

            aquaInstruments = []
            onInstrumentsChanged([])
            selectedInstrumentSymbol = ""
            instrumentError = error.localizedDescription
            isLoadingInstruments = false
            let nsError = error as NSError
            debugInstrumentActivity(
                "\(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut ? "timeout" : "failure") scope=instruments account=\(accountId) elapsed=\(elapsedSeconds(since: startedAt)) error=\(nsError.domain)#\(nsError.code)"
            )
        }
    }

    private func elapsedSeconds(since start: Date) -> String {
        String(format: "%.2fs", Date().timeIntervalSince(start))
    }

    private func debugInstrumentActivity(_ message: String) {
#if DEBUG
        print("[AquaActivity] \(message)")
#endif
    }

    private func selectAccount(_ accountId: String?) {
        guard let accountId,
              tradableAccountIds.contains(accountId) else {
            latestInstrumentRequestID = UUID()
            aquaInstruments = []
            onInstrumentsChanged([])
            onAccountSelected(nil)
            return
        }

        latestInstrumentRequestID = UUID()
        aquaInstruments = []
        onInstrumentsChanged([])

        onAccountSelected(
            effectiveSelectedAccountId == accountId
                ? nil
                : accountId
        )
    }

    private func sessionOpen(for symbol: String) -> Bool? {
        aquaInstruments.first {
            $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame
        }?.sessionOpen
    }

    private func moveAccountSelection(
        by offset: Int,
        reader: ScrollViewProxy
    ) {
        guard !displayedAccounts.isEmpty else {
            return
        }

        let identifiers = displayedAccounts.compactMap(accountIdentifier)
        guard !identifiers.isEmpty else {
            return
        }

        guard let selectedAccountId = effectiveSelectedAccountId,
              let currentIndex = identifiers.firstIndex(
                  of: selectedAccountId
              ) else {
            let firstAccountId = identifiers[0]
            selectAccount(firstAccountId)
            withAnimation {
                reader.scrollTo(firstAccountId, anchor: .center)
            }
            return
        }

        let nextIndex = min(
            max(currentIndex + offset, 0),
            identifiers.count - 1
        )
        let nextAccountId = identifiers[nextIndex]

        selectAccount(nextAccountId)
        withAnimation {
            reader.scrollTo(nextAccountId, anchor: .center)
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
        ) ?? matchingRosterAccount(account)
        let positionCount = positionAccount?.effectivePositionCount ?? 0
        let knownPositions = positionAccount?.positions ?? []
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

            ForEach(
                Array(knownPositions.prefix(2).enumerated()),
                id: \.offset
            ) { _, position in
                Text(
                    "\(position.symbol.uppercased()) "
                        + "\((position.officialSide ?? position.side ?? "—").uppercased())"
                )
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
            }

            if knownPositions.count > 2 {
                Text("+\(knownPositions.count - 2) more")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.mutedText)
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

            Text("Position \(position.positionId ?? "—")")
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)

            Button {
                openPositionManager(position)
            } label: {
                Label(
                    "Manage Live Trade",
                    systemImage: "slider.horizontal.3"
                )
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AppTheme.softGold.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            openPositionManager(position)
        }
        .accessibilityAction(named: "Manage Live Trade") {
            openPositionManager(position)
        }
    }

    private func isTerminalAccountStatus(
        _ value: String?
    ) -> Bool {
        guard let value else {
            return false
        }

        let normalized = value
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        return [
            "archived",
            "blocked",
            "breached",
            "closed",
            "disabled",
            "failed",
            "inactive",
            "passed",
            "payment_requested",
            "terminated",
            "violated",
        ].contains(normalized)
    }

    private func openPositionManager(
        _ position: MatchTraderLivePosition
    ) {
            // Position payloads can identify the account by UUID while the
            // workspace/sizing routes use the trading login. Propagate the
            // canonical connected-account identifier to the parent so the
            // next Trader OS request stays scoped to the same Aqua account.
            let accountId = positionSelectionAccountId(position)

            onPositionSelected(
                position.symbol,
                accountId,
                position.side,
                position.id
            )
            selectedPosition = position
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

    private func matchingRosterAccount(
        _ account: MatchTraderConnectedAccount
    ) -> MatchTraderPositionAccount? {
        let identifiers = connectedAccountIdentifiers(account)

        return rosterAccounts.first { rosterAccount in
            !identifiers.isDisjoint(
                with: positionAccountIdentifiers(rosterAccount)
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

    private func positionSelectionAccountId(
        _ position: MatchTraderLivePosition
    ) -> String {
        let raw = position.accountId
            ?? effectiveSelectedAccountId
            ?? ""

        guard !raw.isEmpty else {
            return ""
        }

        let normalized = normalizedAccountIdentifier(raw)

        if let match = connectedAccounts.first(where: {
            connectedAccountIdentifiers($0).contains(normalized)
        }), let canonical = accountIdentifier(match) {
            return canonical
        }

        return raw
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
    @State private var preTradeContext: PreTradeContextResponse?
    @State private var isLoadingRisk = true
    @State private var isWorking = false
    @State private var showingConfirmation = false
    @State private var errorMessage: String?
    @State private var entryCompleted = false

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
            && !entryCompleted
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
                            .appTextField()

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
                    if let context = preTradeContext {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Trader OS Suggested Levels")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.softGold)

                            HStack(spacing: 12) {
                                protectionLevel("S1", context.support1 ?? context.supportLevel)
                                protectionLevel("S2", context.support2)
                                protectionLevel("R1", context.resistance1 ?? context.resistanceLevel)
                                protectionLevel("R2", context.resistance2)
                            }

                            Button("Apply Suggested \(side) Protection") {
                                applySuggestedProtection()
                            }
                            .buttonStyle(.bordered)

                            Text(
                                "These levels are recommendations from the current broker-backed setup. Review and adjust them before submitting; they never place an order automatically."
                            )
                            .font(.caption2)
                            .foregroundStyle(AppTheme.secondaryText)
                        }
                    }

                    TextField("Stop Loss", text: $stopLossText)
                        .appTextField()
                    TextField("Take Profit", text: $takeProfitText)
                        .appTextField()
                    TextField(
                        "Trailing Distance (0 = off)",
                        text: $trailingDistanceText
                    )
                    .appTextField()
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
                    Section(
                        entryCompleted
                            ? "Entry Opened — Protection Required"
                            : "Could Not Open Position"
                    ) {
                        Text(errorMessage)
                            .foregroundStyle(.red)

                        if entryCompleted {
                            Text(
                                "The market entry already exists. Close this sheet, refresh the account, and manage that position. Submitting again would create a duplicate trade."
                            )
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .foregroundStyle(.primary)
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
                await loadProtectionContext()
            }
            .onChange(of: side) {
                applySuggestedProtection()
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
    private func loadProtectionContext() async {
        do {
            preTradeContext = try await APIService.shared
                .fetchPreTradeContext(
                    PreTradeContextRequest(
                        symbol: symbol,
                        direction: side == "BUY" ? "long" : "short",
                        broker: "Aqua Funding",
                        accountKey: accountId,
                        useMatchTraderQuote: true,
                        matchTraderAccountID: accountId,
                        includeMatchTraderTimeframes: true,
                        accountSize: balanceHealth?.equity
                            ?? balanceHealth?.balance,
                        plannedSize: volume
                    ),
                    accessToken: accessToken
                )

            applySuggestedProtection()
        } catch {
            preTradeContext = nil
        }
    }

    @MainActor
    private func applySuggestedProtection() {
        guard let context = preTradeContext else {
            return
        }

        let suggestedStop: Double?
        let suggestedTarget: Double?

        if side == "SELL" {
            suggestedStop = context.resistance1
                ?? context.resistanceLevel
                ?? context.resistance2
            suggestedTarget = context.support1
                ?? context.supportLevel
                ?? context.target1
        } else {
            suggestedStop = context.support1
                ?? context.supportLevel
                ?? context.support2
            suggestedTarget = context.resistance1
                ?? context.resistanceLevel
                ?? context.target1
        }

        if let suggestedStop {
            stopLossText = format(suggestedStop)
        }

        if let suggestedTarget {
            takeProfitText = format(suggestedTarget)
        }
    }

    private func protectionLevel(
        _ title: String,
        _ value: Double?
    ) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.secondaryText)
            Text(format(value))
                .font(.caption.bold())
                .foregroundStyle(AppTheme.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    @MainActor
    private func reviewOrder() {
        errorMessage = nil

        guard !entryCompleted else {
            errorMessage = (
                "This entry already opened. Do not submit it again; " +
                "manage the new live position instead."
            )
            return
        }

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
            let requestedProtection = (
                Double(stopLossText) != nil
                    || Double(takeProfitText) != nil
                    || trailingDistance > 0
            )
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


            if requestedProtection,
               response.protectionApplied != true {
                entryCompleted = true
                errorMessage = (
                    response.protectionMessage
                        ?? "ENTRY OPENED, but Aqua has not confirmed its protection. Do not submit again; manage the new live position."
                )
                await onComplete()
                return
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

private struct AquaPositionTarget: Identifiable {
    let position: MatchTraderLivePosition
    let accountId: String
    let connectionId: String?

    var id: String {
        AquaProtectionTargetIdentity(
            provider: position.provider ?? "match_trader",
            connectionID: connectionId,
            accountID: accountId,
            positionID: position.positionId ?? position.id
        ).canonicalKey
    }
}

private struct AquaProtectionOperationResult: Identifiable {
    let id = UUID()
    let provider: String
    let connectionId: String?
    let accountId: String
    let positionId: String
    let symbol: String
    let requestedStop: Double?
    let state: AquaProtectionResultState
    let detail: String

    init(
        target: AquaPositionTarget,
        requestedStop: Double?,
        state: AquaProtectionResultState,
        detail: String
    ) {
        provider = target.position.provider ?? "match_trader"
        connectionId = target.connectionId
        accountId = target.accountId
        positionId = target.position.positionId ?? target.position.id
        symbol = target.position.symbol
        self.requestedStop = requestedStop
        self.state = state
        self.detail = detail
    }

    static func failure(
        target: AquaPositionTarget,
        requestedStop: Double? = nil,
        detail: String
    ) -> AquaProtectionOperationResult {
        .init(
            target: target,
            requestedStop: requestedStop,
            state: .failed,
            detail: detail
        )
    }

    var headline: String {
        let marker = state == .protected
            ? "✓"
            : (state == .verificationPending ? "•" : "✗")
        let stop = requestedStop.map {
            " stop \($0.formatted(.number.precision(.fractionLength(0...5))))"
        } ?? ""
        return "\(marker) \(symbol) • \(accountId) • \(positionId)\(stop)"
    }
}

private struct AquaPositionManagementSheet: View {
    @Environment(\.dismiss) private var dismiss

    let position: MatchTraderLivePosition
    let matchingTargets: [AquaPositionTarget]
    let portfolioTargets: [AquaPositionTarget]
    let accountId: String
    let accountTitle: String
    let instrument: MatchTraderInstrument?
    let sessionOpen: Bool?
    let accessToken: String
    let onComplete: () async -> Void

    @State private var stopLossText = ""
    @State private var takeProfitText = ""
    @State private var trailingDistanceText = ""
    @State private var applyStopLoss = false
    @State private var applyTakeProfit = false
    @State private var applyTrailingStop = false
    @State private var protectionScope: AquaProtectionScope = .position
    @State private var stopPercent = 1.0
    @State private var targetPercent = 2.0
    @State private var closePercent = 25
    @State private var pendingAction: AquaPositionAction?
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var confirmationMessage: String?
    @State private var operationResults: [AquaProtectionOperationResult] = []
    @FocusState private var protectionFieldFocused: Bool

    private var partialCloseChoices: [PartialCloseChoice] {
        guard let totalVolume = position.volume,
              let minimumVolume = instrument?.minimumVolume,
              minimumVolume > 0,
              let volumeStep = instrument?.volumeStep,
              volumeStep > 0,
              totalVolume >= minimumVolume + volumeStep else {
            return []
        }

        var seenVolumes = Set<String>()

        return [25, 50, 75].compactMap { percent in
            let requestedVolume = (
                totalVolume * Double(percent) / 100
            )
            let stepUnits = (
                requestedVolume / volumeStep
            ).rounded()
            let closeVolume = stepUnits * volumeStep
            let remainingVolume = totalVolume - closeVolume
            let identity = String(
                format: "%.12f",
                closeVolume
            )

            guard closeVolume >= minimumVolume,
                  closeVolume < totalVolume,
                  remainingVolume >= minimumVolume,
                  seenVolumes.insert(identity).inserted else {
                return nil
            }

            return PartialCloseChoice(
                percent: percent,
                volume: closeVolume
            )
        }
    }

    private var partialCloseUnavailableMessage: String {
        guard let minimumVolume = instrument?.minimumVolume,
              let volumeStep = instrument?.volumeStep else {
            return (
                "Aqua did not provide this instrument's minimum " +
                "volume and step. Partial close is disabled safely; " +
                "use Full Close instead."
            )
        }

        return (
            "This position cannot leave Aqua's minimum " +
            "\(format(minimumVolume)) volume while using its " +
            "\(format(volumeStep)) step. Use Full Close instead."
        )
    }

    private var partialCloseStepMessage: String {
        guard let volumeStep = instrument?.volumeStep else {
            return "The exact broker-supported reduction will be submitted."
        }

        return (
            "Aqua reports a \(format(volumeStep)) volume step for " +
            "\(position.symbol). The volume shown is the exact " +
            "reduction that will be submitted."
        )
    }

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

                    if sessionOpen == false {
                        Label(
                            "Aqua reports this instrument's trading session is closed. Quotes may still move, but entries, exits, and protection changes are unavailable until Aqua reopens the session.",
                            systemImage: "clock.badge.exclamationmark"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }

                Section("Protection") {
                    Toggle(
                        "Apply stop loss",
                        isOn: $applyStopLoss
                    )

                    if applyStopLoss {
                        TextField(
                            "Stop Loss",
                            text: $stopLossText
                        )
                        .appTextField()
                        .focused($protectionFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { dismissKeyboard() }
                    }

                    Toggle(
                        "Apply take profit",
                        isOn: $applyTakeProfit
                    )

                    if applyTakeProfit {
                        TextField(
                            "Take Profit",
                            text: $takeProfitText
                        )
                        .appTextField()
                        .focused($protectionFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { dismissKeyboard() }
                    }

                    Toggle(
                        "Apply trailing stop",
                        isOn: $applyTrailingStop
                    )

                    if applyTrailingStop {
                        TextField(
                            "Trailing Distance (0 = off)",
                            text: $trailingDistanceText
                        )
                        .appTextField()
                        .focused($protectionFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { dismissKeyboard() }
                    }

                    Stepper(
                        "Stop distance: \(stopPercent.formatted(.number.precision(.fractionLength(1))))%",
                        value: $stopPercent,
                        in: 0.1...25,
                        step: 0.5
                    )

                    Button("Set Stop \(stopPercent.formatted(.number.precision(.fractionLength(1))))% Away") {
                        setProtectionPrice(
                            percent: stopPercent,
                            isStop: true
                        )
                    }

                    Stepper(
                        "Target distance: \(targetPercent.formatted(.number.precision(.fractionLength(1))))%",
                        value: $targetPercent,
                        in: 0.1...50,
                        step: 0.5
                    )

                    Button("Set Target \(targetPercent.formatted(.number.precision(.fractionLength(1))))% Away") {
                        setProtectionPrice(
                            percent: targetPercent,
                            isStop: false
                        )
                    }

                    if let stopLoss = Double(stopLossText),
                       let estimate = estimatedPnL(at: stopLoss) {
                        LabeledContent(
                            "Estimated result at stop",
                            value: money(estimate)
                        )
                    }

                    if let takeProfit = Double(takeProfitText),
                       let estimate = estimatedPnL(at: takeProfit) {
                        LabeledContent(
                            "Estimated result at target",
                            value: money(estimate)
                        )
                    }

                    Picker("Protection Scope", selection: $protectionScope) {
                        Text("This Position")
                            .tag(AquaProtectionScope.position)
                        if matchingTargets.count > 1 {
                            Text("All Open \(position.symbol) Positions")
                                .tag(AquaProtectionScope.symbol)
                        }
                        if portfolioTargets.count > 1 {
                            Text("Protect All Eligible Aqua Positions")
                                .tag(AquaProtectionScope.portfolio)
                        }
                    }

                    if protectionScope == .portfolio {
                        Text(
                            "Each position receives its own \(stopPercent.formatted(.number.precision(.fractionLength(1))))% stop from its current broker price. Different instruments never share one absolute stop price."
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    } else if protectionScope == .symbol {
                        Text(
                            "The entered protection values apply only to open \(position.symbol) positions. Every account is updated and verified separately."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Button("Apply Selected Protection") {
                        dismissKeyboard()
                        Task {
                            await execute(.modifyProtection)
                        }
                    }
                    .disabled(
                        !applyStopLoss
                            && !applyTakeProfit
                            && !applyTrailingStop
                    )

                    Button("Confirm Move to Break Even") {
                        dismissKeyboard()
                        pendingAction = .breakEven
                    }
                }

                Section("Reduce Position") {
                    if partialCloseChoices.isEmpty {
                        Text(
                            partialCloseUnavailableMessage
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    } else {
                        Picker("Close", selection: $closePercent) {
                            ForEach(partialCloseChoices) { choice in
                                Text(
                                    "\(choice.percent)% (\(format(choice.volume)))"
                                )
                                .tag(choice.percent)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(
                            partialCloseStepMessage
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Button("Review Partial Close") {
                        dismissKeyboard()
                        pendingAction = .partialClose(closePercent)
                    }
                    .disabled(
                        partialCloseChoices.isEmpty
                            || sessionOpen == false
                    )
                }

                Section("Close Position") {
                    Button(
                        "Review Full Close",
                        role: .destructive
                    ) {
                        dismissKeyboard()
                        pendingAction = .fullClose
                    }
                    .disabled(sessionOpen == false)

                    if matchingTargets.count > 1 {
                        Button(
                            "Review Close All \(matchingTargets.count) \(position.symbol) Positions",
                            role: .destructive
                        ) {
                            dismissKeyboard()
                            pendingAction = .fullCloseAll
                        }
                        .disabled(sessionOpen == false)

                        Text(
                            "This closes every broker-confirmed \(position.symbol) position shown across your Active Aqua accounts. Each account is submitted and verified separately."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Section("Could Not Complete Action") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if let confirmationMessage {
                    Section("Broker Confirmation") {
                        Label(
                            confirmationMessage,
                            systemImage: "checkmark.shield.fill"
                        )
                        .foregroundStyle(.green)
                    }
                }

                if !operationResults.isEmpty {
                    Section("Position Results") {
                        ForEach(operationResults) { result in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.headline)
                                Text(result.detail)
                                    .foregroundStyle(.secondary)
                            }
                                .font(.caption)
                                .foregroundStyle(
                                    result.state == .protected
                                        ? .green
                                        : (result.state == .verificationPending ? .orange : .red)
                                )
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Manage Aqua Position")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismissKeyboard()
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        dismissKeyboard()
                    }
                }
            }
            .disabled(isWorking)
            .onAppear {
                stopLossText = input(position.stopLoss)
                takeProfitText = input(position.takeProfit)
                trailingDistanceText = input(
                    position.trailingDistance
                )
                applyStopLoss = position.stopLoss != nil
                applyTakeProfit = position.takeProfit != nil
                applyTrailingStop = (
                    position.trailingDistance ?? 0
                ) > 0
                if let first = partialCloseChoices.first,
                   !partialCloseChoices.contains(where: {
                       $0.percent == closePercent
                   }) {
                    closePercent = first.percent
                }
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
        guard position.positionId != nil,
              !accountId.isEmpty else {
            errorMessage = "The live Aqua position or account ID is missing."
            pendingAction = nil
            return
        }

        if sessionOpen == false,
           action.isExecutionAction {
            errorMessage = (
                "Aqua reports the \(position.symbol) trading session is closed. The position remains open; try again after the broker reopens the session."
            )
            pendingAction = nil
            return
        }

        let stopLoss = applyStopLoss
            ? Double(stopLossText)
            : nil
        let takeProfit = applyTakeProfit
            ? Double(takeProfitText)
            : nil
        let trailingDistance = applyTrailingStop
            ? Double(trailingDistanceText)
            : nil

        if action == .modifyProtection,
           !applyStopLoss,
           !applyTakeProfit,
           !applyTrailingStop {
            errorMessage = (
                "Select at least one protection control."
            )
            pendingAction = nil
            return
        }

        if action == .modifyProtection,
           protectionScope == .portfolio,
           (!applyStopLoss || applyTakeProfit || applyTrailingStop) {
            errorMessage = (
                "Portfolio-wide protection currently applies an independently calculated stop loss only. Turn on Stop Loss and turn off Target/Trailing Stop for this scope."
            )
            pendingAction = nil
            return
        }

        if action == .modifyProtection,
           (applyStopLoss
                && protectionScope != .portfolio
                && stopLoss == nil)
            || (applyTakeProfit && takeProfit == nil)
            || (applyTrailingStop && trailingDistance == nil) {
            errorMessage = (
                "Every selected protection control needs a valid number."
            )
            pendingAction = nil
            return
        }

        if let trailingDistance,
           trailingDistance < 0 {
            errorMessage = "Trailing distance cannot be negative."
            pendingAction = nil
            return
        }

        isWorking = true
        errorMessage = nil
        confirmationMessage = nil
        operationResults = []

        defer {
            isWorking = false
            pendingAction = nil
        }

        do {
            let selectedTarget = AquaPositionTarget(
                position: position,
                accountId: accountId,
                connectionId: portfolioTargets.first {
                    $0.position.positionId == position.positionId
                        && $0.accountId == accountId
                }?.connectionId
            )
            let scopedTargets: [AquaPositionTarget]
            if action == .fullCloseAll {
                scopedTargets = matchingTargets
            } else if action == .modifyProtection {
                switch protectionScope {
                case .position:
                    scopedTargets = [selectedTarget]
                case .symbol:
                    scopedTargets = matchingTargets
                case .portfolio:
                    scopedTargets = portfolioTargets
                }
            } else {
                scopedTargets = [selectedTarget]
            }

            // Capture and deduplicate the immutable batch before the first
            // broker request. Subsequent UI/account changes cannot alter it.
            let uniqueIndices = AquaProtectionBatchPolicy.uniqueIndices(
                for: scopedTargets.map {
                    AquaProtectionTargetIdentity(
                        provider: $0.position.provider ?? "match_trader",
                        connectionID: $0.connectionId,
                        accountID: $0.accountId,
                        positionID: $0.position.positionId ?? $0.position.id
                    )
                }
            )
            let targets = uniqueIndices.map { scopedTargets[$0] }

            var responses: [
                MatchTraderPositionManagementResponse
            ] = []

            let batchResults = await AquaProtectionBatchPolicy.runSerial(
                captured: targets
            ) { target -> (
                AquaProtectionOperationResult,
                MatchTraderPositionManagementResponse?
            ) in
                let targetPosition = target.position
                guard let targetPositionId = targetPosition.positionId else {
                    let failure = "\(targetPosition.symbol): missing broker position ID"
                    return (
                        .failure(target: target, detail: failure),
                        nil
                    )
                }

                let targetAccountId = target.accountId

                guard !targetAccountId.isEmpty else {
                    let failure = "\(targetPosition.symbol): missing Aqua account identity"
                    return (
                        .failure(target: target, detail: failure),
                        nil
                    )
                }

                let targetStopLoss: Double?
                if action == .modifyProtection,
                   protectionScope == .portfolio {
                    targetStopLoss = AquaProtectionBatchPolicy.stopPrice(
                        for: AquaProtectionStopInput(
                            currentPrice: targetPosition.currentPrice,
                            openPrice: targetPosition.openPrice,
                            side: targetPosition.officialSide ?? targetPosition.side
                        ),
                        percent: stopPercent
                    )
                    guard targetStopLoss != nil else {
                        return (
                            .failure(
                                target: target,
                                detail: "No safe current price/side was available to calculate this position's stop."
                            ),
                            nil
                        )
                    }
                } else {
                    targetStopLoss = stopLoss
                }

                do {
                    let response = try await APIService.shared.manageMatchTraderPosition(
                        MatchTraderPositionManagementRequest(
                            broker: "Aqua Funding",
                            accountId: targetAccountId,
                            positionId: targetPositionId,
                            action: action.apiAction,
                            stopLoss: action == .modifyProtection
                                ? targetStopLoss
                                : nil,
                            takeProfit: action == .modifyProtection
                                && protectionScope != .portfolio
                                ? takeProfit
                                : nil,
                            trailingDistance: action == .modifyProtection
                                && protectionScope != .portfolio
                                ? trailingDistance
                                : nil,
                            volume: nil,
                            closePercent: action.closePercent,
                            userConfirmed: true
                        ),
                        accessToken: accessToken
                    )

                    guard response.success == true else {
                        let failure = (
                            "\(targetAccountId)/\(targetPositionId): "
                            + (response.message ?? response.warnings ?? "Aqua rejected protection")
                        )
                        return (
                            .failure(
                                target: target,
                                requestedStop: targetStopLoss,
                                detail: failure
                            ),
                            nil
                        )
                    }
                    return (
                        .init(
                            target: target,
                            requestedStop: targetStopLoss,
                            state: response.verification?.verified == true
                                ? .protected
                                : .verificationPending,
                            detail: response.verification?.message
                                ?? (response.verification?.verified == true
                                    ? "Broker confirmed."
                                    : "Accepted; broker confirmation is pending.")
                        ),
                        response
                    )
                } catch {
                    let failure = "\(targetAccountId)/\(targetPositionId): \(error.localizedDescription)"
                    return (
                        .failure(
                            target: target,
                            requestedStop: targetStopLoss,
                            detail: failure
                        ),
                        nil
                    )
                }
            }
            operationResults = batchResults.map(\.0)
            responses = batchResults.compactMap(\.1)

            await onComplete()

            if action == .modifyProtection {
                let summary = AquaProtectionBatchSummary(
                    states: operationResults.map(\.state)
                )
                let completionTitle = protectionScope == .portfolio
                    ? "Protect All Complete"
                    : "Protection Update Complete"
                confirmationMessage = (
                    "\(completionTitle) — \(summary.total) eligible, "
                    + "\(summary.protected) protected, \(summary.failed) failed, "
                    + "\(summary.verificationPending) verification pending."
                )
                if targets.count == 1,
                   let verified = responses.first?.verification,
                   verified.verified == true {
                    stopLossText = input(verified.stopLoss)
                    takeProfitText = input(verified.takeProfit)
                    trailingDistanceText = input(
                        verified.trailingDistance
                    )
                }
                dismissKeyboard()
            } else if action == .breakEven {
                confirmationMessage = operationResults.first?.detail
                    ?? "Aqua processed the break-even request."
                dismissKeyboard()
            } else {
                dismissKeyboard()
                dismiss()
            }
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

    private func setProtectionPrice(
        percent: Double,
        isStop: Bool
    ) {
        guard let currentPrice = position.currentPrice
                ?? position.openPrice else {
            return
        }

        let normalizedSide = (
            position.officialSide
                ?? position.side
                ?? ""
        ).lowercased()
        let isLong = normalizedSide.contains("buy")
            || normalizedSide.contains("long")

        let direction: Double
        if isStop {
            applyStopLoss = true
            direction = isLong ? -1 : 1
        } else {
            applyTakeProfit = true
            direction = isLong ? 1 : -1
        }

        let price = currentPrice * (
            1 + direction * percent / 100
        )

        if isStop {
            stopLossText = input(price)
        } else {
            takeProfitText = input(price)
        }
        dismissKeyboard()
    }

    private func estimatedPnL(
        at targetPrice: Double
    ) -> Double? {
        guard let currentPrice = position.currentPrice,
              let openPrice = position.openPrice,
              let currentProfit = position.profit
                ?? position.netProfit,
              abs(currentPrice - openPrice) > 0.000001 else {
            return nil
        }

        let moneyPerPoint = currentProfit
            / (currentPrice - openPrice)

        return moneyPerPoint * (
            targetPrice - openPrice
        )
    }

    private func money(_ value: Double) -> String {
        value.formatted(
            .currency(code: "USD")
        )
    }

    private func dismissKeyboard() {
        protectionFieldFocused = false
#if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
#endif
    }
}

private struct PartialCloseChoice: Identifiable {
    let percent: Int
    let volume: Double

    var id: Int {
        percent
    }
}

private enum AquaPositionAction: Equatable {
    case modifyProtection
    case breakEven
    case partialClose(Int)
    case fullClose
    case fullCloseAll

    var apiAction: String {
        switch self {
        case .modifyProtection:
            return "modify_sl_tp"
        case .breakEven:
            return "move_to_break_even"
        case .partialClose:
            return "close_percent"
        case .fullClose, .fullCloseAll:
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
            return "Confirm Live Protection Change"
        case .breakEven:
            return "Move Stop to Break Even?"
        case .partialClose(let percent):
            return "Close \(percent)% of This Position?"
        case .fullClose:
            return "Close the Entire Position?"
        case .fullCloseAll:
            return "Close Every Open Position for This Symbol?"
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
        case .fullCloseAll:
            return "Close All Symbol Positions"
        }
    }

    var isDestructive: Bool {
        switch self {
        case .partialClose, .fullClose, .fullCloseAll:
            return true
        default:
            return false
        }
    }

    func message(
        symbol: String,
        account: String
    ) -> String {
        switch self {
        case .fullCloseAll:
            return "This sends a live full-close request for every visible \(symbol) position across your Active Aqua accounts. Each close is verified separately."
        default:
            return "This will send a live \(symbol) position change to \(account) through Aqua Funding."
        }
    }

    var isExecutionAction: Bool {
        true
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
