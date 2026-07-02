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

        do {
            let response = try await APIService.shared.fetchTradingWorkspace(
                symbol: symbol,
                direction: direction,
                broker: broker,
                accountKey: accountKey,
                currentBrokerPrice: currentBrokerPrice,
                useIBKRQuote: useIBKRQuote,
                useMatchTraderQuote: useMatchTraderQuote,
                ibkrBaseURL: ibkrBaseURL,
                matchTraderBaseURL: matchTraderBaseURL,
                matchTraderToken: matchTraderToken,
                startingBalance: startingBalance,
                currentBalance: currentBalance,
                targetBalance: targetBalance,
                averageDailyProfit: averageDailyProfit,
                accessToken: accessToken
            )

            apply(response)
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
            mlInsights = try await APIService.shared.fetchMLInsights(
                accessToken: accessToken
            )

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
