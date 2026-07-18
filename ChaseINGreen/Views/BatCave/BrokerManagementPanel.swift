//
//  BrokerManagementPanel.swift
//  ChaseINGreen
//
//  By: Otis Young II
// --------------------------------------------------------------
// PURPOSE
// --------------------------------------------------------------
// ✅ Bat Cave broker management panel
// ✅ Each broker/company keeps its own connection architecture
// ✅ Aqua Funding uses username/password through its backend adapter
// ✅ Match-Trader remains Aqua Funding's platform provider
// ✅ Trade The Pool remains isolated from Aqua Funding
// ✅ IBKR keeps its official session/gateway architecture
// ✅ ChaseINGreen remains the unified portfolio and Trader OS layer
//
// IMPORTANT RULES
// --------------------------------------------------------------
// ✅ No Match-Trader server URL appears in Swift
// ✅ No broker ID appears in Swift
// ✅ No access-token field appears in the user interface
// ✅ No refresh-token field appears in the user interface
// ✅ No tradingApiToken appears in Swift
// ✅ Aqua credentials are never reused for Trade The Pool
// ✅ Other brokers receive their own adapters
// ✅ No live orders are placed from this view
// --------------------------------------------------------------

import SwiftUI

struct BrokerManagementPanel: View {

    private enum AquaCredentialField: Hashable {
        case username
        case password
    }

    let selectedSymbol: String
    let accessToken: String
    let onSyncComplete: () async -> Void

    @State private var selectedLane: BrokerLane = .aqua

    // MARK: - Aqua Funding Login

    @State private var aquaUsername = ""
    @State private var aquaPassword = ""
    @State private var aquaAccountLabel = ""
    @FocusState private var focusedAquaCredential: AquaCredentialField?

    @State private var aquaConnection: MatchTraderConnectionFeatures?
    @State private var selectedAquaAccountId: String?
    @State private var aquaSyncedAccounts: [BrokerAccountResponse] = []
    @State private var aquaBalanceHealth: [MatchTraderBalanceHealthFeatures] = []
    @State private var didRestoreAquaConnection = false

    // MARK: - UI State

    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            lanePicker
            activeLane

            if let statusMessage {
                statusBanner(
                    message: statusMessage,
                    systemImage: "checkmark.circle.fill",
                    color: .green
                )
            }

            if let errorMessage {
                statusBanner(
                    message: errorMessage,
                    systemImage: "exclamationmark.triangle.fill",
                    color: .red
                )
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        }
        .task {
            await restoreAquaConnection()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    focusedAquaCredential = nil
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                "Broker Management",
                systemImage: "building.columns.fill"
            )
            .font(.title2.bold())
            .foregroundStyle(AppTheme.softGold)

