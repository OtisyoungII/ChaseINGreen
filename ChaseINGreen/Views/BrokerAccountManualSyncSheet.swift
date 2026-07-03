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
    @State private var selectedBrokerAccountType: BrokerCashMarginType = .cash

    @State private var accountIdText = ""
    @State private var accountNameText = ""
    @State private var accountNumberText = ""

    @State private var accountModeText = "prop"
    @State private var accountTypeText = "Instant"

    @State private var startingBalanceText = ""
    @State private var balanceText = ""
    @State private var equityText = ""

    @State private var buyingPowerText = ""
    @State private var cashBalanceText = ""
    @State private var availableFundsText = ""

    @State private var dailyDrawdownLimitText = ""
    @State private var maxDrawdownLimitText = ""
    @State private var dailyDrawdownRemainingText = ""
    @State private var maxDrawdownRemainingText = ""

    @State private var profitTargetText = ""
    @State private var profitTargetRemainingText = ""
    @State private var payoutTargetText = ""

    @State private var dailyPnlText = ""
    @State private var unrealizedPnlText = ""
    @State private var realizedPnlText = ""

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

                        if isPropFirmBroker {
                            propRulesCard
                        } else if isCryptoBroker {
                            cryptoCard
                        } else {
                            brokerageCard
                        }

                        pnlCard
                        notesCard

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
                applyBrokerDefaults(newValue, resetIdentity: accountToEdit == nil)
            }
            .onChange(of: selectedPropFirm) { _, _ in
                guard accountToEdit == nil else { return }
                accountIdText = defaultAccountId()
                accountNameText = defaultAccountName()
            }
            .onChange(of: selectedPropModel) { _, newValue in
                guard isPropFirmBroker else { return }
                accountModeText = "prop"
                accountTypeText = newValue.displayName

                guard accountToEdit == nil else { return }
                accountIdText = defaultAccountId()
                accountNameText = defaultAccountName()
            }
            .onChange(of: selectedBrokerAccountType) { _, newValue in
                guard isBrokerageBroker else { return }
                accountModeText = "live"
                accountTypeText = newValue.rawValue

                guard accountToEdit == nil else { return }
                accountIdText = defaultAccountId()
                accountNameText = defaultAccountName()
            }
        }
    }

    private var isPropFirmBroker: Bool {
        selectedBroker == .aquaFunding || selectedBroker == .tradeThePool
    }

    private var isCryptoBroker: Bool {
        selectedBroker == .coinbase || selectedBroker == .kraken || selectedBroker == .cryptoDotCom
    }

    private var isBrokerageBroker: Bool {
        !isPropFirmBroker && !isCryptoBroker
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(accountToEdit == nil ? "Manual Broker Account" : "Edit Broker Account")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Save the correct account type so Trader OS can treat prop firms, cash brokers, margin brokers, and crypto exchanges differently.")
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

            if isPropFirmBroker {
                Picker("Prop Firm", selection: $selectedPropFirm) {
                    ForEach([PropFirmPreset.aquaFunding, .tradeThePool], id: \.id) { firm in
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

            if isBrokerageBroker {
                Picker("Account Type", selection: $selectedBrokerAccountType) {
                    ForEach(BrokerCashMarginType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            appTextField("Account ID / Group Key", text: $accountIdText)
            appTextField("Account Name", text: $accountNameText)
            appTextField("Account Number / Last 4 optional", text: $accountNumberText)

            appTextField("Account Mode", text: $accountModeText)
            appTextField("Account Type", text: $accountTypeText)
        }
    }

    private var balanceCard: some View {
        sectionCard("Balance / Equity", systemImage: "dollarsign.circle.fill") {
            appTextField("Starting Balance", text: $startingBalanceText)
            appTextField("Balance", text: $balanceText)
            appTextField("Equity", text: $equityText)
        }
    }

    private var brokerageCard: some View {
        sectionCard("Brokerage Funds", systemImage: "banknote.fill") {
            appTextField("Buying Power", text: $buyingPowerText)
            appTextField("Cash Balance", text: $cashBalanceText)
            appTextField("Available Funds", text: $availableFundsText)

            Text("IBKR, Fidelity, Webull, and Robinhood should use cash/margin fields, not prop-firm drawdown rules.")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var cryptoCard: some View {
        sectionCard("Crypto Exchange Funds", systemImage: "bitcoinsign.circle.fill") {
            appTextField("Cash / USD Balance", text: $cashBalanceText)
            appTextField("Available Funds", text: $availableFundsText)
            appTextField("Buying Power optional", text: $buyingPowerText)

            Text("Coinbase, Kraken, and Crypto.com are exchange accounts. They are not prop firms.")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var propRulesCard: some View {
        sectionCard("Prop Rules / Targets", systemImage: "shield.lefthalf.filled") {
            appTextField("Daily Drawdown Limit", text: $dailyDrawdownLimitText)
            appTextField("Max Drawdown Limit", text: $maxDrawdownLimitText)
            appTextField("Daily Drawdown Remaining", text: $dailyDrawdownRemainingText)
            appTextField("Max Drawdown Remaining", text: $maxDrawdownRemainingText)
            appTextField("Profit Target", text: $profitTargetText)
            appTextField("Profit Target Remaining", text: $profitTargetRemainingText)
            appTextField("Payout Target", text: $payoutTargetText)
        }
    }

    private var pnlCard: some View {
        sectionCard("P/L", systemImage: "chart.line.uptrend.xyaxis") {
            appTextField("Daily P/L", text: $dailyPnlText)
            appTextField("Unrealized P/L", text: $unrealizedPnlText)
            appTextField("Realized P/L", text: $realizedPnlText)
        }
    }

    private var notesCard: some View {
        sectionCard("Notes", systemImage: "note.text") {
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
            propFirmName: isPropFirmBroker ? selectedPropFirm.displayName : nil,
            propModel: isPropFirmBroker ? selectedPropModel.displayName : nil,
            platform: selectedBroker.displayName,
            startingBalance: double(startingBalanceText),
            balance: double(balanceText),
            equity: double(equityText),
            buyingPower: double(buyingPowerText),
            cashBalance: double(cashBalanceText),
            availableFunds: double(availableFundsText),
            dailyDrawdownLimit: isPropFirmBroker ? double(dailyDrawdownLimitText) : nil,
            maxDrawdownLimit: isPropFirmBroker ? double(maxDrawdownLimitText) : nil,
            dailyDrawdownRemaining: isPropFirmBroker ? double(dailyDrawdownRemainingText) : nil,
            maxDrawdownRemaining: isPropFirmBroker ? double(maxDrawdownRemainingText) : nil,
            profitTarget: isPropFirmBroker ? double(profitTargetText) : nil,
            profitTargetRemaining: isPropFirmBroker ? double(profitTargetRemainingText) : nil,
            payoutTarget: isPropFirmBroker ? double(payoutTargetText) : nil,
            dailyPnl: double(dailyPnlText),
            unrealizedPnl: double(unrealizedPnlText),
            realizedPnl: double(realizedPnlText),
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
            applyBrokerDefaults(selectedBroker, resetIdentity: true)
            return
        }

        selectedBroker = BrokerPreset.from(account.broker) ?? .aquaFunding

        if selectedBroker == .tradeThePool {
            selectedPropFirm = .tradeThePool
        } else if selectedBroker == .aquaFunding {
            selectedPropFirm = .aquaFunding
        } else {
            selectedPropFirm = PropFirmPreset.from(account.propFirmName ?? account.broker)
        }

        selectedPropModel = PropAccountModelPreset.allCases.first {
            $0.displayName.lowercased() == (account.propModel ?? account.accountType ?? "").lowercased()
        } ?? .other

        selectedBrokerAccountType = BrokerCashMarginType.from(account.accountType)

        accountIdText = account.accountId
        accountNameText = account.accountName ?? ""
        accountNumberText = account.accountNumber ?? ""

        accountModeText = account.accountMode ?? defaultAccountMode(for: selectedBroker)
        accountTypeText = account.accountType ?? defaultAccountType(for: selectedBroker)

        startingBalanceText = formatNumber(account.startingBalance)
        balanceText = formatNumber(account.balance)
        equityText = formatNumber(account.equity)

        buyingPowerText = formatNumber(account.buyingPower)
        cashBalanceText = formatNumber(account.cashBalance)
        availableFundsText = formatNumber(account.availableFunds)

        dailyDrawdownLimitText = formatNumber(account.dailyDrawdownLimit)
        maxDrawdownLimitText = formatNumber(account.maxDrawdownLimit)
        dailyDrawdownRemainingText = formatNumber(account.dailyDrawdownRemaining)
        maxDrawdownRemainingText = formatNumber(account.maxDrawdownRemaining)

        profitTargetText = formatNumber(account.profitTarget)
        profitTargetRemainingText = formatNumber(account.profitTargetRemaining)
        payoutTargetText = formatNumber(account.payoutTarget)

        dailyPnlText = formatNumber(account.dailyPnl)
        unrealizedPnlText = formatNumber(account.unrealizedPnl)
        realizedPnlText = formatNumber(account.realizedPnl)

        notesText = account.notes ?? ""
    }

    private func applyBrokerDefaults(
        _ broker: BrokerPreset,
        resetIdentity: Bool
    ) {
        if broker == .aquaFunding {
            selectedPropFirm = .aquaFunding
        }

        if broker == .tradeThePool {
            selectedPropFirm = .tradeThePool
        }

        accountModeText = defaultAccountMode(for: broker)
        accountTypeText = defaultAccountType(for: broker)

        if !isPropFirmBroker {
            selectedPropModel = .other
        }

        if resetIdentity {
            accountIdText = defaultAccountId()
            accountNameText = defaultAccountName()
        }
    }

    private func defaultAccountMode(for broker: BrokerPreset) -> String {
        if broker == .aquaFunding || broker == .tradeThePool {
            return "prop"
        }

        if broker == .coinbase || broker == .kraken || broker == .cryptoDotCom {
            return "crypto"
        }

        return "live"
    }

    private func defaultAccountType(for broker: BrokerPreset) -> String {
        if broker == .aquaFunding || broker == .tradeThePool {
            return selectedPropModel.displayName
        }

        if broker == .coinbase || broker == .kraken || broker == .cryptoDotCom {
            return "Exchange"
        }

        return selectedBrokerAccountType.rawValue
    }

    private func defaultAccountName() -> String {
        if isPropFirmBroker {
            return "\(selectedPropFirm.displayName) \(selectedPropModel.displayName)"
        }

        if isCryptoBroker {
            return "\(selectedBroker.displayName) Exchange"
        }

        return "\(selectedBroker.displayName) \(selectedBrokerAccountType.rawValue)"
    }

    private func defaultAccountId() -> String {
        let broker = selectedBroker.apiValue

        let type: String = {
            if isPropFirmBroker {
                return selectedPropModel.displayName
            }

            if isCryptoBroker {
                return "exchange"
            }

            return selectedBrokerAccountType.rawValue
        }()

        let cleanedType = type
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")

        let size = clean(startingBalanceText) ?? "main"

        return "\(broker)-\(cleanedType)-\(size)"
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: " ", with: "-")
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
