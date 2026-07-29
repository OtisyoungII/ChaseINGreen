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
    @State private var isSecretOrAdmin = false
    @State private var aquaAccount: MatchTraderPositionAccount?
    @State private var aquaInstrument: MatchTraderInstrument?
    @State private var aquaQuote: MatchTraderLiveQuoteResponse?
    @State private var aquaPositionSize: PositionSizeBlock?
    @State private var aquaContext: PreTradeContextResponse?
    @State private var isPreparingAqua = false
    @State private var isSubmittingAqua = false
    @State private var showingAquaConfirmation = false
    @State private var aquaErrorMessage: String?

    private let quickSizes: [Double] = [0.01, 0.02, 0.05, 0.10, 1, 5, 10, 25, 50, 100]

    private var activeBrokerAccounts: [BrokerAccountResponse] {
        brokerAccounts.filter { account in
            let status = (account.accountStatus ?? "")
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return account.isActive
                && ![
                    "closed",
                    "failed",
                    "breached",
                    "disabled",
                    "inactive",
                    "terminated",
                    "passed"
                ].contains(status)
        }
    }

    private var selectedBrokerAccount: BrokerAccountResponse? {
        guard let selectedBrokerAccountId else {
            return nil
        }

        return activeBrokerAccounts.first {
            $0.id == selectedBrokerAccountId
        }
    }

    private var isSelectedAquaAccount: Bool {
        guard let account = selectedBrokerAccount else {
            return false
        }

        let context = [
            account.broker,
            account.platform,
            account.propFirmName
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()

        return context.contains("aqua")
            || context.contains("match trader")
            || context.contains("match-trader")
    }

    private var canPlaceAquaOrder: Bool {
        isSecretOrAdmin
            && isSelectedAquaAccount
            && aquaAccount?.available != false
            && aquaAccount?.systemActive != false
            && aquaInstrument?.tradable != false
            && accessToken != nil
    }

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

    private var isPropFirmTrade: Bool {
        draft.selectedBroker.isPropFirm
    }

    private var accountHelpText: String {
        switch draft.selectedBroker.accountClass {
        case .propFirm:
            return "Prop trades use drawdown, payout, and account-rule tracking."
        case .brokerage:
            return "Brokerage trades use cash/margin account grouping. Prop drawdown fields stay off."
        case .crypto:
            return "Crypto exchange trades use exchange account grouping. These are not prop-firm trades."
        }
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headerCard
                        tradeSection
                        if isSelectedAquaAccount {
                            aquaLiveContextSection
                        }
                        riskSizeSection
                        brokerSection

                        if isPropFirmTrade {
                            propRulesSection
                        }

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
            .onChange(of: draft.selectedBroker) { _, newValue in
                applyManualBrokerDefaults(newValue)
            }
            .onChange(of: draft.direction) {
                if let aquaContext {
                    applyAquaProtection(aquaContext)
                }

                let executablePrice = (
                    draft.direction == .long
                        ? aquaQuote?.ask
                        : aquaQuote?.bid
                ) ?? aquaQuote?.price

                if let executablePrice {
                    let formatted = formatMarketPrice(
                        executablePrice
                    )
                    draft.entryPriceText = formatted
                    draft.currentPriceText = formatted
                }
            }
            .task {
                selectPreferredAccountIfNeeded()
                await prepareAquaQuickTrade()
            }
            .confirmationDialog(
                "Submit immediate Aqua market order?",
                isPresented: $showingAquaConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    "Submit \(draft.direction == .long ? "BUY" : "SELL") \(draft.quantityText) \(draft.symbol)",
                    role: draft.direction == .short ? .destructive : nil
                ) {
                    Task {
                        await submitAquaOrder()
                    }
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text(aquaConfirmationMessage)
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

            Text("Pick a saved account when possible so Trader OS knows if this is prop, brokerage, or crypto.")
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

            ScrollViewReader { reader in
                HStack(spacing: 8) {
                    quickSizeStepButton(
                        systemImage: "chevron.left",
                        offset: -1,
                        reader: reader
                    )

                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(spacing: 10) {
                            ForEach(quickSizes, id: \.self) { size in
                                Button {
                                    selectQuickSize(size)
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
                                .id(size)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    quickSizeStepButton(
                        systemImage: "chevron.right",
                        offset: 1,
                        reader: reader
                    )
                }
            }

            appTextField(isPropFirmTrade ? "Account Size / Prop Balance" : "Account Size / Buying Base", text: $draft.accountSizeText)
        }
    }

    private var aquaLiveContextSection: some View {
        sectionCard(
            "Aqua Live Context",
            systemImage: "bolt.horizontal.circle.fill"
        ) {
            if isPreparingAqua {
                ProgressView("Using the saved Aqua session...")
                    .tint(AppTheme.gold)
            } else if !isSecretOrAdmin {
                Text(
                    "This remains a manual trade log. Live Aqua order preparation is available in the internal Secret workspace."
                )
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.secondaryText)
            } else if let aquaQuote {
                HStack(spacing: 10) {
                    liveQuoteMetric(
                        "Bid",
                        aquaQuote.bid
                    )
                    liveQuoteMetric(
                        "Ask",
                        aquaQuote.ask
                    )
                    liveQuoteMetric(
                        "Mid / Last",
                        aquaQuote.price
                    )
                }

                Text(
                    "Quote source: \(aquaQuote.provider ?? "Match-Trader") • \(aquaQuote.freshness ?? "broker live")"
                )
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.secondaryText)

                if let size = aquaPositionSize {
                    HStack(spacing: 10) {
                        liveValueMetric(
                            "Current size",
                            size.currentPositionSize
                        )
                        liveValueMetric(
                            "Next size",
                            size.recommendedSize
                        )
                        liveValueMetric(
                            "Max",
                            size.maxSize
                        )
                    }

                    if let exposure = size.exposureSummary
                        ?? size.summary {
                        Text(exposure)
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }

                if let context = aquaContext {
                    Text(
                        "\(context.directionSignal.uppercased()) • \(context.setupQuality) • grade \(context.entryGrade)"
                    )
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(
                        context.canEnter
                            ? AppTheme.success
                            : AppTheme.softGold
                    )

                    Text(context.plainEnglishRead)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            } else {
                Text(
                    aquaErrorMessage
                        ?? "Select an active Aqua account to prepare its broker quote, current exposure, recommended next size, and protection."
                )
                .font(AppTheme.captionFont)
                .foregroundStyle(
                    aquaErrorMessage == nil
                        ? AppTheme.secondaryText
                        : AppTheme.danger
                )
            }

            if let aquaErrorMessage,
               aquaQuote != nil {
                Label(
                    aquaErrorMessage,
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.danger)
            }
        }
    }

    private var brokerSection: some View {
        sectionCard("Broker / Account", systemImage: "building.columns.fill") {
            if !activeBrokerAccounts.isEmpty {
                Picker("Saved Account", selection: $selectedBrokerAccountId) {
                    Text("No saved account").tag(UUID?.none)

                    ForEach(activeBrokerAccounts, id: \.id) { account in
                        Text(accountPickerTitle(account))
                            .tag(UUID?.some(account.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.gold)
                .onChange(of: selectedBrokerAccountId) { _, newValue in
                    applySelectedBrokerAccount(newValue)
                    Task {
                        await prepareAquaQuickTrade()
                    }
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

            Text(accountHelpText)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.secondaryText)

            appTextField("Account Name", text: $draft.brokerAccountNameText)
            appTextField("Account Last 4 optional", text: $draft.brokerAccountLast4Text)
            appTextField("Group Key", text: $draft.accountGroupKeyText)

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
                .appTextField()
        }
    }

    private var saveButton: some View {
        Button {
            if canPlaceAquaOrder {
                reviewAquaOrder()
            } else {
                saveTrade()
            }
        } label: {
            HStack {
                if isSubmittingAqua {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(
                        systemName: canPlaceAquaOrder
                            ? "bolt.fill"
                            : "checkmark.circle.fill"
                    )
                }
                Text(
                    canPlaceAquaOrder
                        ? "Review Aqua Order"
                        : "Save Trade"
                )
                    .font(.system(size: 19, weight: .black))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(canSave ? .black : AppTheme.mutedText)
            .background(canSave ? AppTheme.gold : .white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(!canSave || isSubmittingAqua)
    }

    private func applySelectedBrokerAccount(_ id: UUID?) {
        guard let id,
              let account = activeBrokerAccounts.first(where: { $0.id == id }) else {
            return
        }

        let preset = brokerPreset(for: account.broker)

        draft.selectedBroker = preset
        draft.brokerAccountNameText = account.accountName ?? account.accountId
        draft.brokerAccountLast4Text = account.accountNumber ?? ""
        draft.accountGroupKeyText = account.accountId

        if let startingBalance = account.startingBalance ?? account.balance ?? account.equity {
            draft.accountSizeText = formatAccountNumber(startingBalance)
        }

        if preset.isPropFirm {
            draft.maxDailyLossText = formatAccountNumber(account.dailyDrawdownLimit)
            draft.maxTotalLossText = formatAccountNumber(account.maxDrawdownLimit)
            draft.payoutTargetText = formatAccountNumber(account.payoutTarget ?? account.profitTarget)
        } else {
            draft.maxDailyLossText = ""
            draft.maxTotalLossText = ""
            draft.payoutTargetText = ""
        }
    }

    private func applyManualBrokerDefaults(_ broker: BrokerPreset) {
        guard selectedBrokerAccountId == nil else { return }

        if !broker.isPropFirm {
            draft.maxDailyLossText = ""
            draft.maxTotalLossText = ""
            draft.payoutTargetText = ""
        }

        if draft.brokerAccountNameText.isEmpty {
            draft.brokerAccountNameText = defaultAccountName(for: broker)
        }

        if draft.accountGroupKeyText.isEmpty {
            draft.accountGroupKeyText = fallbackAccountGroupKey()
        }
    }

    private func accountPickerTitle(_ account: BrokerAccountResponse) -> String {
        let name = account.accountName ?? account.accountId
        let broker = brokerPreset(for: account.broker)
        let size = account.startingBalance ?? account.balance ?? account.equity

        let typeLabel: String = {
            if broker.isPropFirm {
                return "Prop"
            }

            if broker.isCryptoExchange {
                return "Crypto"
            }

            return account.accountType ?? "Brokerage"
        }()

        if let size {
            return "\(broker.displayName) • \(typeLabel) • \(name) • \(formatPlainMoney(size))"
        }

        return "\(broker.displayName) • \(typeLabel) • \(name)"
    }

    private func brokerPreset(for raw: String) -> BrokerPreset {
        BrokerPreset.from(raw) ?? .aquaFunding
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
            .textFieldStyle(.plain)
            .padding(12)
            .background(.white.opacity(0.10))
            .foregroundStyle(.white)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func liveQuoteMetric(
        _ title: String,
        _ value: Double?
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.secondaryText)
            Text(formatMarketPrice(value))
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func liveValueMetric(
        _ title: String,
        _ value: Double?
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.secondaryText)
            Text(value.map(formatQuickSize) ?? "—")
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func selectPreferredAccountIfNeeded() {
        guard selectedBrokerAccountId == nil else {
            return
        }

        let preferred = activeBrokerAccounts.first(where: { account in
            let context = [
                account.broker,
                account.platform,
                account.propFirmName
            ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

            return context.contains("aqua")
                || context.contains("match trader")
                || context.contains("match-trader")
        }) ?? activeBrokerAccounts.first

        guard let preferred else {
            return
        }

        selectedBrokerAccountId = preferred.id
        applySelectedBrokerAccount(preferred.id)
    }

    @MainActor
    private func prepareAquaQuickTrade() async {
        aquaErrorMessage = nil

        guard isSelectedAquaAccount,
              let account = selectedBrokerAccount,
              let accessToken else {
            aquaAccount = nil
            aquaInstrument = nil
            aquaQuote = nil
            aquaPositionSize = nil
            aquaContext = nil
            return
        }

        isPreparingAqua = true
        defer { isPreparingAqua = false }

        do {
            let user = try await APIService.shared
                .fetchCurrentUser(
                    accessToken: accessToken
                )
            let plan = (user.plan ?? "")
                .lowercased()
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            isSecretOrAdmin = user.isAdmin
                || plan == "secret"

            guard isSecretOrAdmin else {
                return
            }

            let positionsResponse = try await APIService.shared
                .fetchMatchTraderPositions(
                    MatchTraderSyncRequest(
                        broker: "Aqua Funding",
                        accountId: account.accountId,
                        symbols: [draft.symbol],
                        includeEmptyAccounts: true
                    ),
                    accessToken: accessToken
                )

            guard let resolvedAccount =
                    positionsResponse.accounts?.first(where: {
                        aquaAccountMatches(
                            $0,
                            accountId: account.accountId
                        )
                    })
                    ?? positionsResponse.accounts?.first else {
                throw QuickTradeAquaError(
                    "Aqua did not return this active account."
                )
            }

            aquaAccount = resolvedAccount

            let instrumentsResponse = try await APIService.shared
                .fetchMatchTraderInstruments(
                    accountId: account.accountId,
                    accessToken: accessToken
                )
            let requestedSymbol = draft.symbol.uppercased()

            guard let instrument = instrumentsResponse
                .instruments?
                .first(where: {
                    $0.symbol.caseInsensitiveCompare(
                        requestedSymbol
                    ) == .orderedSame
                }),
                instrument.tradable != false else {
                throw QuickTradeAquaError(
                    "\(requestedSymbol) is not tradable in the selected Aqua account."
                )
            }

            aquaInstrument = instrument

            let quote = try await APIService.shared
                .fetchMatchTraderQuote(
                    accountId: account.accountId,
                    symbol: requestedSymbol,
                    accessToken: accessToken
                )
            aquaQuote = quote

            if let price = quote.price {
                let formatted = formatMarketPrice(price)
                draft.entryPriceText = formatted
                draft.currentPriceText = formatted
            }

            let context = try? await APIService.shared
                .fetchPreTradeContext(
                    PreTradeContextRequest(
                        symbol: requestedSymbol,
                        direction: draft.direction.rawValue,
                        broker: "Aqua Funding",
                        accountKey: account.accountId,
                        useMatchTraderQuote: true,
                        matchTraderAccountID: account.accountId,
                        includeMatchTraderTimeframes: true,
                        accountSize: resolvedAccount
                            .balanceHealth?
                            .equity
                            ?? resolvedAccount
                                .balanceHealth?
                                .balance,
                        plannedSize: nil
                    ),
                    accessToken: accessToken
                )
            aquaContext = context

            if let context {
                applyDirectionSuggestion(context)
                applyAquaProtection(context)
            }

            let livePosition = resolvedAccount
                .positions?
                .first {
                    $0.symbol.caseInsensitiveCompare(
                        requestedSymbol
                    ) == .orderedSame
                }
            let liveVolume = livePosition?
                .volume
                .map { abs($0) }
            let price = quote.price
                ?? livePosition?.currentPrice
            let positionValue: Double? = {
                guard let liveVolume, let price else {
                    return nil
                }
                return liveVolume * price
            }()

            let sizeResponse = try await APIService.shared
                .fetchPositionSize(
                    symbol: requestedSymbol,
                    broker: "Aqua Funding",
                    accountKey: account.accountId,
                    accountBalance: resolvedAccount
                        .balanceHealth?
                        .balance,
                    accountEquity: resolvedAccount
                        .balanceHealth?
                        .equity
                        ?? resolvedAccount
                            .balanceHealth?
                            .balance,
                    buyingPower: resolvedAccount
                        .balanceHealth?
                        .buyingPower,
                    propFirm: true,
                    side: draft.direction == .long
                        ? "BUY"
                        : "SELL",
                    currentPrice: price,
                    entryPrice: livePosition?.openPrice,
                    stopPrice: doubleOrNil(
                        draft.stopLossText
                    ),
                    targetPrice: doubleOrNil(
                        draft.takeProfitText
                    ),
                    existingPositionSize: liveVolume,
                    existingPositionValue: positionValue,
                    currentOpenPnl: livePosition?
                        .netProfit
                        ?? livePosition?.profit,
                    accessToken: accessToken
                )

            aquaPositionSize = sizeResponse.positionSize

            if let recommended = sizeResponse
                .positionSize?
                .recommendedSize,
               recommended > 0 {
                draft.quantityText = formatQuickSize(
                    recommended
                )
            }
        } catch {
            aquaErrorMessage = error.localizedDescription
            aquaAccount = nil
            aquaInstrument = nil
            aquaQuote = nil
            aquaPositionSize = nil
            aquaContext = nil
        }
    }

    private func aquaAccountMatches(
        _ account: MatchTraderPositionAccount,
        accountId: String
    ) -> Bool {
        [
            account.accountId,
            account.tradingAccountId,
            account.accountUUID
        ]
        .compactMap { $0 }
        .contains {
            $0.caseInsensitiveCompare(
                accountId
            ) == .orderedSame
        }
    }

    private func applyDirectionSuggestion(
        _ context: PreTradeContextResponse
    ) {
        let signal = [
            context.directionSignal,
            context.setupBias
        ]
        .joined(separator: " ")
        .lowercased()

        if signal.contains("short")
            || signal.contains("sell")
            || signal.contains("bear") {
            draft.direction = .short
        } else if signal.contains("long")
                    || signal.contains("buy")
                    || signal.contains("bull") {
            draft.direction = .long
        }
    }

    private func applyAquaProtection(
        _ context: PreTradeContextResponse
    ) {
        let stop: Double?
        let target: Double?

        if draft.direction == .short {
            stop = context.resistance1
                ?? context.resistanceLevel
                ?? context.resistance2
            target = context.support1
                ?? context.supportLevel
                ?? context.target1
        } else {
            stop = context.support1
                ?? context.supportLevel
                ?? context.support2
            target = context.resistance1
                ?? context.resistanceLevel
                ?? context.target1
        }

        if let stop {
            draft.stopLossText = formatMarketPrice(
                stop
            )
        }

        if let target {
            draft.takeProfitText = formatMarketPrice(
                target
            )
        }
    }

    private func selectQuickSize(_ size: Double) {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            pressedSize = size
            draft.quantityText = formatQuickSize(size)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            pressedSize = nil
        }
    }

    private func quickSizeStepButton(
        systemImage: String,
        offset: Int,
        reader: ScrollViewProxy
    ) -> some View {
        Button {
            let currentSize = Double(draft.quantityText)
            let currentIndex = currentSize.flatMap {
                quickSizes.firstIndex(of: $0)
            } ?? 0
            let nextIndex = min(
                max(currentIndex + offset, 0),
                quickSizes.count - 1
            )
            let next = quickSizes[nextIndex]

            selectQuickSize(next)
            withAnimation {
                reader.scrollTo(next, anchor: .center)
            }
        } label: {
            Image(systemName: systemImage)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppTheme.softGold)
        .foregroundStyle(AppTheme.deepBlack)
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
        guard Double(draft.entryPriceText) != nil else {
            return false
        }

        if canPlaceAquaOrder {
            return (Double(draft.quantityText) ?? 0) > 0
                && !isPreparingAqua
        }

        return true
    }

    private var aquaConfirmationMessage: String {
        let side = draft.direction == .long
            ? "BUY"
            : "SELL"
        let marketPrice = draft.direction == .long
            ? aquaQuote?.ask
            : aquaQuote?.bid
        let priceText = formatMarketPrice(
            marketPrice ?? aquaQuote?.price
        )

        return "Send an immediate \(side) order for \(draft.quantityText) \(draft.symbol) near \(priceText) to \(draft.brokerAccountNameText)? Aqua controls the final fill. Stop \(draft.stopLossText.isEmpty ? "none" : draft.stopLossText), target \(draft.takeProfitText.isEmpty ? "none" : draft.takeProfitText)."
    }

    @MainActor
    private func reviewAquaOrder() {
        aquaErrorMessage = nil

        guard canPlaceAquaOrder,
              let instrument = aquaInstrument else {
            aquaErrorMessage =
                "The active Aqua account and instrument must finish loading first."
            return
        }

        guard let volume = Double(draft.quantityText),
              volume > 0 else {
            aquaErrorMessage =
                "Enter a valid Aqua volume greater than zero."
            return
        }

        if let minimum = instrument.minimumVolume,
           volume < minimum {
            aquaErrorMessage =
                "Volume is below Aqua's minimum of \(formatQuickSize(minimum))."
            return
        }

        if let maximum = instrument.maximumVolume,
           volume > maximum {
            aquaErrorMessage =
                "Volume exceeds Aqua's maximum of \(formatQuickSize(maximum))."
            return
        }

        if let riskMaximum = aquaPositionSize?.maxSize,
           volume > riskMaximum {
            aquaErrorMessage =
                "Volume exceeds the account-specific maximum of \(formatQuickSize(riskMaximum))."
            return
        }

        showingAquaConfirmation = true
    }

    @MainActor
    private func submitAquaOrder() async {
        guard let accessToken,
              let account = selectedBrokerAccount,
              let volume = Double(draft.quantityText),
              volume > 0 else {
            aquaErrorMessage =
                "The Aqua order is missing its account, access, or size."
            return
        }

        isSubmittingAqua = true
        aquaErrorMessage = nil

        defer {
            isSubmittingAqua = false
        }

        do {
            let response = try await APIService.shared
                .openMatchTraderMarketPosition(
                    MatchTraderMarketEntryRequest(
                        broker: "Aqua Funding",
                        accountId: account.accountId,
                        symbol: draft.symbol.uppercased(),
                        side: draft.direction == .long
                            ? "BUY"
                            : "SELL",
                        volume: volume,
                        stopLoss: doubleOrNil(
                            draft.stopLossText
                        ),
                        takeProfit: doubleOrNil(
                            draft.takeProfitText
                        ),
                        trailingDistance: 0,
                        userConfirmed: true
                    ),
                    accessToken: accessToken
                )

            guard response.success == true else {
                throw QuickTradeAquaError(
                    response.message
                        ?? response.warnings
                        ?? "Aqua rejected the market order."
                )
            }

            dismiss()
        } catch {
            aquaErrorMessage = error.localizedDescription
        }
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
            maxDailyLossAllowed: draft.selectedBroker.isPropFirm ? doubleOrNil(draft.maxDailyLossText) : nil,
            maxTotalLossAllowed: draft.selectedBroker.isPropFirm ? doubleOrNil(draft.maxTotalLossText) : nil,
            payoutTarget: draft.selectedBroker.isPropFirm ? doubleOrNil(draft.payoutTargetText) : nil,
            notes: cleanOrNil(draft.notes)
        )

        onSave(payload)
        dismiss()
    }

    private func defaultAccountName(for broker: BrokerPreset) -> String {
        if broker.isPropFirm {
            return "\(broker.displayName) Prop Account"
        }

        if broker.isCryptoExchange {
            return "\(broker.displayName) Exchange"
        }

        return "\(broker.displayName) Cash"
    }

    private func fallbackAccountGroupKey() -> String {
        let broker = draft.selectedBroker.apiValue

        let type: String = {
            if draft.selectedBroker.isPropFirm {
                return "prop"
            }

            if draft.selectedBroker.isCryptoExchange {
                return "exchange"
            }

            return "cash"
        }()

        let size = cleanOrNil(draft.accountSizeText) ?? "main"

        return "\(broker)-\(type)-\(size)"
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: " ", with: "-")
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

    private func formatAccountNumber(_ value: Double?) -> String {
        guard let value else { return "" }

        if value == floor(value) {
            return String(format: "%.0f", value)
        }

        return String(format: "%.2f", value)
    }

    private func formatPlainMoney(_ value: Double) -> String {
        String(format: "$%.0f", value)
    }

    private func formatMarketPrice(
        _ value: Double?
    ) -> String {
        guard let value else {
            return "—"
        }

        return value.formatted(
            .number.precision(
                .fractionLength(0...6)
            )
        )
    }
}

private struct QuickTradeAquaError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
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
