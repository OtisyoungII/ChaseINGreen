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
    private static let versionOneStableMode = true
    private struct WorkspaceSnapshot {
        let response: TradingWorkspaceResponse
        let positionSize: PositionSizeResponse?
        let brokerHealth: BrokerConnectionHealthResponse?
        let savedAt: Date
    }

    private struct AquaSnapshot {
        let connection: MatchTraderConnectionFeatures?
        let positions: MatchTraderPositionsResponse
        let savedAt: Date
    }

    private static var workspaceSnapshots: [
        String: WorkspaceSnapshot
    ] = [:]
    private static var aquaSnapshots: [
        String: AquaSnapshot
    ] = [:]
    private static let snapshotLimit = 8

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
    @Published var aquaProtectionNotice: String?
    @Published var isLoadingAquaActivity = false

    // MARK: - UI State

    @Published var selectedCard: TradingWorkspaceCard = .traderOS
    @Published var zoomedCard: TradingWorkspaceCard?
    @Published var selectedTrade: LoggedTradeResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var latestWorkspaceRequestID = UUID()
    private var lastAquaActivityFetch: Date?
    private var lastAquaActivityAccountID: String?

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

        if !force,
           let snapshot = Self.workspaceSnapshots[
                workspaceKey.storageKey
           ],
           Date().timeIntervalSince(snapshot.savedAt) < 120 {
            apply(snapshot.response)
            positionSize = snapshot.positionSize
            brokerHealth = snapshot.brokerHealth
        }

        guard APIRefreshGate.shared.shouldRefresh(workspaceKey, force: force) else {
            isLoading = false
            return
        }

        let requestID = UUID()
        latestWorkspaceRequestID = requestID

        APIRefreshGate.shared.begin(workspaceKey)

        isLoading = workspace == nil
        errorMessage = nil

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
            let resolvedBrokerHealth = try? await brokerHealthRequest

            guard latestWorkspaceRequestID == requestID,
                  !Task.isCancelled else {
                APIRefreshGate.shared.finish(workspaceKey)
                return
            }

            brokerHealth = resolvedBrokerHealth

            apply(response)

            let resolvedPositionSize: PositionSizeResponse? =
                if Self.versionOneStableMode {
                    nil
                } else {
                    await loadPositionSize(
                        symbol: symbol,
                        brokerProfile: brokerProfile,
                        accessToken: accessToken
                    )
                }

            guard latestWorkspaceRequestID == requestID,
                  !Task.isCancelled else {
                APIRefreshGate.shared.finish(workspaceKey)
                return
            }

            positionSize = resolvedPositionSize
            Self.workspaceSnapshots[workspaceKey.storageKey] =
                WorkspaceSnapshot(
                    response: response,
                    positionSize: resolvedPositionSize,
                    brokerHealth: resolvedBrokerHealth,
                    savedAt: Date()
                )
            Self.trimSnapshots(&Self.workspaceSnapshots)

            APIRefreshGate.shared.finish(workspaceKey)

            if !Self.versionOneStableMode {
                await loadSlowData(
                    symbol: symbol,
                    broker: broker,
                    accountKey: accountKey,
                    accessToken: accessToken,
                    force: force
                )
            }
        } catch {
            if latestWorkspaceRequestID == requestID,
               !Task.isCancelled {
                // A transient broker or analysis refresh must not erase a
                // usable cached workspace. Keep the last complete deck on
                // screen and reserve the fatal error card for a true
                // first-load failure.
                errorMessage = workspace == nil
                    ? error.localizedDescription
                    : nil
            }
            APIRefreshGate.shared.reset(workspaceKey)
        }

        if latestWorkspaceRequestID == requestID {
            isLoading = false
        }
    }

    // MARK: - Position Size

    private func loadPositionSize(
        symbol: String,
        brokerProfile: BrokerWorkspaceProfile,
        accessToken: String
    ) async -> PositionSizeResponse? {
        let normalizedAccountKey = (brokerProfile.accountKey ?? "").lowercased()

        func accountKeyVariants(_ value: String?) -> Set<String> {
            guard let value else { return [] }
            let clean = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return [] }
            var variants: Set<String> = [clean]
            if let separator = clean.lastIndex(of: ":") {
                let suffix = String(clean[clean.index(after: separator)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !suffix.isEmpty { variants.insert(suffix) }
            }
            return variants
        }

        let aquaAccount = aquaPositions?.accounts?.first { account in
            let identifiers = [
                account.accountId,
                account.tradingAccountId,
                account.accountUUID,
                account.accountName
            ]
            .reduce(into: Set<String>()) { result, value in
                result.formUnion(accountKeyVariants(value))
            }

            return brokerProfile.isMatchTrader
                && (normalizedAccountKey.isEmpty || !identifiers.isDisjoint(with: accountKeyVariants(brokerProfile.accountKey)))
        }

        let livePosition = aquaAccount?.positions?.first {
            $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame
        }

        let selectedTrade = openTrades.first { trade in
            guard trade.symbol.caseInsensitiveCompare(symbol) == .orderedSame else {
                return false
            }

            guard !normalizedAccountKey.isEmpty else {
                return true
            }

            let tradeIdentifiers = [
                trade.accountGroupKey,
                trade.brokerAccountId,
                trade.brokerAccountName
            ]
            .reduce(into: Set<String>()) { result, value in
                result.formUnion(accountKeyVariants(value))
            }
            return !tradeIdentifiers.isDisjoint(with: accountKeyVariants(brokerProfile.accountKey))
        }

        let tradeBroker = brokerProfile.isMatchTrader
            ? (brokerProfile.broker ?? "Aqua Funding")
            : (selectedTrade?.platform ?? brokerProfile.broker)
        let tradeAccountKey = brokerProfile.accountKey
            ?? livePosition?.accountId
            ?? selectedTrade?.accountGroupKey
            ?? selectedTrade?.brokerAccountId

        let matchedAccount = brokerAccounts.first { account in
            account.accountId.caseInsensitiveCompare(tradeAccountKey ?? "") == .orderedSame
            || account.accountName?.caseInsensitiveCompare(tradeAccountKey ?? "") == .orderedSame
        }

        let balanceHealth = aquaAccount?.balanceHealth
        let currentPrice = livePosition?.currentPrice
            ?? traderOS?.quoteResolution?.price
        let currentVolume = livePosition?.volume.map { Swift.abs($0) }
        let currentValue: Double? = {
            guard let currentVolume, let currentPrice else { return nil }
            return currentVolume * currentPrice
        }()

        return try? await APIService.shared.fetchPositionSize(
            symbol: symbol,
            broker: tradeBroker,
            accountKey: tradeAccountKey,
            accountBalance: balanceHealth?.balance
                ?? matchedAccount?.balance
                ?? matchedAccount?.startingBalance
                ?? selectedTrade?.accountSize
                ?? brokerProfile.accountBalance,
            accountEquity: balanceHealth?.equity
                ?? matchedAccount?.equity
                ?? matchedAccount?.balance
                ?? selectedTrade?.accountSize
                ?? brokerProfile.accountEquity,
            buyingPower: balanceHealth?.buyingPower
                ?? matchedAccount?.buyingPower,
            bestProbability: traderOS?.probability?.bestProbability,
            riskScore: traderOS?.ai?.riskScore ?? traderOS?.executionPlan?.riskScore,
            sizeProfile: traderOS?.executionPlan?.sizeProfile ?? traderOS?.probability?.tradeSizeSuggestion,
            pdtSensitive: brokerProfile.isMatchTrader ? false : isIBKRBroker(tradeBroker),
            propFirm: brokerProfile.isMatchTrader || isPropFirmBroker(tradeBroker),
            side: livePosition?.side ?? selectedTrade?.direction,
            currentPrice: currentPrice,
            entryPrice: livePosition?.openPrice ?? selectedTrade?.entryPrice,
            stopPrice: livePosition?.stopLoss,
            targetPrice: livePosition?.takeProfit,
            existingPositionSize: currentVolume ?? selectedTrade?.quantity,
            existingPositionValue: currentValue,
            currentOpenPnl: livePosition?.netProfit
                ?? livePosition?.profit
                ?? selectedTrade?.openPnl,
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
        fetchPositions: Bool = true,
        accountId: String? = nil,
        force: Bool = false,
        reconcileProtectionEvents: Bool = true
    ) async {
        let aquaCacheKey = (
            accountId?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()
            ?? "all"
        )

        if !force,
           fetchPositions,
           let snapshot = Self.aquaSnapshots[aquaCacheKey],
           Date().timeIntervalSince(snapshot.savedAt) < 120 {
            aquaConnection = snapshot.connection
            aquaPositions = snapshot.positions
            lastAquaActivityFetch = snapshot.savedAt
            lastAquaActivityAccountID = accountId
            return
        }

        // SwiftUI can trigger the workspace task, a symbol change, and a
        // broker refresh nearly together. Never let those events fan out into
        // overlapping forty-account Aqua discovery requests.
        guard !isLoadingAquaActivity else {
            return
        }

        if !force,
           fetchPositions,
           lastAquaActivityAccountID == accountId,
           let lastAquaActivityFetch,
           Date().timeIntervalSince(lastAquaActivityFetch) < 20 {
            return
        }

        isLoadingAquaActivity = true
        aquaActivityError = nil

        defer {
            isLoadingAquaActivity = false
        }

        do {
            let health = try await APIService.shared
                .fetchMatchTraderAuthHealth(
                    accessToken: accessToken,
                    forceRefresh: force
                )

            guard health.sessionReady else {
                aquaPositions = nil
                aquaActivityError = health.message
                    ?? "Aqua is reconnecting its saved session."
                return
            }

            aquaConnection = health.connection

            guard fetchPositions else {
                return
            }

            let livePositions = try await APIService.shared
                .fetchMatchTraderPositions(
                    MatchTraderSyncRequest(
                        broker: "Aqua Funding",
                        accountId: accountId,
                        symbols: [],
                        includeEmptyAccounts: false
                    ),
                    accessToken: accessToken,
                    forceRefresh: force
                )

            aquaPositions = livePositions
            lastAquaActivityFetch = Date()
            lastAquaActivityAccountID = accountId
            Self.aquaSnapshots[aquaCacheKey] = AquaSnapshot(
                connection: aquaConnection,
                positions: livePositions,
                savedAt: Date()
            )
            Self.trimSnapshots(&Self.aquaSnapshots)

            guard reconcileProtectionEvents else {
                return
            }

            let tradableAccountIds = livePositions.accounts?
                .filter {
                    $0.available != false
                        && $0.systemActive != false
                        && $0.balanceAvailable == true
                        && $0.effectivePositionCount > 0
                }
                .compactMap {
                    $0.accountId
                        ?? $0.tradingAccountId
                        ?? $0.accountUUID
                }
                ?? []

            // Protection-event reconciliation is needed only for accounts
            // that actually have a live position. Keep this bounded so one
            // Aqua screen cannot fan out across old evaluation accounts.
            let prioritizedAccountIds = tradableAccountIds.sorted {
                $0 == accountId && $1 != accountId
            }

            for accountId in prioritizedAccountIds.prefix(3) {
                let syncResponse = try? await APIService.shared
                    .syncMatchTraderPositions(
                    MatchTraderSyncRequest(
                        broker: "Aqua Funding",
                        accountId: accountId,
                        symbols: [],
                        includeEmptyAccounts: false
                    ),
                    accessToken: accessToken
                )

                if let event = syncResponse?
                    .protectionEvents?
                    .first {
                    aquaProtectionNotice = event.message
                        ?? "Aqua confirmed a protected position exit."
                }
            }
        } catch {
            // The connection health may still be useful, but the position
            // snapshot is not trustworthy after a failed fetch.
            if fetchPositions {
                aquaPositions = nil
            }
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
            mlInsights = try await APIService.shared.fetchMLInsights(
                accountKey: accountKey,
                broker: broker,
                symbol: symbol,
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

    private static func trimSnapshots<Value>(
        _ snapshots: inout [String: Value]
    ) {
        guard snapshots.count > snapshotLimit else {
            return
        }

        let keysToRemove = snapshots.keys.sorted().prefix(
            snapshots.count - snapshotLimit
        )

        for key in keysToRemove {
            snapshots.removeValue(forKey: key)
        }
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
