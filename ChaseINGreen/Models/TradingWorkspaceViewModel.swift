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
    @Published var brokerHealth: BrokerConnectionHealthResponse?
    @Published var tradeStats: TradeStatsSummaryResponse?
    @Published var mlInsights: MLInsightsResponse?
    @Published var aquaConnection: MatchTraderConnectionFeatures?
    @Published var aquaPositions: MatchTraderPositionsResponse?
    @Published var aquaActivityError: String?
    @Published var isLoadingAquaActivity = false

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
        matchTraderConnectionID: String? = nil,
        matchTraderAccountID: String? = nil,
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
            async let workspaceRequest = APIService.shared.fetchTradingWorkspace(
                symbol: symbol,
                direction: direction,
                broker: broker,
                accountKey: accountKey,
                currentBrokerPrice: currentBrokerPrice,
                useIBKRQuote: useIBKRQuote || brokerProfile.isIBKR,
                useMatchTraderQuote: useMatchTraderQuote || brokerProfile.isMatchTrader,
                ibkrBaseURL: ibkrBaseURL,
                includeMatchTraderTimeframes: brokerProfile.isMatchTrader,
                matchTraderConnectionID: matchTraderConnectionID,
                matchTraderAccountID: matchTraderAccountID,
                startingBalance: startingBalance,
                currentBalance: currentBalance,
                targetBalance: targetBalance,
                averageDailyProfit: averageDailyProfit,
                accessToken: accessToken
            )

            async let brokerHealthRequest = APIService.shared.fetchBrokerConnectionHealth(
                accessToken: accessToken
            )

            let response = try await workspaceRequest
            brokerHealth = try? await brokerHealthRequest

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
        let selectedTrade = openTrades.first {
            $0.symbol.uppercased() == symbol.uppercased()
        }

        let tradeBroker = selectedTrade?.platform ?? brokerProfile.broker
        let tradeAccountKey = selectedTrade?.accountGroupKey
            ?? selectedTrade?.brokerAccountId
            ?? brokerProfile.accountKey

        let matchedAccount = brokerAccounts.first { account in
            account.accountId.lowercased() == (tradeAccountKey ?? "").lowercased()
            || account.accountName?.lowercased() == (selectedTrade?.brokerAccountName ?? "").lowercased()
            || account.platform?.lowercased() == (tradeBroker ?? "").lowercased()
            || account.broker.lowercased() == (tradeBroker ?? "").lowercased()
        }

        positionSize = try? await APIService.shared.fetchPositionSize(
            symbol: symbol,
            broker: tradeBroker,
            accountKey: tradeAccountKey,
            accountBalance: matchedAccount?.balance
                ?? matchedAccount?.startingBalance
                ?? selectedTrade?.accountSize
                ?? brokerProfile.accountBalance,
            accountEquity: matchedAccount?.equity
                ?? matchedAccount?.balance
                ?? selectedTrade?.accountSize
                ?? brokerProfile.accountEquity,
            buyingPower: matchedAccount?.buyingPower,
            bestProbability: traderOS?.probability?.bestProbability,
            riskScore: traderOS?.ai?.riskScore ?? traderOS?.executionPlan?.riskScore,
            sizeProfile: traderOS?.executionPlan?.sizeProfile ?? traderOS?.probability?.tradeSizeSuggestion,
            pdtSensitive: isIBKRBroker(tradeBroker),
            propFirm: isPropFirmBroker(tradeBroker),
            accessToken: accessToken
        )
    }

    private func isIBKRBroker(_ broker: String?) -> Bool {
        let clean = (broker ?? "").lowercased()
        return clean.contains("ibkr")
            || clean.contains("interactive brokers")
            || clean.contains("interactive broker")
    }

    private func isPropFirmBroker(_ broker: String?) -> Bool {
        let clean = (broker ?? "").lowercased()
        return clean.contains("aqua")
            || clean.contains("trade the pool")
            || clean.contains("ttp")
            || clean.contains("topstep")
            || clean.contains("prop")
            || clean.contains("funded")
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

    // MARK: - Broker-Confirmed Aqua Activity

    func loadAquaActivity(
        accessToken: String,
        fetchPositions: Bool = true
    ) async {
        isLoadingAquaActivity = true
        aquaActivityError = nil

        defer {
            isLoadingAquaActivity = false
        }

        do {
            let health = try await APIService.shared
                .fetchMatchTraderAuthHealth(
                    accessToken: accessToken
                )

            guard health.connected == true else {
                aquaConnection = nil
                aquaPositions = nil
                return
            }

            aquaConnection = health.connection

            guard fetchPositions else {
                return
            }

            aquaPositions = try await APIService.shared
                .fetchMatchTraderPositions(
                    MatchTraderSyncRequest(
                        broker: "Aqua Funding",
                        accountId: nil,
                        symbols: []
                    ),
                    accessToken: accessToken
                )
        } catch {
            aquaActivityError = error.localizedDescription
        }
    }

    func clearAllBackendTrades(
        accessToken: String
    ) async throws -> BackendTradeClearResponse {
        let response = try await APIService.shared
            .clearAllBackendTrades(
                accessToken: accessToken
            )

        openTrades = []
        calendar = nil
        tradeStats = nil
        mlInsights = nil
        selectedTrade = nil

        return response
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
        brokerHealth = nil
        tradeStats = nil
        mlInsights = nil
        aquaConnection = nil
        aquaPositions = nil
        aquaActivityError = nil
        isLoadingAquaActivity = false
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
