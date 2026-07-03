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

    @State private var showingAddSheet = false
    @State private var accountToEdit: BrokerAccountResponse?
    @State private var accountToInspect: BrokerAccountResponse?
    @State private var accountPendingDelete: BrokerAccountResponse?
    @State private var isDeleting = false

    private var refreshKey: APIRefreshKey {
        APIRefreshKey(
            "broker_accounts",
            broker: selectedBroker.apiValue,
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
                        accountToEdit = account
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
            "Delete broker account?",
            isPresented: Binding(
                get: { accountPendingDelete != nil },
                set: { if !$0 { accountPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                guard let account = accountPendingDelete else { return }

                Task {
                    await deleteAccount(account)
                }
            }

            Button("Cancel", role: .cancel) {
                accountPendingDelete = nil
            }
        } message: {
            Text("This removes the saved broker account only. It does not delete trade history.")
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
                    value: "\(accounts.count)",
                    systemImage: "wallet.pass.fill"
                )

                DashboardStatCard(
                    title: "Open Equity",
                    value: formatMoney(totalEquity),
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

            if isLoading {
                ProgressView()
                    .tint(AppTheme.gold)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if filteredAccounts.isEmpty {
                emptyAccountsView
            } else {
                ForEach(filteredAccounts) { account in
                    accountRow(account)
                }
            }
        }
    }

    private func accountRow(_ account: BrokerAccountResponse) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Button {
                accountToInspect = account
            } label: {
                BrokerAccountCard(account: account)
            }
            .buttonStyle(.plain)

            Button {
                accountPendingDelete = account
            } label: {
                Image(systemName: "trash.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
                    .padding(10)
                    .background(.black.opacity(0.35))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
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

    private var totalEquity: Double {
        accounts.compactMap { $0.equity ?? $0.balance }.reduce(0, +)
    }

    private func loadAccounts(force: Bool = false) async {
        guard APIRefreshGate.shared.shouldRefresh(refreshKey, force: force) else {
            return
        }

        APIRefreshGate.shared.begin(refreshKey)

        do {
            isLoading = true
            errorMessage = nil

            accounts = try await APIService.shared.fetchBrokerAccounts(
                accessToken: accessToken
            )

            APIRefreshGate.shared.finish(refreshKey)
            isLoading = false
        } catch {
            APIRefreshGate.shared.reset(refreshKey)
            isLoading = false
            errorMessage = "Could not load broker accounts: \(error.localizedDescription)"
        }
    }

    private func deleteAccount(_ account: BrokerAccountResponse) async {
        guard !isDeleting else { return }

        do {
            isDeleting = true
            errorMessage = nil

            try await APIService.shared.deleteBrokerAccount(
                accountId: account.id,
                accessToken: accessToken
            )

            accounts.removeAll { $0.id == account.id }
            accountPendingDelete = nil
            APIRefreshGate.shared.reset(refreshKey)
            isDeleting = false
        } catch {
            isDeleting = false
            errorMessage = "Could not delete broker account: \(error.localizedDescription)"
        }
    }

    private func formatMoney(_ value: Double) -> String {
        String(format: "$%.2f", value)
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

    private func formatMoney(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%@%.2f", value >= 0 ? "$" : "-$", abs(value))
    }
}

#Preview {
    NavigationStack {
        BrokerAccountsView(accessToken: "dummy-access-token")
    }
}
