//
//  BrokerAccountManualSyncSheet.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/1/26.
//

import SwiftUI

struct BrokerAccountManualSyncSheet: View {
    let accessToken: String
    let accountToEdit: BrokerAccountResponse?
    let onSaved: () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedBroker: BrokerPreset = .aquaFunding
    @State private var selectedPropFirm: PropFirmPreset = .aquaFunding
    @State private var selectedPropModel: PropAccountModelPreset = .instant

    @State private var accountIdText = ""
    @State private var accountNameText = ""
    @State private var accountNumberText = ""

    @State private var accountModeText = "prop"
    @State private var accountTypeText = "prop_firm"

    @State private var startingBalanceText = ""
    @State private var balanceText = ""
    @State private var equityText = ""
    @State private var dailyDrawdownLimitText = ""
    @State private var maxDrawdownLimitText = ""
    @State private var dailyDrawdownRemainingText = ""
    @State private var maxDrawdownRemainingText = ""
    @State private var payoutTargetText = ""
    @State private var notesText = ""

    @State private var errorMessage: String?
    @State private var isSaving = false

    init(
        accessToken: String,
        accountToEdit: BrokerAccountResponse? = nil,
        onSaved: @escaping () async -> Void
    ) {
        self.accessToken = accessToken
        self.accountToEdit = accountToEdit
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerCard
                        brokerCard
                        balanceCard
                        rulesCard

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.danger)
                        }

                        saveButton
                    }
                    .padding()
                }
            }
            .navigationTitle(accountToEdit == nil ? "Add Account" : "Edit Account")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .onAppear {
                loadEditAccountIfNeeded()
            }
            .onChange(of: selectedBroker) { _, newValue in
                applyBrokerDefaults(newValue)
            }
            .onChange(of: selectedPropFirm) { _, newValue in
                if accountToEdit == nil || accountIdText.isEmpty {
                    accountIdText = defaultAccountId()
                }
            }
            .onChange(of: selectedPropModel) { _, newValue in
                accountModeText = "prop"
                accountTypeText = newValue.displayName
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(accountToEdit == nil ? "Manual Broker Account" : "Edit Broker Account")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Save account rules so trades can auto-group by broker, prop firm, balance, drawdown, and payout target.")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .appCard()
    }

    private var brokerCard: some View {
        sectionCard("Broker / Identity", systemImage: "building.columns.fill") {
            Picker("Broker / Platform", selection: $selectedBroker) {
                ForEach(BrokerPreset.allCases) { broker in
                    Text(broker.displayName).tag(broker)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.gold)

            if selectedBroker.accountType == "prop_firm" {
                Picker("Prop Firm", selection: $selectedPropFirm) {
                    ForEach(PropFirmPreset.allCases) { firm in
                        Text(firm.displayName).tag(firm)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.gold)

                Picker("Prop Model", selection: $selectedPropModel) {
                    ForEach(PropAccountModelPreset.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.gold)
            }

            appTextField("Account ID / Group Key, ex: ttp-flex-25k", text: $accountIdText)
            appTextField("Account Name, ex: Flex 25K TTP", text: $accountNameText)
            appTextField("Account Number / Last 4 optional", text: $accountNumberText)

            appTextField("Account Mode, ex: prop, live, paper", text: $accountModeText)
            appTextField("Account Type, ex: Flex, Instant, Margin", text: $accountTypeText)
        }
    }

    private var balanceCard: some View {
        sectionCard("Balance / Equity", systemImage: "dollarsign.circle.fill") {
            appTextField("Starting Balance", text: $startingBalanceText)
            appTextField("Balance", text: $balanceText)
            appTextField("Equity", text: $equityText)
        }
    }

    private var rulesCard: some View {
        sectionCard("Rules / Targets", systemImage: "shield.lefthalf.filled") {
            appTextField("Daily Drawdown Limit", text: $dailyDrawdownLimitText)
            appTextField("Max Drawdown Limit", text: $maxDrawdownLimitText)
            appTextField("Daily Drawdown Remaining", text: $dailyDrawdownRemainingText)
            appTextField("Max Drawdown Remaining", text: $maxDrawdownRemainingText)
            appTextField("Payout Target", text: $payoutTargetText)
            appTextField("Notes", text: $notesText)
        }
    }

    private var saveButton: some View {
        Button {
            Task {
                await saveAccount()
            }
        } label: {
            Text(isSaving ? "Saving..." : accountToEdit == nil ? "Save Account" : "Update Account")
                .font(.headline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(canSave ? AppTheme.deepBlack : AppTheme.mutedText)
                .background(canSave ? AppTheme.gold : .white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!canSave || isSaving)
    }

    private var canSave: Bool {
        !accountIdText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveAccount() async {
        guard canSave else { return }

        isSaving = true
        errorMessage = nil

        let payload = BrokerAccountUpsertRequest(
            broker: selectedBroker.apiValue,
            accountId: clean(accountIdText) ?? defaultAccountId(),
            accountNumber: clean(accountNumberText),
            accountName: clean(accountNameText),
            accountStatus: "active",
            accountMode: clean(accountModeText),
            accountType: clean(accountTypeText),
            propFirmName: selectedBroker.accountType == "prop_firm" ? selectedPropFirm.displayName : nil,
            propModel: selectedBroker.accountType == "prop_firm" ? selectedPropModel.displayName : nil,
            platform: selectedBroker.displayName,
            startingBalance: double(startingBalanceText),
            balance: double(balanceText),
            equity: double(equityText),
            buyingPower: nil,
            cashBalance: nil,
            availableFunds: nil,
            dailyDrawdownLimit: double(dailyDrawdownLimitText),
            maxDrawdownLimit: double(maxDrawdownLimitText),
            dailyDrawdownRemaining: double(dailyDrawdownRemainingText),
            maxDrawdownRemaining: double(maxDrawdownRemainingText),
            profitTarget: nil,
            profitTargetRemaining: nil,
            payoutTarget: double(payoutTargetText),
            dailyPnl: nil,
            unrealizedPnl: nil,
            realizedPnl: nil,
            currency: "USD",
            notes: clean(notesText)
        )

        do {
            _ = try await APIService.shared.manualSyncBrokerAccount(
                payload,
                accessToken: accessToken
            )

            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func loadEditAccountIfNeeded() {
        guard let account = accountToEdit else {
            applyBrokerDefaults(selectedBroker)
            return
        }

        selectedBroker = BrokerPreset.from(account.broker) ?? .aquaFunding
        selectedPropFirm = PropFirmPreset.from(account.propFirmName ?? account.broker)
        selectedPropModel = PropAccountModelPreset.allCases.first {
            $0.displayName.lowercased() == (account.propModel ?? account.accountType ?? "").lowercased()
        } ?? .other

        accountIdText = account.accountId
        accountNameText = account.accountName ?? ""
        accountNumberText = account.accountNumber ?? ""

        accountModeText = account.accountMode ?? "prop"
        accountTypeText = account.accountType ?? selectedPropModel.displayName

        startingBalanceText = formatNumber(account.startingBalance)
        balanceText = formatNumber(account.balance)
        equityText = formatNumber(account.equity)
        dailyDrawdownLimitText = formatNumber(account.dailyDrawdownLimit)
        maxDrawdownLimitText = formatNumber(account.maxDrawdownLimit)
        dailyDrawdownRemainingText = formatNumber(account.dailyDrawdownRemaining)
        maxDrawdownRemainingText = formatNumber(account.maxDrawdownRemaining)
        payoutTargetText = formatNumber(account.payoutTarget)
        notesText = account.notes ?? ""
    }

    private func applyBrokerDefaults(_ broker: BrokerPreset) {
        if broker.accountType == "prop_firm" {
            accountModeText = "prop"
            accountTypeText = selectedPropModel.displayName

            if accountToEdit == nil && accountIdText.isEmpty {
                accountIdText = defaultAccountId()
            }

            if accountToEdit == nil && accountNameText.isEmpty {
                accountNameText = "\(selectedPropModel.displayName) Account"
            }
        } else {
            accountModeText = broker.accountType == "crypto" ? "crypto" : "live"
            accountTypeText = broker.accountType
        }
    }

    private func defaultAccountId() -> String {
        let broker = selectedBroker.apiValue
        let model = selectedPropModel.displayName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")

        let size = clean(startingBalanceText) ?? "account"
        return "\(broker)-\(model)-\(size)"
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
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

    private func appTextField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .font(AppTheme.bodyFont)
            .padding(12)
            .background(.white.opacity(0.10))
            .foregroundStyle(.white)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func clean(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func double(_ value: String) -> Double? {
        guard let cleaned = clean(value) else { return nil }
        return Double(cleaned)
    }

    private func formatNumber(_ value: Double?) -> String {
        guard let value else { return "" }

        if value == floor(value) {
            return String(format: "%.0f", value)
        }

        return String(format: "%.2f", value)
    }
}

#Preview {
    BrokerAccountManualSyncSheet(accessToken: "dummy") {}
}
