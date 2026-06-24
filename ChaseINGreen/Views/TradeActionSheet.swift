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
    @State private var exitPriceConfirmed = true

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
    
    private func decimalKeyboardIfAvailable<Content: View>(_ view: Content) -> some View {
    #if os(iOS)
        return view.keyboardType(.decimalPad)
    #else
        return view
    #endif
    }

    private var isEditTradeMode: Bool {
        if case .editTrade = prompt { return true }
        return false
    }

    private var isCloseMode: Bool {
        switch prompt {
        case .close, .stopLossHit, .takeProfitHit:
            return true
        default:
            return false
        }
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    tradeSummarySection

                    if isEditTradeMode {
                        editTradeSections
                    } else if prompt.needsValue {
                        Section {
                            decimalKeyboardIfAvailable(
                                appTextField("Entry Price", text: $editEntryPriceText)
                            )

                            if isCloseMode {
                                Toggle("Exit price is confirmed", isOn: $exitPriceConfirmed)
                                    .tint(AppTheme.gold)
                                    .foregroundStyle(AppTheme.primaryText)

                                Text(exitPriceConfirmed
                                     ? "This will realize P/L using the price above."
                                     : "This will close the trade as unconfirmed. We will not pretend this is the true fill.")
                                    .font(AppTheme.captionFont)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        } header: {
                            sectionHeader(valueTitle)
                        }
                        .listRowBackground(AppTheme.cardBlack)
                    }

                    Section {
                        TextField("Optional note", text: $noteText, axis: .vertical)
                            .lineLimit(2...4)
                            .appTextField()
                            .foregroundStyle(AppTheme.primaryText)
                            .tint(AppTheme.gold)
                    } header: {
                        sectionHeader("Note")
                    }
                    .listRowBackground(AppTheme.cardBlack)

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.danger)
                        }
                        .listRowBackground(AppTheme.cardBlack)
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
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [
                                    AppTheme.gold.opacity(0.95),
                                    AppTheme.softGold.opacity(0.78)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(AppTheme.deepBlack)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .disabled(isSaving)
                        .opacity(isSaving ? 0.65 : 1.0)
                    }
                    .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
                .foregroundStyle(AppTheme.primaryText)
            }
            .navigationTitle(prompt.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.softGold)
                }
            }
            .onAppear {
                setupInitialValues()
            }
        }
    }

    private var tradeSummarySection: some View {
        Section {
            Text(prompt.trade.symbol)
                .font(.headline.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text(prompt.trade.direction.capitalized)
                .foregroundStyle(AppTheme.primaryText)

            Text("Entry: \(format(prompt.trade.entryPrice))")
                .foregroundStyle(AppTheme.primaryText)

            if let accountName = prompt.trade.brokerAccountName, !accountName.isEmpty {
                Text("Account: \(accountName)")
                    .foregroundStyle(AppTheme.secondaryText)
            }

            if let platform = prompt.trade.platform, !platform.isEmpty {
                Text("Broker: \(platform)")
                    .foregroundStyle(AppTheme.secondaryText)
            }
        } header: {
            sectionHeader("Trade")
        }
        .listRowBackground(AppTheme.cardBlack)
    }

    private var editTradeSections: some View {
        Group {
            Section {
                appTextField("Symbol", text: $editSymbolText)

                Picker("Direction", selection: $editDirection) {
                    ForEach(TradeDirectionOption.allCases) { direction in
                        Text(direction.title).tag(direction)
                    }
                }
                .pickerStyle(.segmented)

                decimalKeyboardIfAvailable(
                    appTextField(valuePlaceholder, text: $valueText)
                )

                appTextField("Opened At ISO Time", text: $editOpenedAtText)

                decimalKeyboardIfAvailable(
                    appTextField("Current Broker Price", text: $editCurrentPriceText)
                )
            } header: {
                sectionHeader("Correct Trade Info")
            }
            .listRowBackground(AppTheme.cardBlack)

            Section {
                decimalKeyboardIfAvailable(
                    appTextField("Stop Loss", text: $editStopLossText)
                )

                decimalKeyboardIfAvailable(
                    appTextField("Take Profit", text: $editTakeProfitText)
                )

                decimalKeyboardIfAvailable(
                    appTextField("Quantity / Shares / Lots", text: $editQuantityText)
                )

                decimalKeyboardIfAvailable(
                    appTextField("Account Size", text: $editAccountSizeText)
                )
            } header: {
                sectionHeader("Risk / Size")
            }
            .listRowBackground(AppTheme.cardBlack)

            Section {
                Picker("Broker", selection: $editBroker) {
                    ForEach(BrokerPreset.allCases) { broker in
                        Text(broker.displayName).tag(broker)
                    }
                }
                .foregroundStyle(AppTheme.primaryText)
                .tint(AppTheme.gold)

                Text(editBroker.integrationStatus)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)

                appTextField("Account Name", text: $editBrokerAccountNameText)
                appTextField("Account Last 4", text: $editBrokerLast4Text)
                appTextField("Group Key", text: $editAccountGroupKeyText)
            } header: {
                sectionHeader("Broker / Account")
            }
            .listRowBackground(AppTheme.cardBlack)

            Section {
                decimalKeyboardIfAvailable(
                    appTextField("Max Daily Loss Allowed", text: $editMaxDailyLossText)
                )

                decimalKeyboardIfAvailable(
                    appTextField("Max Total Loss Allowed", text: $editMaxTotalLossText)
                )

                decimalKeyboardIfAvailable(
                    appTextField("Payout Target", text: $editPayoutTargetText)
                )
            } header: {
                sectionHeader("Prop / Account Rules")
            }
            .listRowBackground(AppTheme.cardBlack)
        }
    }

    private func appTextField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .font(.system(size: 17, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.deepBlack.opacity(0.88))
            .foregroundStyle(AppTheme.primaryText)
            .tint(AppTheme.gold)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.gold.opacity(0.42), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(AppTheme.softGold)
            .textCase(nil)
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
        case .brokerPrice: return "Broker price"
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
        exitPriceConfirmed = isCloseMode

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
        let value = doubleOrNil(valueText)

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

                await logTradeAction(
                    trade: trade,
                    intent: "update",
                    outcome: "open",
                    notes: note ?? "Trade details corrected."
                )

            case .brokerPrice(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid broker price.") }

                _ = try await APIService.shared.updateBrokerPrice(
                    tradeId: trade.id,
                    currentPrice: value,
                    notes: note ?? "Broker price manually updated.",
                    accessToken: accessToken
                )

                await logTradeAction(
                    trade: trade,
                    intent: "update",
                    outcome: "open",
                    notes: note ?? "Broker price manually updated."
                )

            case .stopLoss(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid stop loss.") }

                _ = try await APIService.shared.updateTrade(
                    tradeId: trade.id,
                    stopLoss: value,
                    notes: note ?? "Stop loss set to \(value).",
                    accessToken: accessToken
                )

                await logTradeAction(
                    trade: trade,
                    intent: "update",
                    outcome: "open",
                    notes: note ?? "Stop loss set."
                )

            case .clearStopLoss(let trade):
                _ = try await APIService.shared.updateTrade(
                    tradeId: trade.id,
                    clearStopLoss: true,
                    notes: note ?? "Stop loss removed.",
                    accessToken: accessToken
                )

                await logTradeAction(
                    trade: trade,
                    intent: "update",
                    outcome: "open",
                    notes: note ?? "Stop loss removed."
                )

            case .takeProfit(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid take profit.") }

                _ = try await APIService.shared.updateTrade(
                    tradeId: trade.id,
                    takeProfit: value,
                    notes: note ?? "Take profit set to \(value).",
                    accessToken: accessToken
                )

                await logTradeAction(
                    trade: trade,
                    intent: "update",
                    outcome: "open",
                    notes: note ?? "Take profit set."
                )

            case .clearTakeProfit(let trade):
                _ = try await APIService.shared.updateTrade(
                    tradeId: trade.id,
                    clearTakeProfit: true,
                    notes: note ?? "Take profit removed.",
                    accessToken: accessToken
                )

                await logTradeAction(
                    trade: trade,
                    intent: "update",
                    outcome: "open",
                    notes: note ?? "Take profit removed."
                )

            case .quantity(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid quantity.") }

                _ = try await APIService.shared.updateTrade(
                    tradeId: trade.id,
                    quantity: value,
                    notes: note ?? "Quantity updated to \(value).",
                    accessToken: accessToken
                )

                await logTradeAction(
                    trade: trade,
                    intent: "update",
                    outcome: "open",
                    notes: note ?? "Quantity updated."
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

                await logTradeAction(
                    trade: trade,
                    intent: "scale_out",
                    outcome: "open",
                    notes: note ?? "Position reduced."
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

                await logTradeAction(
                    trade: trade,
                    intent: "add",
                    outcome: "open",
                    notes: note ?? "Added to position."
                )

            case .close(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid exit price.") }

                _ = try await APIService.shared.closeTrade(
                    tradeId: trade.id,
                    exitPrice: exitPriceConfirmed ? value : nil,
                    closeReason: "manual_close",
                    notes: note ?? (exitPriceConfirmed ? "Trade manually closed at \(value)." : "Trade marked closed, exit price unconfirmed."),
                    exitPriceConfirmed: exitPriceConfirmed,
                    closeSource: "user",
                    closeConfidence: exitPriceConfirmed ? "confirmed" : "unconfirmed",
                    accessToken: accessToken
                )

                await logTradeAction(
                    trade: trade,
                    intent: "exit",
                    outcome: "closed",
                    exitPrice: exitPriceConfirmed ? value : nil,
                    notes: note ?? "Trade manually closed."
                )

            case .stopLossHit(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid stop fill price.") }

                _ = try await APIService.shared.closeTrade(
                    tradeId: trade.id,
                    exitPrice: exitPriceConfirmed ? value : nil,
                    closeReason: "stop_loss_hit",
                    notes: note ?? (exitPriceConfirmed ? "Stop loss hit at \(value)." : "Stop loss marked hit, exit price unconfirmed."),
                    exitPriceConfirmed: exitPriceConfirmed,
                    closeSource: "user",
                    closeConfidence: exitPriceConfirmed ? "confirmed" : "unconfirmed",
                    accessToken: accessToken
                )

                await logTradeAction(
                    trade: trade,
                    intent: "exit",
                    outcome: "loss",
                    exitPrice: exitPriceConfirmed ? value : nil,
                    notes: note ?? "Stop loss hit."
                )

            case .takeProfitHit(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid target fill price.") }

                _ = try await APIService.shared.closeTrade(
                    tradeId: trade.id,
                    exitPrice: exitPriceConfirmed ? value : nil,
                    closeReason: "take_profit_hit",
                    notes: note ?? (exitPriceConfirmed ? "Take profit hit at \(value)." : "Take profit marked hit, exit price unconfirmed."),
                    exitPriceConfirmed: exitPriceConfirmed,
                    closeSource: "user",
                    closeConfidence: exitPriceConfirmed ? "confirmed" : "unconfirmed",
                    accessToken: accessToken
                )

                await logTradeAction(
                    trade: trade,
                    intent: "exit",
                    outcome: "win",
                    exitPrice: exitPriceConfirmed ? value : nil,
                    notes: note ?? "Take profit hit."
                )
            }

            await onComplete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func logTradeAction(
        trade: LoggedTradeResponse,
        intent: String,
        outcome: String,
        exitPrice: Double? = nil,
        notes: String? = nil
    ) async {
        let payload = TradeLogCreateRequest(
            symbol: trade.symbol,
            broker: trade.platform,
            accountType: inferAccountType(from: trade.platform),
            accountSize: trade.accountSize,
            direction: trade.direction.lowercased() == "long" ? "buy" : "sell",
            intent: intent,
            entryPrice: trade.entryPrice,
            exitPrice: exitPrice,
            stopLoss: trade.stopLoss,
            takeProfit: trade.takeProfit,
            positionSize: trade.quantity,
            riskAmount: nil,
            setupType: nil,
            marketPhase: nil,
            timeframe: nil,
            reasons: [],
            warnings: [],
            emotions: [],
            mistakes: [],
            confidence: nil,
            outcome: outcome,
            notes: notes,
            instructionsCompleted: true,
            bypassInstructions: true,
            allowInstructionReplay: false,
            userConfirmedUnderstanding: true
        )

        _ = try? await APIService.shared.createTradeLog(
            payload,
            accessToken: accessToken
        )
    }

    private func inferAccountType(from platform: String?) -> String? {
        guard let platform else { return nil }

        let normalized = platform.lowercased()

        if normalized.contains("aqua")
            || normalized.contains("topstep")
            || normalized.contains("trade_the_pool")
            || normalized.contains("trade the pool") {
            return "prop_firm"
        }

        if normalized.contains("paper") {
            return "paper"
        }

        return "cash"
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
