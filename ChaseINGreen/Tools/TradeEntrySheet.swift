//
//  TradeEntrySheet.swift
//  ChaseINGreen
//
//  Created by Otis Young on 4/16/26.
//

import SwiftUI

enum TradeDirectionOption: String, CaseIterable, Identifiable {
    case long
    case short

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct TradeEntryDraft {
    var symbol: String
    var direction: TradeDirectionOption = .long

    var entryPriceText = ""
    var currentPriceText = ""
    var stopLossText = ""
    var takeProfitText = ""
    var quantityText = ""
    var accountSizeText = "5000"

    var selectedBroker: BrokerPreset = .aquaFunding
    var brokerAccountNameText = ""
    var brokerAccountLast4Text = ""
    var accountGroupKeyText = ""

    var maxDailyLossText = ""
    var maxTotalLossText = ""
    var payoutTargetText = ""

    var notes = ""
}

struct TradeEntrySheet: View {
    let symbol: String
    let currentPrice: Double?
    let brokerAccounts: [BrokerAccountResponse]
    let accessToken: String?
    let onSave: (LoggedTradeCreateRequest) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: TradeEntryDraft
    @State private var pressedSize: Double?
    @State private var selectedBrokerAccountId: UUID?

    private let quickSizes: [Double] = [0.01, 0.02, 0.05, 0.10, 1, 5, 10, 25, 50, 100]

    init(
        symbol: String,
        currentPrice: Double?,
        brokerAccounts: [BrokerAccountResponse] = [],
        accessToken: String? = nil,
        onSave: @escaping (LoggedTradeCreateRequest) -> Void
    ) {
        self.symbol = symbol
        self.currentPrice = currentPrice
        self.brokerAccounts = brokerAccounts
        self.accessToken = accessToken
        self.onSave = onSave

        var initialDraft = TradeEntryDraft(symbol: symbol.uppercased())

        if let currentPrice {
            initialDraft.entryPriceText = String(format: "%.2f", currentPrice)
            initialDraft.currentPriceText = String(format: "%.2f", currentPrice)
        }

        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headerCard
                        tradeSection
                        riskSizeSection
                        brokerSection
                        propRulesSection
                        notesSection
                        saveButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Quick Trade Entry")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppTheme.gold)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Log Trade")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Fast entry for \(draft.symbol)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()
            }

