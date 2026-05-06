//
//  TradeActionSheet.swift
//  ChaseINGreen
//

import SwiftUI

struct TradeActionSheet: View {
    let prompt: TradeActionPrompt
    let currentQuotePrice: Double?
    let accessToken: String
    let onComplete: () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var valueText = ""
    @State private var noteText = ""

    @State private var editSymbolText = ""
    @State private var editDirection: TradeDirectionOption = .long
    @State private var editEntryPriceText = ""
    @State private var editOpenedAtText = ""
    @State private var editCurrentPriceText = ""
    @State private var editStopLossText = ""
    @State private var editTakeProfitText = ""
    @State private var editQuantityText = ""
    @State private var editAccountSizeText = ""
    @State private var editBroker: BrokerPreset = .aquaFunding
    @State private var editBrokerAccountNameText = ""
    @State private var editBrokerLast4Text = ""
    @State private var editAccountGroupKeyText = ""
    @State private var editMaxDailyLossText = ""
    @State private var editMaxTotalLossText = ""
    @State private var editPayoutTargetText = ""

    @State private var errorMessage: String?
    @State private var isSaving = false

    private var isEditTradeMode: Bool {
        if case .editTrade = prompt {
            return true
        }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                tradeSummarySection

                if isEditTradeMode {
                    editTradeSections
                } else if prompt.needsValue {
                    Section(valueTitle) {
                        TextField(valuePlaceholder, text: $valueText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Note") {
                    TextField("Optional note", text: $noteText, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            await submit()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(saveButtonTitle)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .navigationTitle(prompt.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupInitialValues()
            }
        }
    }

    private var tradeSummarySection: some View {
        Section("Trade") {
            Text(prompt.trade.symbol)
            Text(prompt.trade.direction.capitalized)
            Text("Entry: \(format(prompt.trade.entryPrice))")

            if let accountName = prompt.trade.brokerAccountName, !accountName.isEmpty {
                Text("Account: \(accountName)")
                    .foregroundStyle(.secondary)
            }

            if let platform = prompt.trade.platform, !platform.isEmpty {
                Text("Broker: \(platform)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var editTradeSections: some View {
        Group {
            Section("Correct Trade Info") {
                TextField("Symbol", text: $editSymbolText)
                    .textInputAutocapitalization(.characters)
                    .disableAutocorrection(true)

                Picker("Direction", selection: $editDirection) {
                    ForEach(TradeDirectionOption.allCases) { direction in
                        Text(direction.title).tag(direction)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Entry Price", text: $editEntryPriceText)
                    .keyboardType(.decimalPad)

                TextField("Opened At ISO Time", text: $editOpenedAtText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                TextField("Current Broker Price", text: $editCurrentPriceText)
                    .keyboardType(.decimalPad)
            }

            Section("Risk / Size") {
                TextField("Stop Loss", text: $editStopLossText)
                    .keyboardType(.decimalPad)

                TextField("Take Profit", text: $editTakeProfitText)
                    .keyboardType(.decimalPad)

                TextField("Quantity / Shares / Lots", text: $editQuantityText)
                    .keyboardType(.decimalPad)

                TextField("Account Size", text: $editAccountSizeText)
                    .keyboardType(.decimalPad)
            }

            Section("Broker / Account") {
                Picker("Broker", selection: $editBroker) {
                    ForEach(BrokerPreset.allCases) { broker in
                        Text(broker.displayName).tag(broker)
                    }
                }

                Text(editBroker.integrationStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Account Name", text: $editBrokerAccountNameText)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)

                TextField("Account Last 4", text: $editBrokerLast4Text)
                    .keyboardType(.numberPad)

                TextField("Group Key", text: $editAccountGroupKeyText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }

            Section("Prop / Account Rules") {
                TextField("Max Daily Loss Allowed", text: $editMaxDailyLossText)
                    .keyboardType(.decimalPad)

                TextField("Max Total Loss Allowed", text: $editMaxTotalLossText)
                    .keyboardType(.decimalPad)

                TextField("Payout Target", text: $editPayoutTargetText)
                    .keyboardType(.decimalPad)
            }
        }
    }

    private var valueTitle: String {
        switch prompt {
        case .editTrade: return "Edit Trade"
        case .brokerPrice: return "Broker Price"
        case .stopLoss: return "Stop Loss"
        case .takeProfit: return "Take Profit"
        case .quantity: return "Current Quantity"
        case .reduce: return "New Smaller Quantity"
        case .add: return "Quantity Added"
        case .close, .stopLossHit, .takeProfitHit: return "Exit Price"
        case .clearStopLoss, .clearTakeProfit: return ""
        }
    }

    private var valuePlaceholder: String {
        switch prompt {
        case .editTrade: return ""
        case .reduce: return "New quantity you still hold"
        case .add: return "Amount added"
        case .close: return "Broker fill price"
        case .stopLossHit: return "Stop fill price"
        case .takeProfitHit: return "Target fill price"
        default: return "Value"
        }
    }

    private var saveButtonTitle: String {
        switch prompt {
        case .editTrade: return "Save Corrections"
        case .close: return "Close Trade"
        case .stopLossHit: return "Mark Stop Hit"
        case .takeProfitHit: return "Mark Target Hit"
        case .clearStopLoss: return "Remove Stop Loss"
        case .clearTakeProfit: return "Remove Take Profit"
        default: return "Save"
        }
    }

    private func setupInitialValues() {
        valueText = formatForInput(prompt.defaultValue(currentQuotePrice: currentQuotePrice))

        guard isEditTradeMode else { return }

        let trade = prompt.trade

        editSymbolText = trade.symbol
        editDirection = trade.direction.lowercased() == "short" ? .short : .long
        editEntryPriceText = formatForInput(trade.entryPrice)
        editOpenedAtText = trade.openedAt
        editCurrentPriceText = formatForInput(trade.currentPrice)
        editStopLossText = formatForInput(trade.stopLoss)
        editTakeProfitText = formatForInput(trade.takeProfit)
        editQuantityText = formatForInput(trade.quantity)
        editAccountSizeText = formatForInput(trade.accountSize)
        editBroker = BrokerPreset.from(trade.platform) ?? .aquaFunding
        editBrokerAccountNameText = trade.brokerAccountName ?? ""
        editBrokerLast4Text = trade.brokerAccountNumberLast4 ?? ""
        editAccountGroupKeyText = trade.accountGroupKey ?? ""
        editMaxDailyLossText = formatForInput(trade.maxDailyLossAllowed)
        editMaxTotalLossText = formatForInput(trade.maxTotalLossAllowed)
        editPayoutTargetText = formatForInput(trade.payoutTarget)
    }

    private func submit() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let note = cleanOrNil(noteText)
        let value = Double(valueText)

        do {
            switch prompt {
            case .editTrade(let trade):
                guard let entryPrice = doubleOrNil(editEntryPriceText) else {
                    throw TradeActionError.invalidValue("Invalid entry price.")
                }

                let groupKey = cleanOrNil(editAccountGroupKeyText) ?? fallbackAccountGroupKey()

                _ = try await APIService.shared.updateTrade(
                    tradeId: trade.id,
                    symbol: cleanOrNil(editSymbolText)?.uppercased(),
                    direction: editDirection.rawValue,
                    entryPrice: entryPrice,
                    openedAt: cleanOrNil(editOpenedAtText),
                    currentPrice: doubleOrNil(editCurrentPriceText),
                    stopLoss: doubleOrNil(editStopLossText),
                    takeProfit: doubleOrNil(editTakeProfitText),
                    quantity: doubleOrNil(editQuantityText),
                    accountSize: doubleOrNil(editAccountSizeText),
                    platform: editBroker.displayName,
                    brokerAccountId: groupKey,
                    brokerAccountName: cleanOrNil(editBrokerAccountNameText),
                    brokerAccountNumberLast4: cleanOrNil(editBrokerLast4Text),
                    accountGroupKey: groupKey,
                    parentTradeGroupId: trade.parentTradeGroupId,
                    maxDailyLossAllowed: doubleOrNil(editMaxDailyLossText),
                    maxTotalLossAllowed: doubleOrNil(editMaxTotalLossText),
                    payoutTarget: doubleOrNil(editPayoutTargetText),
                    notes: note ?? "Trade details corrected.",
                    accessToken: accessToken
                )

            case .brokerPrice(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid broker price.") }
                _ = try await APIService.shared.updateBrokerPrice(
                    tradeId: trade.id,
                    currentPrice: value,
                    notes: note ?? "Broker price manually updated.",
                    accessToken: accessToken
                )

            case .stopLoss(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid stop loss.") }
                _ = try await APIService.shared.updateTrade(
                    tradeId: trade.id,
                    stopLoss: value,
                    notes: note ?? "Stop loss set to \(value).",
                    accessToken: accessToken
                )

            case .clearStopLoss(let trade):
                _ = try await APIService.shared.updateTrade(
                    tradeId: trade.id,
                    clearStopLoss: true,
                    notes: note ?? "Stop loss removed.",
                    accessToken: accessToken
                )

            case .takeProfit(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid take profit.") }
                _ = try await APIService.shared.updateTrade(
                    tradeId: trade.id,
                    takeProfit: value,
                    notes: note ?? "Take profit set to \(value).",
                    accessToken: accessToken
                )

            case .clearTakeProfit(let trade):
                _ = try await APIService.shared.updateTrade(
                    tradeId: trade.id,
                    clearTakeProfit: true,
                    notes: note ?? "Take profit removed.",
                    accessToken: accessToken
                )

            case .quantity(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid quantity.") }
                _ = try await APIService.shared.updateTrade(
                    tradeId: trade.id,
                    quantity: value,
                    notes: note ?? "Quantity updated to \(value).",
                    accessToken: accessToken
                )

            case .reduce(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid reduced quantity.") }
                _ = try await APIService.shared.reduceTrade(
                    tradeId: trade.id,
                    newQuantity: value,
                    currentPrice: currentQuotePrice,
                    notes: note ?? "Position reduced. New quantity: \(value).",
                    accessToken: accessToken
                )

            case .add(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid add quantity.") }
                _ = try await APIService.shared.addToTrade(
                    tradeId: trade.id,
                    addQuantity: value,
                    currentPrice: currentQuotePrice,
                    notes: note ?? "Added \(value) to position.",
                    accessToken: accessToken
                )

            case .close(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid exit price.") }
                _ = try await APIService.shared.closeTrade(
                    tradeId: trade.id,
                    exitPrice: value,
                    closeReason: "manual_close",
                    notes: note ?? "Trade manually closed at \(value).",
                    accessToken: accessToken
                )

            case .stopLossHit(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid stop fill price.") }
                _ = try await APIService.shared.markStopLossHit(
                    tradeId: trade.id,
                    exitPrice: value,
                    notes: note ?? "Stop loss hit at \(value).",
                    accessToken: accessToken
                )

            case .takeProfitHit(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid target fill price.") }
                _ = try await APIService.shared.markTakeProfitHit(
                    tradeId: trade.id,
                    exitPrice: value,
                    notes: note ?? "Take profit hit at \(value).",
                    accessToken: accessToken
                )
            }

            await onComplete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fallbackAccountGroupKey() -> String {
        let broker = editBroker.displayName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ".", with: "")

        let size = cleanOrNil(editAccountSizeText) ?? "unknown"
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

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func formatForInput(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.2f", value)
    }
}

private enum TradeActionError: LocalizedError {
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case .invalidValue(let message):
            return message
        }
    }
}
