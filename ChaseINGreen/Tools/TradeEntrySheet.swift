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

    var title: String {
        rawValue.capitalized
    }
}

struct TradeEntryDraft {
    var symbol: String
    var direction: TradeDirectionOption = .long

    var entryPriceText: String = ""
    var currentPriceText: String = ""
    var stopLossText: String = ""
    var takeProfitText: String = ""
    var quantityText: String = ""
    var accountSizeText: String = "5000"

    var selectedBroker: BrokerPreset = .aquaFunding
    var brokerAccountNameText: String = ""
    var brokerAccountLast4Text: String = ""
    var accountGroupKeyText: String = ""

    var maxDailyLossText: String = ""
    var maxTotalLossText: String = ""
    var payoutTargetText: String = ""

    var notes: String = ""
}

struct TradeEntrySheet: View {
    let symbol: String
    let currentPrice: Double?
    let onSave: (LoggedTradeCreateRequest) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var draft: TradeEntryDraft

    private let quickSizes: [Double] = [0.01, 0.02, 0.05, 0.10, 1, 5, 10, 25, 50, 100]

    init(
        symbol: String,
        currentPrice: Double?,
        onSave: @escaping (LoggedTradeCreateRequest) -> Void
    ) {
        self.symbol = symbol
        self.currentPrice = currentPrice
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
            Form {
                tradeSection
                riskSizeSection
                brokerSection
                propRulesSection
                notesSection
            }
            .navigationTitle("Quick Trade Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTrade()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var tradeSection: some View {
        Section("Trade") {
            HStack {
                Text("Symbol")
                Spacer()
                Text(draft.symbol)
                    .foregroundStyle(.secondary)
            }

            Picker("Direction", selection: $draft.direction) {
                ForEach(TradeDirectionOption.allCases) { direction in
                    Text(direction.title).tag(direction)
                }
            }
            .pickerStyle(.segmented)

            appTextField("Entry Price", text: $draft.entryPriceText)

            if let currentPrice {
                Button("Use Current Price (\(currentPrice, specifier: "%.2f"))") {
                    let formatted = String(format: "%.2f", currentPrice)
                    draft.entryPriceText = formatted
                    draft.currentPriceText = formatted
                }
            }
        }
    }

    private var riskSizeSection: some View {
        Section("Risk / Size") {
            appTextField("Current Price (optional)", text: $draft.currentPriceText)
            appTextField("Stop Loss (optional)", text: $draft.stopLossText)
            appTextField("Take Profit (optional)", text: $draft.takeProfitText)
            appTextField("Quantity / Shares / Lots", text: $draft.quantityText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(quickSizes, id: \.self) { size in
                        Button {
                            draft.quantityText = formatQuickSize(size)
                        } label: {
                            Text(formatQuickSize(size))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            appTextField("Account Size", text: $draft.accountSizeText)
        }
    }

    private var brokerSection: some View {
        Section("Broker / Account") {
            Picker("Broker", selection: $draft.selectedBroker) {
                ForEach(BrokerPreset.allCases) { broker in
                    Text(broker.displayName).tag(broker)
                }
            }

            Text(draft.selectedBroker.integrationStatus)
                .font(.caption)
                .foregroundStyle(.secondary)

            appTextField("Account Name, ex: Aqua 250K #1", text: $draft.brokerAccountNameText)
            appTextField("Account Last 4 (optional)", text: $draft.brokerAccountLast4Text)
            appTextField("Group Key, ex: aqua-250k-1", text: $draft.accountGroupKeyText)

            Text("Use a unique group key for each real account so P/L and price updates stay grouped correctly.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var propRulesSection: some View {
        Section("Prop / Account Rules") {
            appTextField("Max Daily Loss Allowed", text: $draft.maxDailyLossText)
            appTextField("Max Total Loss Allowed", text: $draft.maxTotalLossText)
            appTextField("Payout Target", text: $draft.payoutTargetText)
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Optional notes", text: $draft.notes, axis: .vertical)
                .lineLimit(3...5)
        }
    }

    private func appTextField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .textFieldStyle(RoundedBorderTextFieldStyle())
    }

    private var canSave: Bool {
        Double(draft.entryPriceText) != nil
    }

    private func saveTrade() {
        guard let entryPrice = Double(draft.entryPriceText) else {
            return
        }

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
}

#Preview {
    TradeEntrySheet(
        symbol: "TQQQ",
        currentPrice: 72.42
    ) { _ in }
}
