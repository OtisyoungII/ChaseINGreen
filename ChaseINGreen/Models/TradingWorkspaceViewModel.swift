//
//  TradingWorkspaceViewModel.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import Foundation
import SwiftUI

@MainActor
final class TradingWorkspaceViewModel: ObservableObject {

    // MARK: - Published Workspace State

    @Published var workspace: TradingWorkspaceResponse?
    @Published var traderOS: TraderOSResponse?
    @Published var positionSize: PositionSizeResponse?
    @Published var calendar: TradingCalendarResponse?
    @Published var openTrades: [LoggedTradeResponse] = []
    @Published var brokerAccounts: [BrokerAccountResponse] = []
    @Published var tradeStats: TradeStatsSummaryResponse?
    @Published var mlInsights: MLInsightsResponse?

    // MARK: - UI State

    @Published var selectedCard: TradingWorkspaceCard = .traderOS
    @Published var zoomedCard: TradingWorkspaceCard?
    @Published var selectedTrade: LoggedTradeResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Context

    var isZoomed: Bool {
        zoomedCard != nil
    }

    var selectedSymbol: String? {
        traderOS?.symbol?.uppercased()
    }

    // MARK: - Load

    func load(
        symbol: String,
        direction: String? = nil,
        broker: String? = nil,
        accountKey: String? = nil,
        currentBrokerPrice: Double? = nil,
        useIBKRQuote: Bool = false,
        useMatchTraderQuote: Bool = false,
        ibkrBaseURL: String? = nil,
        matchTraderBaseURL: String? = nil,
        matchTraderToken: String? = nil,
        startingBalance: Double? = nil,
        currentBalance: Double? = nil,
        targetBalance: Double? = nil,
        averageDailyProfit: Double? = nil,
        accessToken: String,
        force: Bool = false
    ) async {
        let brokerProfile = BrokerWorkspaceProfile(
            broker: broker,
            accountKey: accountKey,
            startingBalance: startingBalance,
            currentBalance: currentBalance
        )

        let workspaceKey = APIRefreshKey(
            "trading_workspace",
            symbol: symbol,
            broker: broker,
            accountKey: accountKey,
            speed: .medium
        )

        guard APIRefreshGate.shared.shouldRefresh(workspaceKey, force: force) else {
            return
        }

        APIRefreshGate.shared.begin(workspaceKey)

        isLoading = true
        errorMessage = nil
        positionSize = nil

        do {
            let response = try await APIService.shared.fetchTradingWorkspace(
                symbol: symbol,
                direction: direction,
                broker: broker,
                accountKey: accountKey,
                currentBrokerPrice: currentBrokerPrice,
                useIBKRQuote: useIBKRQuote || brokerProfile.isIBKR,
                useMatchTraderQuote: useMatchTraderQuote || brokerProfile.isMatchTrader,
                ibkrBaseURL: ibkrBaseURL,
                matchTraderBaseURL: matchTraderBaseURL,
                includeMatchTraderTimeframes: brokerProfile.isMatchTrader,
                matchTraderToken: matchTraderToken,
                startingBalance: startingBalance,
                currentBalance: currentBalance,
                targetBalance: targetBalance,
                averageDailyProfit: averageDailyProfit,
                accessToken: accessToken
            )

            apply(response)

            await loadPositionSize(
                symbol: symbol,
                brokerProfile: brokerProfile,
                accessToken: accessToken
            )

            APIRefreshGate.shared.finish(workspaceKey)

            await loadSlowData(
                symbol: symbol,
                broker: broker,
                accountKey: accountKey,
                accessToken: accessToken,
                force: force
            )
        } catch {
            errorMessage = error.localizedDescription
            APIRefreshGate.shared.reset(workspaceKey)
        }

        isLoading = false
    }

    // MARK: - Position Size

