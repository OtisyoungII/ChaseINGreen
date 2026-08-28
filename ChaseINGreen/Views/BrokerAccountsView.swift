//
//  BrokerAccountsView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/1/26.
//

import SwiftUI

struct BrokerAccountsView: View {
    let accessToken: String

    @State private var accounts: [BrokerAccountResponse] = []
    @State private var selectedBroker: BrokerPreset = .aquaFunding
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasLoadedAccounts = false
    @State private var didChooseInitialBroker = false

    @State private var showingAddSheet = false
    @State private var accountToEdit: BrokerAccountResponse?
    @State private var accountToInspect: BrokerAccountResponse?
    @State private var accountPendingDelete: BrokerAccountResponse?
    @State private var accountPendingRename: BrokerAccountResponse?
    @State private var renameText = ""
    @State private var isDeleting = false
    @State private var isRenaming = false

    private var refreshKey: APIRefreshKey {
        APIRefreshKey(
            "broker_accounts",
            broker: selectedBroker.apiValue,
            ownerKey: APIRefreshKey.ownerScope(
                accessToken: accessToken
            ),
            speed: .medium
        )
    }

    private var trailingToolbarPlacement: ToolbarItemPlacement {
    #if os(iOS)
        return .topBarTrailing
    #else
        return .automatic
    #endif
    }

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    brokerPickerSection
                    accountsSection
                }
                .padding()
            }
        }
        .navigationTitle("Broker Accounts")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        #endif
        .toolbar {
            ToolbarItem(placement: trailingToolbarPlacement) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppTheme.gold)
                }
            }
        }
        .task {
            await loadAccounts()
        }
        .refreshable {
            await loadAccounts(force: true)
        }
        .sheet(isPresented: $showingAddSheet) {
            BrokerAccountManualSyncSheet(
                accessToken: accessToken,
                accountToEdit: nil,
                onSaved: {
                    await loadAccounts(force: true)
                }
            )
        }
        .sheet(item: $accountToEdit) { account in
            BrokerAccountManualSyncSheet(
                accessToken: accessToken,
                accountToEdit: account,
                onSaved: {
                    await loadAccounts(force: true)
                }
            )
        }
        .sheet(item: $accountToInspect) { account in
            BrokerAccountDetailSheet(
                account: account,
                onEdit: {
                    accountToInspect = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        if isConnectedKrakenAccount(account) {
                            renameText = account.accountName ?? account.accountId
                            accountPendingRename = account
                        } else {
                            accountToEdit = account
                        }
                    }
                },
                onDelete: {
                    accountToInspect = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        accountPendingDelete = account
                    }
                }
            )
        }
        .confirmationDialog(
            "Ignore broker account?",
            isPresented: Binding(
                get: { accountPendingDelete != nil },
                set: { if !$0 { accountPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Ignore Account", role: .destructive) {
                guard let account = accountPendingDelete else { return }

                Task {
                    await deleteAccount(account)
                }
            }

            Button("Cancel", role: .cancel) {
                accountPendingDelete = nil
            }
        } message: {
            Text("This removes the account from live polling and Trader OS. Identity, Calendar, Journal, and trade history remain saved.")
        }
        .alert(
            "Rename Kraken connection",
            isPresented: Binding(
                get: { accountPendingRename != nil },
                set: { if !$0 { accountPendingRename = nil } }
            )
        ) {
            TextField("Connection name", text: $renameText)
            Button("Save") {
                guard let account = accountPendingRename else { return }
                Task { await renameKrakenAccount(account) }
            }
            .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRenaming)
            Button("Cancel", role: .cancel) {
                accountPendingRename = nil
            }
        } message: {
            Text("This changes the local display name only. Kraken credentials and trade history are unchanged.")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Account Command Center")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text("Separate prop firms, brokerage accounts, and crypto exchanges so Trader OS can use the right account rules.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.danger)
            }

            HStack(spacing: 12) {
                DashboardStatCard(
                    title: "Accounts",
                    value: hasLoadedAccounts ? "\(filteredAccounts.count)" : "--",
                    systemImage: "wallet.pass.fill"
                )

                DashboardStatCard(
                    title: "Open Equity",
                    value: hasLoadedAccounts ? formatMoney(filteredEquity) : "--",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
            }
        }
    }

    private var brokerPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Broker / Platform")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.softGold)

            Picker("Broker", selection: $selectedBroker) {
                ForEach(BrokerPreset.allCases) { broker in
                    Text(broker.displayName).tag(broker)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.gold)

            Text(selectedBroker.integrationStatus)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            Text(selectedBroker.accountClass.displayName)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)

            if selectedBroker == .aquaFunding {
                Button {
                    Task { await discoverAquaAccounts() }
                } label: {
                    Label("Discover Aqua Accounts", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.gold)
            }
        }
        .padding()
        .background(AppTheme.cardBlack)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saved Accounts")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.softGold)

                Spacer()

                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.caption.bold())
                }
                .foregroundStyle(AppTheme.gold)
            }

            if isLoading && accounts.isEmpty {
                ProgressView()
                    .tint(AppTheme.gold)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if errorMessage != nil && accounts.isEmpty {
                AppUnavailableView(
                    title: "Accounts Temporarily Unavailable",
                    systemImage: "arrow.clockwise.circle",
                    message: "Your saved accounts were not replaced with an empty portfolio. Pull to retry."
                )
            } else if filteredAccounts.isEmpty {
                emptyAccountsView
            } else if selectedBroker == .aquaFunding {
                ForEach(participationSections, id: \.state) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(section.title) (\(section.accounts.count))")
                            .font(.caption.bold())
                            .foregroundStyle(section.color)

                        ForEach(section.accounts) { account in
                            accountRow(account)
                        }
                    }
                }
            } else {
                ForEach(filteredAccounts) { account in
                    accountRow(account)
                }
            }

            if isLoading && !accounts.isEmpty {
                Label("Refreshing saved accounts…", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            } else if errorMessage != nil && !accounts.isEmpty {
                Label("Showing the last saved account list. Pull to retry.", systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(AppTheme.softGold)
            }
        }
    }

    private var participationSections: [(
        state: String,
        title: String,
        color: Color,
        accounts: [BrokerAccountResponse]
    )] {
        [
            ("active", "ACTIVE", .green),
            ("available", "AVAILABLE", AppTheme.gold),
            ("ignored", "IGNORED", AppTheme.secondaryText)
        ].compactMap { state, title, color in
            let matching = filteredAccounts.filter {
                $0.normalizedParticipationState == state
            }
            guard !matching.isEmpty else { return nil }
            return (state, title, color, matching)
        }
    }

    private func accountRow(_ account: BrokerAccountResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.accountName ?? account.accountId)
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.primaryText)

                    Text(account.accountType ?? account.accountMode ?? "broker account")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(BrokerPreset.from(account.broker)?.displayName ?? account.platform ?? account.broker)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.softGold)

                    Text(participationLabel(account))
                        .font(.caption2.bold())
                        .foregroundStyle(participationColor(account))

                    Text(connectionLabel(account))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            HStack(spacing: 10) {
                if account.normalizedParticipationState != "active" {
                    Button("Activate") {
                        Task { await setParticipation(account, state: "active") }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                if account.normalizedParticipationState != "ignored" {
                    Button("Ignore") { accountPendingDelete = account }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.danger)
                } else {
                    Button("Restore as Available") {
                        Task { await setParticipation(account, state: "available") }
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.gold)
                }
                Spacer()
                Button("Details") { accountToInspect = account }
                    .buttonStyle(.borderless)
            }
            .font(.caption.bold())

            detailGrid([
                ("Equity", formatMoney(account.equity ?? account.balance ?? account.startingBalance)),
                ("Buying Power", formatMoney(account.buyingPower ?? account.availableFunds)),
                ("Open P/L", formatMoney(account.unrealizedPnl)),
                ("Daily DD Left", formatMoney(account.dailyDrawdownRemaining)),
                ("Max DD Left", formatMoney(account.maxDrawdownRemaining))
            ])

            if let updated = account.updatedAt ?? account.lastManualUpdateAt {
                Text("Updated: \(updated)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
    }

    private var emptyAccountsView: some View {
        VStack(spacing: 12) {
            AppUnavailableView(
                title: "No Accounts Yet",
                systemImage: "wallet.pass",
                message: "Add Aqua, Trade The Pool, IBKR, Fidelity, Webull, Robinhood, Coinbase, Kraken, or Crypto.com so account rules stay separate."
            )

            Button {
                showingAddSheet = true
            } label: {
                Label("Add Broker Account", systemImage: "plus.circle.fill")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.deepBlack)
            .background(AppTheme.gold)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var filteredAccounts: [BrokerAccountResponse] {
        accounts.filter { account in
            BrokerPreset.from(account.broker) == selectedBroker
            || BrokerPreset.from(account.platform) == selectedBroker
        }
    }

    private var filteredEquity: Double? {
        let values = filteredAccounts.compactMap { $0.equity ?? $0.balance }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private func loadAccounts(force: Bool = false) async {
        guard APIRefreshGate.shared.shouldRefresh(refreshKey, force: force) else {
            return
        }

        APIRefreshGate.shared.begin(refreshKey)

        do {
            isLoading = true
            errorMessage = nil
            let startedAt = Date()
            #if DEBUG
            print("[RefreshPerf] accounts start force=\(force)")
            #endif

            let loaded = try await AppRefreshCoordinator.shared.brokerAccounts(
                accessToken: accessToken,
                force: force,
                includeInactive: true
            )
            if !loaded.isEmpty || accounts.isEmpty {
                accounts = loaded
            }
            hasLoadedAccounts = true
            if !didChooseInitialBroker {
                didChooseInitialBroker = true
                if filteredAccounts.isEmpty,
                   let first = accounts.first,
                   let provider = BrokerPreset.from(first.broker)
                    ?? BrokerPreset.from(first.platform) {
                    selectedBroker = provider
                }
            }

            APIRefreshGate.shared.finish(refreshKey)
            isLoading = false
            #if DEBUG
            print("[RefreshPerf] accounts complete ms=\(Int(Date().timeIntervalSince(startedAt) * 1000)) count=\(accounts.count)")
            #endif
        } catch {
            APIRefreshGate.shared.reset(refreshKey)
            isLoading = false
            errorMessage = "Could not load broker accounts: \(error.localizedDescription)"
            #if DEBUG
            print("[RefreshPerf] accounts failed preserved=\(!accounts.isEmpty) error=\(error.localizedDescription)")
            #endif
        }
    }

    private func discoverAquaAccounts() async {
        do {
            isLoading = true
            errorMessage = nil
            _ = try await APIService.shared.fetchMatchTraderPositions(
                MatchTraderSyncRequest(
                    broker: "Aqua Funding",
                    accountId: nil,
                    symbols: [],
                    includeEmptyAccounts: true
                ),
                accessToken: accessToken,
                forceRefresh: true
            )
            APIRefreshGate.shared.reset(refreshKey)
            await loadAccounts(force: true)
        } catch {
            isLoading = false
            errorMessage = "Could not discover Aqua accounts: \(error.localizedDescription)"
        }
    }

    private func deleteAccount(_ account: BrokerAccountResponse) async {
        guard !isDeleting else { return }

        do {
            isDeleting = true
            errorMessage = nil

            if isConnectedKrakenAccount(account),
               let connectionId = account.brokerConnectionId {
                try await APIService.shared.disconnectKrakenConnection(
                    connectionId: connectionId,
                    accessToken: accessToken
                )
            } else {
                try await APIService.shared.deleteBrokerAccount(
                    accountId: account.id,
                    accessToken: accessToken
                )
            }

            await loadAccounts(force: true)
            accountPendingDelete = nil
            APIRefreshGate.shared.reset(refreshKey)
            isDeleting = false
        } catch {
            isDeleting = false
            errorMessage = "Could not ignore broker account: \(error.localizedDescription)"
        }
    }

    private func renameKrakenAccount(_ account: BrokerAccountResponse) async {
        guard !isRenaming,
              let connectionId = account.brokerConnectionId else {
            return
        }

        let cleanName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        do {
            isRenaming = true
            errorMessage = nil
            _ = try await APIService.shared.renameKrakenConnection(
                connectionId: connectionId,
                name: cleanName,
                accessToken: accessToken
            )
            accountPendingRename = nil
            APIRefreshGate.shared.reset(refreshKey)
            await loadAccounts(force: true)
            isRenaming = false
        } catch {
            isRenaming = false
            errorMessage = "Could not rename Kraken connection: \(error.localizedDescription)"
        }
    }

    private func isConnectedKrakenAccount(_ account: BrokerAccountResponse) -> Bool {
        guard account.brokerConnectionId != nil,
              account.connectionMode?.lowercased() == "api" else {
            return false
        }

        return BrokerPreset.from(account.broker) == .kraken
            || BrokerPreset.from(account.platform) == .kraken
    }

    private func setParticipation(
        _ account: BrokerAccountResponse,
        state: String
    ) async {
        do {
            let updated = try await APIService.shared.updateBrokerAccountParticipation(
                accountId: account.id,
                state: state,
                accessToken: accessToken
            )
            if let index = accounts.firstIndex(where: { $0.id == updated.id }) {
                accounts[index] = updated
            }
        } catch {
            errorMessage = "Could not update account participation: \(error.localizedDescription)"
        }
    }

    private func participationLabel(_ account: BrokerAccountResponse) -> String {
        switch account.normalizedParticipationState {
        case "ignored": return "Ignored"
        case "available": return "Available"
        default: return "Active"
        }
    }

    private func participationColor(_ account: BrokerAccountResponse) -> Color {
        switch account.normalizedParticipationState {
        case "ignored": return AppTheme.secondaryText
        case "available": return AppTheme.gold
        default: return .green
        }
    }

    private func connectionLabel(_ account: BrokerAccountResponse) -> String {
        switch account.connectionMode?.lowercased() {
        case "api":
            return "API • \(account.connectionStatus ?? "connected")"
        case "gateway":
            return "Gateway • \(account.connectionStatus ?? "connected")"
        default:
            return "Manually maintained"
        }
    }

    private func detailGrid(_ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows.indices, id: \.self) { index in
                HStack {
                    Text(rows[index].0)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)

                    Spacer()

                    Text(rows[index].1)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
        }
    }

    private func formatMoney(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%@%.2f", value >= 0 ? "$" : "-$", abs(value))
    }
}

// MARK: - Broker Account Detail Sheet

private struct BrokerAccountDetailSheet: View {
    let account: BrokerAccountResponse
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private var broker: BrokerPreset {
        BrokerPreset.from(account.broker)
        ?? BrokerPreset.from(account.platform)
        ?? .aquaFunding
    }
    
    private var title: String {
        account.accountName ?? account.accountId
    }
    
    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        BrokerAccountCard(account: account)
                        accountIdentityCard
                        accountMetricsCard
                        accountRulesCard
                        actionCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Account Details")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
    }
    
    private var accountIdentityCard: some View {
        sectionCard("Identity", systemImage: "person.text.rectangle") {
            detailRow("Name", title)
            detailRow("Broker", broker.displayName)
            detailRow("Class", broker.accountClass.displayName)
            detailRow("Mode", account.accountMode)
            detailRow("Type", account.accountType)
            detailRow("Account ID", account.accountId)
            detailRow("Last 4", account.accountNumber)
            detailRow("Status", account.accountStatus ?? "active")
        }
    }
    
    private var accountMetricsCard: some View {
        sectionCard("Balances", systemImage: "dollarsign.circle.fill") {
            detailRow("Starting", formatMoney(account.startingBalance))
            detailRow("Balance", formatMoney(account.balance))
            detailRow("Equity", formatMoney(account.equity))
            detailRow("Buying Power", formatMoney(account.buyingPower))
            detailRow("Cash", formatMoney(account.cashBalance))
            detailRow("Available", formatMoney(account.availableFunds))
        }
    }
    
    private var accountRulesCard: some View {
        sectionCard(broker.isPropFirm ? "Prop Rules" : "Account Rules", systemImage: "shield.lefthalf.filled") {
            if broker.isPropFirm {
                detailRow("Prop Firm", account.propFirmName)
                detailRow("Model", account.propModel)
                detailRow("Daily DD Limit", formatMoney(account.dailyDrawdownLimit))
                detailRow("Max DD Limit", formatMoney(account.maxDrawdownLimit))
                detailRow("Daily DD Left", formatMoney(account.dailyDrawdownRemaining))
                detailRow("Max DD Left", formatMoney(account.maxDrawdownRemaining))
                detailRow("Profit Target", formatMoney(account.profitTarget))
                detailRow("Target Left", formatMoney(account.profitTargetRemaining))
                detailRow("Payout Target", formatMoney(account.payoutTarget))
            } else if broker.isCryptoExchange {
                Text("Crypto exchange account. No prop-firm drawdown rules should be attached.")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                Text("Brokerage account. Cash/margin rules apply. Prop-firm drawdown rules should not be attached.")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }
    
    private var actionCard: some View {
        sectionCard("Actions", systemImage: "slider.horizontal.3") {
            Button {
                onEdit()
            } label: {
                Label("Edit Account", systemImage: "pencil")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.deepBlack)
            .background(AppTheme.gold)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            Button {
                onDelete()
            } label: {
                Label("Delete Account", systemImage: "trash")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.red.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private func sectionCard<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.softGold)
            
            content()
        }
        .appCard()
    }
    
    private func detailRow(_ title: String, _ value: String?) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.secondaryText)
            
            Spacer()
            
            Text(value?.isEmpty == false ? value! : "--")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.primaryText)
                .multilineTextAlignment(.trailing)
        }
    }
    
    private func detailGrid(_ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows.indices, id: \.self) { index in
                HStack {
                    Text(rows[index].0)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    
                    Spacer()
                    
                    Text(rows[index].1)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
        }
    }
    
    private func formatMoney(_ value: Double?) -> String {
        guard let value else { return "--" }
        
        return String(
            format: "%@%.2f",
            value >= 0 ? "$" : "-$",
            abs(value)
        )
    }
}

#Preview {
    NavigationStack {
        BrokerAccountsView(accessToken: "dummy-access-token")
    }
}
