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
    @State private var protection: ProfitProtectionRecommendationResponse?
    @State private var isLoadingProtection = false
    @State private var protectionSettings: ProfitProtectionSettings?
    @State private var isSavingProtectionSettings = false
    
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

                    if prompt.trade.isOpen {
                        profitProtectionSection
                    }

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

    private var profitProtectionSection: some View {
        Section {
            if let protection {
                let guidance = protection.recommendation
                LabeledContent("Current Profit", value: protectionMoney(guidance.currentProfit))
                LabeledContent("Best Profit Reached", value: protectionMoney(guidance.bestProfitReached))
                LabeledContent("Profit Given Back", value: "\(protectionMoney(guidance.profitGivenBack)) / \(Int(guidance.profitGivenBackPercent))%")
                LabeledContent("Suggested Stop", value: format(guidance.recommendedProtection))
                LabeledContent("Protection Mode", value: (guidance.protectionMode ?? "manual").replacingOccurrences(of: "_", with: " ").capitalized)
                LabeledContent("Break-Even Earned", value: guidance.breakEvenEarned == true ? "Yes" : "Not yet")
                LabeledContent("Profit Protected If Hit", value: guidance.profitLockedIfHit.map { "approximately \(protectionMoney($0))" } ?? "Unavailable")
                LabeledContent("Urgency", value: guidance.protectionUrgency.capitalized)
                LabeledContent("Confidence", value: "\(Int(guidance.confidence * 100))%")
                ForEach(guidance.why, id: \.self) { Text("• \($0)").font(.caption).foregroundStyle(AppTheme.secondaryText) }
                Text("Historical Experience: \(protection.shadowIntelligence.historicalExperience.capitalized) — \(protection.shadowIntelligence.sampleSize) comparable evaluated situations")
                    .font(.caption.bold()).foregroundStyle(AppTheme.softGold)
                Text(protection.disclaimer).font(.caption2).foregroundStyle(AppTheme.secondaryText)
                if case .stopLoss = prompt {
                    Button(guidance.actionable == true ? "Use Suggested Stop" : "Suggested Stop Not Yet Safe") {
                        valueText = String(guidance.recommendedProtection)
                        Task { try? await APIService.shared.recordProfitProtectionResponse(eventId: protection.eventId, response: "accepted", accessToken: accessToken) }
                    }
                    .disabled(guidance.actionable != true)
                }
                if let settings = Binding($protectionSettings) {
                    DisclosureGroup("Protection Preferences") {
                        Picker("Aggressiveness", selection: settings.aggressiveness) {
                            Text("Conservative").tag("conservative")
                            Text("Balanced").tag("balanced")
                            Text("Aggressive").tag("aggressive")
                        }
                        LabeledContent("Give-Back Warning", value: "\(Int(settings.wrappedValue.givebackWarningPercent))%")
                        Slider(value: settings.givebackWarningPercent, in: 5...90, step: 5)
                        LabeledContent("Preferred Profit Lock", value: "\(Int(settings.wrappedValue.preferredProfitLockPercent))%")
                        Slider(value: settings.preferredProfitLockPercent, in: 0...95, step: 5)
                        Toggle("Auto-Raise Protection", isOn: settings.autoRaiseEnabled)
                        Picker("Protection Mode", selection: settings.protectionMode) {
                            Text("Off").tag(Optional("off"))
                            Text("Manual").tag(Optional("manual"))
                            Text("Break-Even Protection").tag(Optional("break_even"))
                            Text("Profit Protection").tag(Optional("profit_protection"))
                        }
                        Text("Auto-raise remains recommendation-only. ChaseINGreen will never silently modify a broker stop.")
                            .font(.caption2).foregroundStyle(AppTheme.secondaryText)
                        Button(isSavingProtectionSettings ? "Saving…" : "Save Preferences") {
                            Task { await saveProtectionSettings() }
                        }.disabled(isSavingProtectionSettings)
                    }
                }
            } else {
                Button {
                    Task { await loadProfitProtection() }
                } label: {
                    Label(isLoadingProtection ? "Analyzing…" : "Analyze Profit Protection", systemImage: "shield.lefthalf.filled")
                }
                .disabled(isLoadingProtection)
            }
        } header: {
            sectionHeader("Protect Profit")
        }
        .listRowBackground(AppTheme.cardBlack)
    }

    private func protectionMoney(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").sign(strategy: .always()))
    }

    @MainActor private func loadProfitProtection() async {
        isLoadingProtection = true
        defer { isLoadingProtection = false }
        do {
            async let recommendationRequest = APIService.shared.fetchProfitProtectionRecommendation(
                trade: prompt.trade, accessToken: accessToken
            )
            async let settingsRequest = APIService.shared.fetchProfitProtectionSettings(accessToken: accessToken)
            protection = try await recommendationRequest
            protectionSettings = try await settingsRequest
            if let eventId = protection?.eventId {
                try? await APIService.shared.recordProfitProtectionResponse(
                    eventId: eventId, response: "displayed", accessToken: accessToken
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor private func saveProtectionSettings() async {
        guard let protectionSettings else { return }
        isSavingProtectionSettings = true
        defer { isSavingProtectionSettings = false }
        do {
            self.protectionSettings = try await APIService.shared.saveProfitProtectionSettings(
                protectionSettings, accessToken: accessToken
            )
            protection = nil
            await loadProfitProtection()
        } catch {
            errorMessage = error.localizedDescription
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
            .appTextField()
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

                if isLiveAquaTrade(trade) {
                    guard let accountID = cleanOrNil(
                        trade.brokerAccountId ?? trade.accountGroupKey ?? ""
                    ), let positionID = cleanOrNil(trade.externalPositionId ?? "") else {
                        throw TradeActionError.invalidValue(
                            "This Aqua position is missing its broker account or position identifier."
                        )
                    }

                    let brokerResponse = try await APIService.shared.manageMatchTraderPosition(
                        MatchTraderPositionManagementRequest(
                            broker: "Aqua Funding",
                            accountId: accountID,
                            positionId: positionID,
                            action: "modify_sl_tp",
                            stopLoss: value,
                            takeProfit: trade.takeProfit,
                            trailingDistance: nil,
                            volume: nil,
                            closePercent: nil,
                            userConfirmed: true,
                            protectionEventId: protection?.eventId.uuidString
                        ),
                        accessToken: accessToken
                    )
                    guard brokerResponse.success == true else {
                        throw TradeActionError.invalidValue(
                            brokerResponse.message
                                ?? brokerResponse.warnings
                                ?? "Aqua did not confirm the stop-loss change."
                        )
                    }
                }

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

    private func isLiveAquaTrade(_ trade: LoggedTradeResponse) -> Bool {
        let platform = (trade.platform ?? "").lowercased()
        return trade.externalPositionId != nil
            && (platform.contains("aqua") || platform.contains("match"))
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