            Text(
                "Connect each account through its own official broker flow. "
                + "ChaseINGreen combines the accounts afterward for portfolio analysis, "
                + "Trader OS, coaching, risk controls, calendars, and performance comparisons."
            )
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryText)
        }
    }

    // MARK: - Lane Picker

    private var lanePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BrokerLane.allCases) { lane in
                    Button {
                        selectedLane = lane
                        clearMessages()
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(statusColor(for: lane))
                                .frame(width: 9, height: 9)

                            Text(lane.title)
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            selectedLane == lane
                                ? AppTheme.softGold.opacity(0.18)
                                : Color.secondary.opacity(0.08)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Active Lane

    @ViewBuilder
    private var activeLane: some View {
        switch selectedLane {
        case .aqua:
            aquaLane

        case .tradeThePool:
            tradeThePoolLane

        case .ibkr:
            ibkrLane

        case .webull,
             .fidelity,
             .robinhood,
             .tradeStation:
            comingSoonLane(selectedLane)
        }
    }

    // MARK: - Aqua Funding

    private var aquaLane: some View {
        brokerCard(
            title: "Aqua Funding",
            subtitle: "Aqua Funding is the broker/company. Match-Trader is the platform provider used by this connection.",
            systemImage: "waveform.path.ecg"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                architectureNotice(
                    title: "Aqua Funding connection",
                    message: "Enter only the same username or email and password used for your Aqua Funding Match-Trader account. Platform URLs, broker IDs, cookies, and trading tokens stay inside the ChaseINGreen backend."
                )

                credentialTextField(
                    "Aqua Funding / Match-Trader Email",
                    text: $aquaUsername,
                    contentType: .username
                )
                .focused(
                    $focusedAquaCredential,
                    equals: .username
                )
                .submitLabel(.next)
                .onSubmit {
                    focusedAquaCredential = .password
                }

                secureCredentialField(
                    "Aqua Funding / Match-Trader Password",
                    text: $aquaPassword
                )
                .focused(
                    $focusedAquaCredential,
                    equals: .password
                )
                .submitLabel(.done)
                .onSubmit {
                    focusedAquaCredential = nil
                }
                .onChange(of: aquaPassword) { oldValue, newValue in
                    let looksLikeAutoFillOrPaste = (
                        oldValue.isEmpty
                        && newValue.count > 1
                        && !aquaUsername.isEmpty
                    )

                    if looksLikeAutoFillOrPaste {
                        focusedAquaCredential = nil
                    }
                }

                input(
                    "Account Label Optional",
                    text: $aquaAccountLabel
                )

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        aquaConnectionButtons
                    }

                    VStack(spacing: 10) {
                        aquaConnectionButtons
                    }
                }

                if let connection = aquaConnection {
                    aquaConnectionCard(connection)
                }
            }
        }
    }

    private func connectAqua() async throws {
        focusedAquaCredential = nil

        let cleanUsername = aquaUsername.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let cleanPassword = aquaPassword.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanUsername.isEmpty else {
            throw BrokerManagementError.validation(
                "Enter your Aqua Funding username or email."
            )
        }

        guard !cleanPassword.isEmpty else {
            throw BrokerManagementError.validation(
                "Enter your Aqua Funding password."
            )
        }

        let result = try await APIService.shared.loginMatchTrader(
            MatchTraderLoginRequest(
                login: cleanUsername,
                password: cleanPassword,
                broker: "Aqua Funding",
                accountLabel: normalizedOptional(aquaAccountLabel)
            ),
            accessToken: accessToken
        )

        guard result.success != false else {
            throw BrokerManagementError.connection(
                result.summary
                    ?? result.headline
                    ?? "Aqua Funding connection failed."
            )
        }

        aquaConnection = result.connection
        aquaSyncedAccounts = []
        aquaBalanceHealth = []

        let returnedAccounts = result.connection?.accounts ?? []
        let returnedAccountIds = Set(
            returnedAccounts.compactMap {
                $0.tradingAccountId
                    ?? $0.accountUUID
                    ?? $0.accountName
            }
        )

        if selectedAquaAccountId == nil
            || !returnedAccountIds.contains(selectedAquaAccountId ?? "") {
            selectedAquaAccountId = returnedAccounts.first.flatMap {
                $0.tradingAccountId
                    ?? $0.accountUUID
                    ?? $0.accountName
            }
        }

        aquaPassword = ""

        let connectedMessage = result.summary
            ?? result.headline
            ?? "Aqua Funding connected."

        statusMessage = connectedMessage
            + " Open Aqua Trader when you are ready to load live accounts and positions."

        await onSyncComplete()
    }

    @MainActor
    private func restoreAquaConnection() async {
        guard !didRestoreAquaConnection else {
            return
        }

        didRestoreAquaConnection = true

        do {
            let health = try await APIService.shared
                .fetchMatchTraderAuthHealth(
                    accessToken: accessToken
                )

            guard health.connected == true,
                  let connection = health.connection else {
                return
            }

            aquaConnection = connection

            let restoredAccounts = connection.accounts
                ?? health.accounts
                ?? []

            selectedAquaAccountId = restoredAccounts.first.flatMap {
                $0.tradingAccountId
                    ?? $0.accountUUID
                    ?? $0.accountName
            }

            statusMessage = health.message
                ?? "Aqua Funding connection restored."
        } catch {
            if aquaConnection != nil {
                errorMessage = (
                    "Aqua Funding is connected, but its live account data "
                    + "could not be restored: "
                    + error.localizedDescription
                )
            }
        }
    }

    @ViewBuilder
    private var aquaConnectionButtons: some View {
        brokerButton(
            aquaConnection == nil
                ? "Connect Aqua Funding"
                : "Reconnect Aqua Funding"
        ) {
            try await connectAqua()
        }
    }

    @MainActor
    private func syncAquaAccounts(
        accountId: String?
    ) async throws {
        let result = try await APIService.shared.syncMatchTraderAccounts(
            MatchTraderSyncRequest(
                broker: "Aqua Funding",
                accountId: accountId,
                symbols: [selectedSymbol.uppercased()]
            ),
            accessToken: accessToken
        )

        guard result.success != false else {
            throw BrokerManagementError.connection(
                result.summary
                    ?? result.headline
                    ?? "Aqua Funding account sync failed."
            )
        }

        mergeSyncedAccounts(result.accounts ?? [])
        mergeBalanceHealth(result.balanceHealth ?? [])

        statusMessage = result.summary
            ?? result.headline
            ?? "Aqua Funding account data synchronized."

        await onSyncComplete()
    }

    @MainActor
    private func mergeSyncedAccounts(
        _ updates: [BrokerAccountResponse]
    ) {
        for account in updates {
            if let index = aquaSyncedAccounts.firstIndex(
                where: { $0.accountId == account.accountId }
            ) {
                aquaSyncedAccounts[index] = account
            } else {
                aquaSyncedAccounts.append(account)
            }
        }
    }

    @MainActor
    private func mergeBalanceHealth(
        _ updates: [MatchTraderBalanceHealthFeatures]
    ) {
        for health in updates {
            if let index = aquaBalanceHealth.firstIndex(
                where: { $0.accountId == health.accountId }
            ) {
                aquaBalanceHealth[index] = health
            } else {
                aquaBalanceHealth.append(health)
            }
        }
    }

    @ViewBuilder
    private func aquaConnectionCard(
        _ connection: MatchTraderConnectionFeatures
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            HStack {
                Label(
                    connection.authenticated == true
                        ? "Authenticated"
                        : "Connection received",
                    systemImage: connection.authenticated == true
                        ? "checkmark.shield.fill"
                        : "shield"
                )
                .font(.caption.bold())
                .foregroundStyle(
                    connection.authenticated == true
                        ? Color.green
                        : AppTheme.softGold
                )

                Spacer()

                if let accountCount = connection.accountCount {
                    Text("\(accountCount) account\(accountCount == 1 ? "" : "s")")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            if let email = connection.email,
               !email.isEmpty {
                infoRow(
                    title: "Login",
                    value: email
                )
            }

            if let expiresAt = connection.expiresAt,
               !expiresAt.isEmpty {
                infoRow(
                    title: "Session expires",
                    value: formattedConnectionDate(expiresAt)
                )
            }

            if connection.tokenExpired == true {
                Text("The Aqua Funding session needs to be refreshed.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if (connection.accountCount ?? 0) > 0 {
                architectureNotice(
                    title: "Accounts kept out of this connection card",
                    message: "Open the dedicated Aqua Live Activity trader to see active accounts, browse the full account list, and manage broker-confirmed positions."
                )
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func aquaAccountRow(
        _ account: MatchTraderConnectedAccount
    ) -> some View {
        let accountId = account.tradingAccountId
            ?? account.accountUUID
            ?? account.accountName
            ?? account.id

        let isSelected = selectedAquaAccountId == accountId

        return Button {
            selectedAquaAccountId = accountId
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(
                    systemName: isSelected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .foregroundStyle(
                    isSelected
                        ? AppTheme.softGold
                        : AppTheme.secondaryText
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        account.accountName
                            ?? account.tradingAccountId
                            ?? "Aqua Funding Account"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.primaryText)

                    if let offerName = account.offerName,
                       !offerName.isEmpty {
                        Text(offerName)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    if let systemName = account.systemName,
                       !systemName.isEmpty {
                        Text("Platform: \(systemName)")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    if let accountType = account.accountType,
                       !accountType.isEmpty {
                        Text(
                            [
                                accountType.capitalized,
                                account.group,
                                account.leverage.map { "1:\(Int($0))" }
                            ]
                            .compactMap { $0 }
                            .joined(separator: " • ")
                        )
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                    }

                    if let initialDeposit = account.initialDeposit {
                        Text(
                            "Initial balance: "
                            + initialDeposit.formatted(
                                .currency(code: "USD")
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                    }
                }

                Spacer()

                connectionBadge(
                    isReady: account.authenticatedForTrading == true
                )
            }
            .padding()
            .background(
                isSelected
                    ? AppTheme.softGold.opacity(0.10)
                    : Color.secondary.opacity(0.05)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var selectedAquaSyncedAccount: BrokerAccountResponse? {
        guard let selectedAquaAccountId else {
            return aquaSyncedAccounts.first
        }

        return aquaSyncedAccounts.first {
            $0.accountId == selectedAquaAccountId
                || $0.accountNumber == selectedAquaAccountId
        }
    }

    private var selectedAquaBalanceHealth: MatchTraderBalanceHealthFeatures? {
        guard let selectedAquaAccountId else {
            return aquaBalanceHealth.first
        }

        return aquaBalanceHealth.first {
            $0.accountId == selectedAquaAccountId
        }
    }

    private func aquaAccountControlCard(
        health: MatchTraderBalanceHealthFeatures,
        account: BrokerAccountResponse?
    ) -> some View {
        let currency = account?.currency ?? "USD"
        let riskColor = aquaRiskColor(health.riskLevel)

        return VStack(alignment: .leading, spacing: 14) {
            Divider()

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    aquaRiskHeading(health: health, color: riskColor)
                    Spacer(minLength: 12)
                    aquaTradingPermission(health, color: riskColor)
                }

                VStack(alignment: .leading, spacing: 10) {
                    aquaRiskHeading(health: health, color: riskColor)
                    aquaTradingPermission(health, color: riskColor)
                }
            }

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: 125, maximum: 220),
                        spacing: 10
                    )
                ],
                spacing: 10
            ) {
                aquaMetric(
                    "Balance",
                    currencyValue(health.balance, code: currency)
                )
                aquaMetric(
                    "Equity",
                    currencyValue(health.equity, code: currency)
                )
                aquaMetric(
                    "Available Funds",
                    currencyValue(health.freeMargin, code: currency)
                )
                aquaMetric(
                    "Open P/L",
                    signedCurrencyValue(health.openPnl, code: currency),
                    color: pnlColor(health.openPnl)
                )
                aquaMetric(
                    "Today P/L",
                    signedCurrencyValue(health.todayPnl, code: currency),
                    color: pnlColor(health.todayPnl)
                )
                aquaMetric(
                    "Margin Used",
                    currencyValue(health.margin, code: currency)
                )
                aquaMetric(
                    "Equity Buffer",
                    percentValue(health.equityBufferPercent)
                )

                if let riskScore = health.riskScore {
                    aquaMetric(
                        "Risk Score",
                        "\(riskScore) / 100",
                        color: riskColor
                    )
                }

                if let startingBalance = account?.startingBalance {
                    aquaMetric(
                        "Starting Balance",
                        currencyValue(startingBalance, code: currency)
                    )
                }

                if let profitTargetRemaining = account?.profitTargetRemaining {
                    aquaMetric(
                        "Eval Target Left",
                        currencyValue(
                            profitTargetRemaining,
                            code: currency
                        ),
                        color: profitTargetRemaining > 0
                            ? AppTheme.softGold
                            : .green
                    )
                }

                if let payoutTarget = account?.payoutTarget {
                    aquaMetric(
                        "Payout Target",
                        currencyValue(payoutTarget, code: currency),
                        color: AppTheme.softGold
                    )
                }

                if health.dailyDrawdownRemaining != nil {
                    aquaMetric(
                        "Daily DD Room",
                        currencyValue(
                            health.dailyDrawdownRemaining,
                            code: currency
                        ),
                        color: drawdownColor(
                            health.dailyDrawdownRemaining
                        )
                    )
                }

                if health.maxDrawdownRemaining != nil {
                    aquaMetric(
                        "Max DD Room",
                        currencyValue(
                            health.maxDrawdownRemaining,
                            code: currency
                        ),
                        color: drawdownColor(
                            health.maxDrawdownRemaining
                        )
                    )
                }
            }

            if let suggestedRisk = health.suggestedMaxTradeRisk,
               suggestedRisk > 0 {
                Label(
                    "Current risk ceiling: "
                        + currencyValue(suggestedRisk, code: currency)
                        + " per trade"
                        + suggestedRiskPercentText(health),
                    systemImage: "shield.lefthalf.filled"
                )
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)
            }

            Text(
                health.summary
                    ?? "Risk guidance is based on the latest synchronized account snapshot."
            )
            .font(.caption2)
            .foregroundStyle(AppTheme.secondaryText)

            if let account {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        accountIdentityBadges(account)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        accountIdentityBadges(account)
                    }
                }
            }
        }
        .padding()
        .background(riskColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(riskColor.opacity(0.22), lineWidth: 1)
        }
    }

    private func aquaRiskHeading(
        health: MatchTraderBalanceHealthFeatures,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Account Control")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text(
                health.headline
                    ?? "Live account health synchronized."
            )
            .font(.caption2)
            .foregroundStyle(color)
        }
    }

    private func aquaTradingPermission(
        _ health: MatchTraderBalanceHealthFeatures,
        color: Color
    ) -> some View {
        Label(
            health.tradingAllowed == true
                ? "Risk gate open"
                : "New trades paused",
            systemImage: health.tradingAllowed == true
                ? "checkmark.shield.fill"
                : "hand.raised.fill"
        )
        .font(.caption2.bold())
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
    }

    private func aquaMetric(
        _ title: String,
        _ value: String,
        color: Color = AppTheme.primaryText
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)

            Text(value)
                .font(.caption.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func accountIdentityBadges(
        _ account: BrokerAccountResponse
    ) -> some View {
        smallBadge(
            account.accountMode?.uppercased() ?? "ACCOUNT",
            color: account.accountMode?.lowercased() == "live"
                ? .orange
                : .blue
        )

        if let model = account.propModel,
           !model.isEmpty {
            smallBadge(model, color: AppTheme.softGold)
        }

        if let status = account.accountStatus,
           !status.isEmpty {
            smallBadge(status.capitalized, color: .green)
        }
    }

    private func smallBadge(
        _ text: String,
        color: Color
    ) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }

    private func currencyValue(
        _ value: Double?,
        code: String
    ) -> String {
        guard let value else {
            return "—"
        }

        return value.formatted(
            .currency(code: code)
                .precision(.fractionLength(2))
        )
    }

    private func signedCurrencyValue(
        _ value: Double?,
        code: String
    ) -> String {
        guard let value else {
            return "—"
        }

        let formatted = currencyValue(abs(value), code: code)
        return value > 0 ? "+\(formatted)" : value < 0 ? "-\(formatted)" : formatted
    }

    private func percentValue(
        _ value: Double?
    ) -> String {
        guard let value else {
            return "—"
        }

        return value.formatted(
            .number.precision(.fractionLength(1))
        ) + "%"
    }

    private func suggestedRiskPercentText(
        _ health: MatchTraderBalanceHealthFeatures
    ) -> String {
        guard let percent = health.suggestedMaxTradeRiskPercent else {
            return ""
        }

        return " (\(percentValue(percent)) of equity)"
    }

    private func aquaRiskColor(
        _ riskLevel: String?
    ) -> Color {
        switch riskLevel?.lowercased() {
        case "critical", "high":
            return .red
        case "medium":
            return .orange
        default:
            return .green
        }
    }

    private func pnlColor(
        _ value: Double?
    ) -> Color {
        guard let value else {
            return AppTheme.primaryText
        }

        return value > 0 ? .green : value < 0 ? .red : AppTheme.primaryText
    }

    private func drawdownColor(
        _ value: Double?
    ) -> Color {
        guard let value else {
            return AppTheme.primaryText
        }

        return value > 0 ? .green : .red
    }

    // MARK: - Trade The Pool

    private var tradeThePoolLane: some View {
        brokerCard(
            title: "Trade The Pool",
            subtitle: "Trade The Pool keeps its own login and account architecture. Aqua Funding credentials are never reused here.",
            systemImage: "person.2.wave.2.fill"
        ) {
            architectureNotice(
                title: "Separate broker adapter required",
                message: "Trade The Pool may use Google sign-in and a different account provider. Its login will be added only after the official TTP authentication flow is confirmed."
            )

            Text("Trade The Pool connection coming soon")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.softGold)

            Text(
                "The lane is reserved now so TTP accounts, rules, balances, "
                + "positions, calendars, and performance remain separate from Aqua Funding."
            )
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryText)
        }
    }

    // MARK: - IBKR

    private var ibkrLane: some View {
        brokerCard(
            title: "Interactive Brokers",
            subtitle: "IBKR uses its official session and gateway architecture. ChaseINGreen does not ask for an IBKR password here.",
            systemImage: "chart.line.uptrend.xyaxis"
        ) {
            architectureNotice(
                title: "Official IBKR session required",
                message: "The hosted ChaseINGreen backend cannot connect directly to a gateway running only on your Mac's localhost. IBKR sync requires an approved reachable session."
            )

            HStack(spacing: 10) {
                brokerButton("Check IBKR") {
                    let health = try await APIService.shared.fetchIBKRHealth(
                        accessToken: accessToken
                    )

                    statusMessage = health.message
                        ?? "IBKR connection status checked."
                }

                brokerButton("Try Sync") {
                    let result = try await APIService.shared.fullSyncIBKR(
                        accessToken: accessToken
                    )

                    statusMessage = result.summary
                        ?? result.headline
                        ?? "IBKR sync attempted."

                    await onSyncComplete()
                }
            }
        }
    }

    // MARK: - Coming Soon

    private func comingSoonLane(
        _ lane: BrokerLane
    ) -> some View {
        brokerCard(
            title: lane.fullTitle,
            subtitle: "\(lane.fullTitle) will receive its own official connection and synchronization adapter.",
            systemImage: lane.systemImage
        ) {
            architectureNotice(
                title: "Dedicated architecture",
                message: "This broker will not reuse Aqua Funding, Match-Trader, Trade The Pool, or IBKR authentication."
            )

            Text("Coming soon")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.softGold)

            Text(
                "The future adapter will provide broker-specific authentication, "
                + "account sync, balances, positions, quotes, rules, and execution permissions."
            )
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryText)
        }
    }

    // MARK: - UI Helpers

    private func brokerCard<Content: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            content()
        }
        .padding()
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func architectureNotice(
        title: String,
        message: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: "lock.shield.fill")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)

            Text(message)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.softGold.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statusBanner(
        message: String,
        systemImage: String,
        color: Color
    ) -> some View {
        Label(message, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(color)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func infoRow(
        title: String,
        value: String
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.secondaryText)

            Spacer()

            Text(value)
                .font(.caption2)
                .foregroundStyle(AppTheme.primaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private func connectionBadge(
        isReady: Bool
    ) -> some View {
        Text(isReady ? "Ready" : "Limited")
            .font(.caption2.bold())
            .foregroundStyle(isReady ? Color.green : Color.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                (isReady ? Color.green : Color.orange)
                    .opacity(0.10)
            )
            .clipShape(Capsule())
    }

    private func input(
        _ title: String,
        text: Binding<String>
    ) -> some View {
        TextField(title, text: text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding()
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func credentialTextField(
        _ title: String,
        text: Binding<String>,
        contentType: UITextContentType?
    ) -> some View {
        TextField(title, text: text)
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding()
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func secureCredentialField(
        _ title: String,
        text: Binding<String>
    ) -> some View {
        SecureField(title, text: text)
            .textContentType(.password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .privacySensitive()
            .padding()
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func brokerButton(
        _ title: String,
        action: @escaping () async throws -> Void
    ) -> some View {
        Button {
            Task {
                await run(action)
            }
        } label: {
            Text(isWorking ? "Working..." : title)
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.softGold.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
    }

    @MainActor
    private func run(
        _ action: () async throws -> Void
    ) async {
        isWorking = true
        clearMessages()

        defer {
            isWorking = false
        }

        do {
            try await action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearMessages() {
        statusMessage = nil
        errorMessage = nil
    }

    private func normalizedOptional(
        _ value: String
    ) -> String? {
        let clean = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return clean.isEmpty ? nil : clean
    }

    private func formattedConnectionDate(
        _ rawValue: String
    ) -> String {
        let formatter = ISO8601DateFormatter()

        guard let date = formatter.date(from: rawValue) else {
            return rawValue
        }

        return date.formatted(
            date: .abbreviated,
            time: .shortened
        )
    }

    private func statusColor(
        for lane: BrokerLane
    ) -> Color {
        switch lane {
        case .aqua:
            return aquaConnection?.authenticated == true
                ? .green
                : .yellow

        case .ibkr,
             .tradeThePool:
            return .yellow

        case .webull,
             .fidelity,
             .robinhood,
             .tradeStation:
            return .gray
        }
    }
}

// MARK: - Broker Lanes

private enum BrokerLane: String, CaseIterable, Identifiable {
    case aqua
    case tradeThePool
    case ibkr
    case webull
    case fidelity
    case robinhood
    case tradeStation

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .aqua:
            return "Aqua"

        case .tradeThePool:
            return "TTP"

        case .ibkr:
            return "IBKR"

        case .webull:
            return "Webull"

        case .fidelity:
            return "Fidelity"

        case .robinhood:
            return "Robinhood"

        case .tradeStation:
            return "TradeStation"
        }
    }

    var fullTitle: String {
        switch self {
        case .aqua:
            return "Aqua Funding"

        case .tradeThePool:
            return "Trade The Pool"

        case .ibkr:
            return "Interactive Brokers"

        case .webull:
            return "Webull"

        case .fidelity:
            return "Fidelity"

        case .robinhood:
            return "Robinhood"

        case .tradeStation:
            return "TradeStation"
        }
    }

    var systemImage: String {
        switch self {
        case .aqua:
            return "waveform.path.ecg"

        case .tradeThePool:
            return "person.2.wave.2.fill"

        case .ibkr:
            return "chart.line.uptrend.xyaxis"

        case .webull:
            return "chart.bar.xaxis"

        case .fidelity:
            return "building.columns.fill"

        case .robinhood:
            return "leaf.fill"

        case .tradeStation:
            return "desktopcomputer"
        }
    }
}

// MARK: - Broker Management Errors

private enum BrokerManagementError: LocalizedError {
    case validation(String)
    case connection(String)

    var errorDescription: String? {
        switch self {
        case .validation(let message),
             .connection(let message):
            return message
        }
    }
}