            Text("Pick a saved account when possible so P/L, drawdown, and payout tracking stay grouped correctly.")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .appCard()
    }

    private var tradeSection: some View {
        sectionCard("Trade", systemImage: "chart.line.uptrend.xyaxis") {
            HStack {
                Text("Symbol")
                    .foregroundStyle(AppTheme.secondaryText)

                Spacer()

                Text(draft.symbol)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(AppTheme.softGold)
            }

            Picker("Direction", selection: $draft.direction) {
                ForEach(TradeDirectionOption.allCases) { direction in
                    Text(direction.title).tag(direction)
                }
            }
            .pickerStyle(.segmented)

            appTextField("Entry Price", text: $draft.entryPriceText)

            if let currentPrice {
                glassMiniButton("Use Current Price \(String(format: "%.2f", currentPrice))") {
                    let formatted = String(format: "%.2f", currentPrice)
                    draft.entryPriceText = formatted
                    draft.currentPriceText = formatted
                }
            }
        }
    }

    private var riskSizeSection: some View {
        sectionCard("Risk / Size", systemImage: "shield.lefthalf.filled") {
            appTextField("Current Price optional", text: $draft.currentPriceText)
            appTextField("Stop Loss optional", text: $draft.stopLossText)
            appTextField("Take Profit optional", text: $draft.takeProfitText)
            appTextField("Quantity / Shares / Lots", text: $draft.quantityText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(quickSizes, id: \.self) { size in
                        Button {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                pressedSize = size
                                draft.quantityText = formatQuickSize(size)
                            }

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                pressedSize = nil
                            }
                        } label: {
                            Text(formatQuickSize(size))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(.white.opacity(0.10))
                                .overlay {
                                    Capsule()
                                        .stroke(AppTheme.gold.opacity(0.35), lineWidth: 1)
                                }
                                .clipShape(Capsule())
                                .scaleEffect(pressedSize == size ? 0.94 : 1.0)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            appTextField("Account Size", text: $draft.accountSizeText)
        }
    }

    private var brokerSection: some View {
        sectionCard("Broker / Account", systemImage: "building.columns.fill") {
            if !brokerAccounts.isEmpty {
                Picker("Saved Account", selection: $selectedBrokerAccountId) {
                    Text("No saved account").tag(UUID?.none)

                    ForEach(brokerAccounts, id: \.id) { account in
                        Text(accountPickerTitle(account))
                            .tag(UUID?.some(account.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.gold)
                .onChange(of: selectedBrokerAccountId) { _, newValue in
                    applySelectedBrokerAccount(newValue)
                }
            }

            Picker("Broker", selection: $draft.selectedBroker) {
                ForEach(BrokerPreset.allCases) { broker in
                    Text(broker.displayName).tag(broker)
                }
            }

            Text(draft.selectedBroker.integrationStatus)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.secondaryText)

            appTextField("Account Name, ex: Aqua 250K #1", text: $draft.brokerAccountNameText)
            appTextField("Account Last 4 optional", text: $draft.brokerAccountLast4Text)
            appTextField("Group Key, ex: aqua-250k-1", text: $draft.accountGroupKeyText)

            Text("Saved accounts are optional. Users can still log trades without one.")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var propRulesSection: some View {
        sectionCard("Prop / Account Rules", systemImage: "exclamationmark.shield.fill") {
            appTextField("Max Daily Loss Allowed", text: $draft.maxDailyLossText)
            appTextField("Max Total Loss Allowed", text: $draft.maxTotalLossText)
            appTextField("Payout Target", text: $draft.payoutTargetText)
        }
    }

    private var notesSection: some View {
        sectionCard("Notes", systemImage: "note.text") {
            TextField("Optional notes", text: $draft.notes, axis: .vertical)
                .lineLimit(3...5)
                .font(AppTheme.bodyFont)
                .padding(12)
                .background(.white.opacity(0.10))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var saveButton: some View {
        Button {
            saveTrade()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Save Trade")
                    .font(.system(size: 19, weight: .black))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(canSave ? .black : AppTheme.mutedText)
            .background(canSave ? AppTheme.gold : .white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    private func applySelectedBrokerAccount(_ id: UUID?) {
        guard let id,
              let account = brokerAccounts.first(where: { $0.id == id }) else {
            return
        }

        draft.selectedBroker = brokerPreset(for: account.broker)
        draft.brokerAccountNameText = account.accountName ?? account.accountId
        draft.brokerAccountLast4Text = account.accountNumber ?? ""
        draft.accountGroupKeyText = account.accountId

        if let startingBalance = account.startingBalance ?? account.balance ?? account.equity {
            draft.accountSizeText = formatAccountNumber(startingBalance)
        }

        if let dailyLimit = account.dailyDrawdownLimit {
            draft.maxDailyLossText = formatAccountNumber(dailyLimit)
        }

        if let maxLimit = account.maxDrawdownLimit {
            draft.maxTotalLossText = formatAccountNumber(maxLimit)
        }

        if let payoutTarget = account.payoutTarget ?? account.profitTarget {
            draft.payoutTargetText = formatAccountNumber(payoutTarget)
        }
    }

    private func accountPickerTitle(_ account: BrokerAccountResponse) -> String {
        let name = account.accountName ?? account.accountId
        let broker = brokerPreset(for: account.broker).displayName
        let size = account.startingBalance ?? account.balance ?? account.equity

        if let size {
            return "\(broker) • \(name) • \(formatPlainMoney(size))"
        }

        return "\(broker) • \(name)"
    }

    private func brokerPreset(for raw: String) -> BrokerPreset {
        let cleaned = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        switch cleaned {
        case "aqua", "aqua_funded", "aqua funded", "aqua funding":
            return .aquaFunding
        case "trade_the_pool", "trade the pool", "ttp":
            return .tradeThePool
        case "ibkr", "interactive brokers":
            return .ibkr
        case "fidelity":
            return .fidelity
        case "robinhood":
            return .robinhood
        case "webull":
            return .webull
        case "coinbase":
            return .coinbase
        case "kraken":
            return .kraken
        case "crypto.com", "crypto_com":
            return .cryptoDotCom
        default:
            return BrokerPreset.from(raw) ?? .aquaFunding
        }
    }

    private func sectionCard<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
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

    private func glassMiniButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.softGold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(.white.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppTheme.gold.opacity(0.35), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var canSave: Bool {
        Double(draft.entryPriceText) != nil
    }

    private func saveTrade() {
        guard let entryPrice = Double(draft.entryPriceText) else { return }

        let accountName = cleanOrNil(draft.brokerAccountNameText)
        let accountLast4 = cleanOrNil(draft.brokerAccountLast4Text)
        let accountGroupKey = cleanOrNil(draft.accountGroupKeyText) ?? fallbackAccountGroupKey()

        let payload = LoggedTradeCreateRequest(
            userId: nil,
            symbol: draft.symbol.uppercased(),
            direction: draft.direction.rawValue,
            entryPrice: entryPrice,
            currentPrice: doubleOrNil(draft.currentPriceText),
            stopLoss: doubleOrNil(draft.stopLossText),
            takeProfit: doubleOrNil(draft.takeProfitText),
            quantity: doubleOrNil(draft.quantityText),
            accountSize: doubleOrNil(draft.accountSizeText),
            platform: draft.selectedBroker.displayName,
            brokerAccountId: accountGroupKey,
            brokerAccountName: accountName,
            brokerAccountNumberLast4: accountLast4,
            accountGroupKey: accountGroupKey,
            parentTradeGroupId: nil,
            maxDailyLossAllowed: doubleOrNil(draft.maxDailyLossText),
            maxTotalLossAllowed: doubleOrNil(draft.maxTotalLossText),
            payoutTarget: doubleOrNil(draft.payoutTargetText),
            notes: cleanOrNil(draft.notes)
        )

        onSave(payload)
        dismiss()
    }

    private func fallbackAccountGroupKey() -> String {
        let broker = draft.selectedBroker.displayName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ".", with: "")

        let size = cleanOrNil(draft.accountSizeText) ?? "unknown"
        return "\(broker)-\(size)"
    }

    private func cleanOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func doubleOrNil(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : Double(trimmed)
    }

    private func formatQuickSize(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        }

        return String(format: "%.2f", value)
    }

    private func formatAccountNumber(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        }

        return String(format: "%.2f", value)
    }

    private func formatPlainMoney(_ value: Double) -> String {
        String(format: "$%.0f", value)
    }
}

#Preview {
    TradeEntrySheet(
        symbol: "TQQQ",
        currentPrice: 72.42,
        brokerAccounts: [],
        accessToken: nil
    ) { _ in }
}
