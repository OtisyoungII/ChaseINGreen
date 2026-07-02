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
    @Published var workspace: TradingWorkspaceResponse?
    @Published var traderOS: TraderOSResponse?
    @Published var calendar: TradingCalendarResponse?
    @Published var openTrades: [LoggedTradeResponse] = []
    @Published var brokerAccounts: [BrokerAccountResponse] = []
    @Published var tradeStats: TradeStatsSummaryResponse?
    @Published var mlInsights: MLInsightsResponse?

    @Published var selectedCard: TradingWorkspaceCard = .traderOS
    @Published var zoomedCard: TradingWorkspaceCard?
    @Published var isLoading = false
    @Published var errorMessage: String?

    var isZoomed: Bool {
        zoomedCard != nil
    }

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
        accessToken: String
    ) async {
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

            workspace = response
            traderOS = response.traderOS
            calendar = response.calendar
            openTrades = response.openTrades ?? []
            brokerAccounts = response.brokerAccounts ?? []
            tradeStats = response.tradeStats
            mlInsights = try? await APIService.shared.fetchMLInsights(accessToken: accessToken)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

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
        errorMessage = nil
        isLoading = false
    }
}