    private func loadPositionSize(
        symbol: String,
        brokerProfile: BrokerWorkspaceProfile,
        accessToken: String
    ) async {
        let selectedAccount = brokerAccounts.first { account in
            let brokerMatches =
                brokerProfile.broker == nil ||
                account.broker.lowercased().contains(brokerProfile.broker?.lowercased() ?? "") ||
                account.platform.lowercased().contains(brokerProfile.broker?.lowercased() ?? "")

            let accountMatches =
                brokerProfile.accountKey == nil ||
                account.accountId.lowercased() == brokerProfile.accountKey?.lowercased() ||
                account.accountName?.lowercased() == brokerProfile.accountKey?.lowercased()

            return brokerMatches && accountMatches
        } ?? brokerAccounts.first

        positionSize = try? await APIService.shared.fetchPositionSize(
            symbol: symbol,
            broker: brokerProfile.broker ?? selectedAccount?.platform ?? selectedAccount?.broker,
            accountKey: brokerProfile.accountKey ?? selectedAccount?.accountId,
            accountBalance: selectedAccount?.balance ?? selectedAccount?.startingBalance ?? brokerProfile.accountBalance,
            accountEquity: selectedAccount?.equity ?? selectedAccount?.balance ?? brokerProfile.accountEquity,
            buyingPower: selectedAccount?.buyingPower ?? brokerProfile.buyingPower,
            bestProbability: traderOS?.probability?.bestProbability,
            riskScore: traderOS?.ai?.riskScore ?? traderOS?.executionPlan?.riskScore,
            sizeProfile: traderOS?.executionPlan?.sizeProfile ?? traderOS?.probability?.tradeSizeSuggestion,
            pdtSensitive: brokerProfile.isIBKR || selectedAccount?.platform.lowercased().contains("ibkr") == true,
            propFirm: brokerProfile.isPropFirm
                || selectedAccount?.platform.lowercased().contains("aqua") == true
                || selectedAccount?.platform.lowercased().contains("trade the pool") == true,
            accessToken: accessToken
        )
    }

    // MARK: - Manual Refresh

    func manualRefresh(
        symbol: String,
        direction: String? = nil,
        broker: String? = nil,
        accountKey: String? = nil,
        accessToken: String
    ) async {
        await load(
            symbol: symbol,
            direction: direction,
            broker: broker,
            accountKey: accountKey,
            accessToken: accessToken,
            force: true
        )
    }

    // MARK: - Slow Data

    private func loadSlowData(
        symbol: String,
        broker: String?,
        accountKey: String?,
        accessToken: String,
        force: Bool
    ) async {
        let mlKey = APIRefreshKey(
            "ml_insights",
            symbol: symbol,
            broker: broker,
            accountKey: accountKey,
            speed: .slow
        )

        guard APIRefreshGate.shared.shouldRefresh(mlKey, force: force) else {
            return
        }

        APIRefreshGate.shared.begin(mlKey)

        do {
            mlInsights = try await APIService.shared.fetchMLInsights(accessToken: accessToken)
            APIRefreshGate.shared.finish(mlKey)
        } catch {
            APIRefreshGate.shared.reset(mlKey)
        }
    }

    // MARK: - Apply Response

    private func apply(_ response: TradingWorkspaceResponse) {
        workspace = response
        traderOS = response.traderOS
        calendar = response.calendar
        openTrades = response.openTrades ?? []
        brokerAccounts = response.brokerAccounts ?? []
        tradeStats = response.tradeStats
    }

    // MARK: - Card Selection

    func select(_ card: TradingWorkspaceCard) {
        selectedCard = card
    }

    func zoom(_ card: TradingWorkspaceCard) {
        selectedCard = card
        zoomedCard = card
    }

    func closeZoom() {
        zoomedCard = nil
    }

    // MARK: - Trade Selection

    func selectTrade(_ trade: LoggedTradeResponse) {
        selectedTrade = trade
    }

    func clearSelectedTrade() {
        selectedTrade = nil
    }

    // MARK: - Reset

    func reset() {
        workspace = nil
        traderOS = nil
        positionSize = nil
        calendar = nil
        openTrades = []
        brokerAccounts = []
        tradeStats = nil
        mlInsights = nil
        selectedCard = .traderOS
        zoomedCard = nil
        selectedTrade = nil
        errorMessage = nil
        isLoading = false
    }
}

// MARK: - Broker Workspace Profile

private struct BrokerWorkspaceProfile {
    let broker: String?
    let accountKey: String?
    let accountBalance: Double?
    let accountEquity: Double?
    let buyingPower: Double?

    init(
        broker: String?,
        accountKey: String?,
        startingBalance: Double?,
        currentBalance: Double?
    ) {
        self.broker = broker
        self.accountKey = accountKey
        self.accountBalance = startingBalance
        self.accountEquity = currentBalance ?? startingBalance
        self.buyingPower = nil
    }

    private var normalizedBroker: String {
        (broker ?? "")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }

    var isIBKR: Bool {
        normalizedBroker.contains("ibkr")
        || normalizedBroker.contains("interactive brokers")
        || normalizedBroker.contains("interactive broker")
    }

    var isMatchTrader: Bool {
        normalizedBroker.contains("match trader")
        || normalizedBroker.contains("matchtrader")
        || normalizedBroker.contains("aqua")
        || normalizedBroker.contains("trade the pool")
        || normalizedBroker == "ttp"
    }

    var isPropFirm: Bool {
        normalizedBroker.contains("aqua")
        || normalizedBroker.contains("trade the pool")
        || normalizedBroker == "ttp"
        || normalizedBroker.contains("topstep")
        || normalizedBroker.contains("prop")
        || normalizedBroker.contains("funded")
    }
}
