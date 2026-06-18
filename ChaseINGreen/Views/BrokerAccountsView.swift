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
    @State private var accountPendingDelete: BrokerAccountResponse?
    @State private var isDeleting = false

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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
            await loadAccounts()
        }
        .sheet(isPresented: $showingAddSheet) {
            BrokerAccountManualSyncSheet(
                accessToken: accessToken,
                accountToEdit: nil,
                onSaved: {
                    await loadAccounts()
                }
            )
        }
        .sheet(item: $accountToEdit) { account in
            BrokerAccountManualSyncSheet(
                accessToken: accessToken,
                accountToEdit: account,
                onSaved: {
                    await loadAccounts()
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

            Text("Separate Aqua, Trade The Pool, IBKR, crypto, and manual accounts so P/L and drawdown finally make sense.")
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
            } else if accounts.isEmpty {
                emptyAccountsView
            } else {
                ForEach(accounts) { account in
                    accountRow(account)
                }
            }
        }
    }

    private func accountRow(_ account: BrokerAccountResponse) -> some View {
        ZStack(alignment: .bottomTrailing) {
            BrokerAccountCard(account: account)
                .contentShape(RoundedRectangle(cornerRadius: 18))
                .onTapGesture {
                    accountToEdit = account
                }

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
                message: "Add Aqua, Trade The Pool, IBKR, or another broker account so the app can track balance, drawdown, and targets separately."
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

    private var totalEquity: Double {
        accounts.compactMap { $0.equity ?? $0.balance }.reduce(0, +)
    }

    private func loadAccounts() async {
        do {
            isLoading = true
            errorMessage = nil
            accounts = try await APIService.shared.fetchBrokerAccounts(accessToken: accessToken)
            isLoading = false
        } catch {
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

#Preview {
    NavigationStack {
        BrokerAccountsView(accessToken: "dummy-access-token")
    }
}
