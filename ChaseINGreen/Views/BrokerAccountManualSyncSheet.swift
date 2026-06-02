//
//  BrokerAccountManualSyncSheet.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/1/26.
//


import SwiftUI

struct BrokerAccountManualSyncSheet: View {
    let accessToken: String
    let onSaved: () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedBroker: BrokerPreset = .aquaFunding
    @State private var accountIdText = ""
    @State private var accountNameText = ""
    @State private var accountNumberText = ""

    @State private var accountModeText = "prop"
    @State private var accountTypeText = "instant"
    @State private var propFirmNameText = "Aqua Funded"
    @State private var propModelText = ""

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
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Manual Broker Account")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Save Aqua, Trade The Pool, IBKR, crypto, or brokerage account rules so trades can auto-group correctly.")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .appCard()
    }

    private var brokerCard: some View {
        sectionCard("Broker / Identity", systemImage: "building.columns.fill") {
            Picker("Broker", selection: $selectedBroker) {
                ForEach(BrokerPreset.allCases) { broker in
                    Text(broker.displayName).tag(broker)
                }
            }

            appTextField("Account ID / Group Key, ex: aqua-250k-1", text: $accountIdText)
            appTextField("Account Name, ex: Aqua 250K #1", text: $accountNameText)
            appTextField("Account Number / Last 4 optional", text: $accountNumberText)

            appTextField("Account Mode, ex: prop, live, paper", text: $accountModeText)
            appTextField("Account Type, ex: instant, challenge, margin", text: $accountTypeText)
            appTextField("Prop Firm Name", text: $propFirmNameText)
            appTextField("Prop Model", text: $propModelText)
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
            Text(isSaving ? "Saving..." : "Save Account")
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
            broker: selectedBroker.rawValue,
            accountId: clean(accountIdText) ?? selectedBroker.rawValue,
            accountNumber: clean(accountNumberText),
            accountName: clean(accountNameText),
            accountStatus: "active",
            accountMode: clean(accountModeText),
            accountType: clean(accountTypeText),
            propFirmName: clean(propFirmNameText),
            propModel: clean(propModelText),
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
}

#Preview {
    BrokerAccountManualSyncSheet(accessToken: "dummy") {}
}
