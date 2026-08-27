import Foundation

/// Owns authentication-profile revalidation for the whole application.
/// A valid credential and a resolved profile are intentionally separate:
/// transient network failures may stale the profile, but never manufacture
/// Free/non-admin entitlements.
@MainActor
final class AppRefreshCoordinator {
    static let shared = AppRefreshCoordinator()

    private struct PersistedProfile: Codable {
        let ownerScope: String
        let profile: APIService.CurrentUserResponse
        let savedAt: Date
    }

    private let profileKey = "chaseingreen.current-user.last-known-good.v1"
    private let foregroundFreshness: TimeInterval = 30
    private let runtimeInactivityLimit: TimeInterval = 45 * 60
    private var persistedProfile: PersistedProfile?
    private var profileTask: Task<APIService.CurrentUserResponse, Error>?
    private var lastForegroundCompletion: Date?
    private var runtimeEntered = false
    private var backgroundedAt: Date?
    private var openTradesCache: (
        owner: String,
        value: [LoggedTradeResponse],
        savedAt: Date
    )?
    private var openTradesTask: (
        owner: String,
        task: Task<[LoggedTradeResponse], Error>
    )?
    private var brokerAccountsCache: (
        owner: String,
        value: [BrokerAccountResponse],
        savedAt: Date
    )?
    private var brokerAccountsTask: (
        owner: String,
        task: Task<[BrokerAccountResponse], Error>
    )?
    private var aquaHistoryTask: (
        owner: String,
        task: Task<Void, Error>
    )?
    private var aquaHistoryRetryAfter: [String: Date] = [:]
    private var watchlistsCache: (
        owner: String,
        value: [WatchlistResponse],
        savedAt: Date
    )?
    private var watchlistsTask: (
        owner: String,
        task: Task<[WatchlistResponse], Error>
    )?
    private var aquaPositionSyncTasks: [
        String: Task<BrokerSyncResponse, Error>
    ] = [:]
    private var portfolioMarksCache: (
        owner: String,
        value: PortfolioMarkToMarketResponse,
        savedAt: Date
    )?
    private var portfolioMarksTask: (
        owner: String,
        task: Task<PortfolioMarkToMarketResponse, Error>
    )?
    private var providerRefreshCompletedAt: [String: Date] = [:]
    private var providerRefreshInFlight = Set<String>()
    private var krakenInstrumentCache: (
        value: KrakenInstrumentUniverseResponse,
        savedAt: Date
    )?
    private var krakenInstrumentTask: Task<KrakenInstrumentUniverseResponse, Error>?
    private let portfolioFreshness: TimeInterval = 15
    private let aquaHistoryFailureCooldown: TimeInterval = 120
    private let watchlistFreshness: TimeInterval = 30
    private let krakenInstrumentFreshness: TimeInterval = 60 * 60

    private init() {
        if let data = UserDefaults.standard.data(forKey: profileKey) {
            persistedProfile = try? JSONDecoder().decode(
                PersistedProfile.self,
                from: data
            )
        }
    }

    func cachedProfile(
        accessToken: String
    ) -> APIService.CurrentUserResponse? {
        let scope = APIRefreshKey.ownerScope(accessToken: accessToken)
        guard persistedProfile?.ownerScope == scope else { return nil }
        return persistedProfile?.profile
    }

    func freshCachedProfile(
        accessToken: String,
        maximumAge: TimeInterval = 30
    ) -> APIService.CurrentUserResponse? {
        let scope = APIRefreshKey.ownerScope(accessToken: accessToken)
        guard let persistedProfile,
              persistedProfile.ownerScope == scope,
              Date().timeIntervalSince(persistedProfile.savedAt) < maximumAge else {
            return nil
        }
        return persistedProfile.profile
    }

    func revalidateProfile(
        accessToken: String,
        trigger: String
    ) async throws -> APIService.CurrentUserResponse {
        if let profileTask {
            print(
                "[AuthState] credentialState=valid profileState=revalidating "
                + "profileSource=cache profileFreshness=stale "
                + "reason=coalesced-\(trigger)"
            )
            return try await profileTask.value
        }

        let startedAt = Date()
        print(
            "[AuthState] credentialState=valid profileState=revalidating "
            + "profileSource=network profileFreshness=pending "
            + "reason=\(trigger)"
        )
        let task = Task {
            try await APIService.shared.fetchCurrentUser(
                accessToken: accessToken,
                forceRefresh: true
            )
        }
        profileTask = task

        do {
            let profile = try await task.value
            profileTask = nil
            save(profile, accessToken: accessToken)
            print(
                "[AuthState] credentialState=valid profileState=resolved "
                + "profileSource=network profileFreshness=fresh "
                + "reason=complete-\(trigger) elapsedMs="
                + "\(Int(Date().timeIntervalSince(startedAt) * 1000))"
            )
            return profile
        } catch {
            profileTask = nil
            print(
                "[AuthState] credentialState=valid profileState=stale "
                + "profileSource=cache profileFreshness=stale "
                + "reason=failed-\(trigger) elapsedMs="
                + "\(Int(Date().timeIntervalSince(startedAt) * 1000))"
            )
            throw error
        }
    }

    func foregroundProfile(
        accessToken: String
    ) async throws -> APIService.CurrentUserResponse {
        if profileTask != nil {
            print("[RefreshCoordinator] event=foreground action=coalesced")
            return try await revalidateProfile(
                accessToken: accessToken,
                trigger: "foreground"
            )
        }

        if let lastForegroundCompletion,
           Date().timeIntervalSince(lastForegroundCompletion)
            < foregroundFreshness,
           let cached = cachedProfile(accessToken: accessToken) {
            print("[RefreshCoordinator] event=foreground action=skipped-fresh")
            return cached
        }

        print("[RefreshCoordinator] event=foreground action=start")
        let profile = try await revalidateProfile(
            accessToken: accessToken,
            trigger: "foreground"
        )
        lastForegroundCompletion = Date()
        print("[RefreshCoordinator] event=foreground action=complete")
        return profile
    }

    func openTrades(
        accessToken: String,
        force: Bool = false
    ) async throws -> [LoggedTradeResponse] {
        let owner = APIRefreshKey.ownerScope(accessToken: accessToken)
        if !force,
           let cached = openTradesCache,
           cached.owner == owner,
           Date().timeIntervalSince(cached.savedAt) < portfolioFreshness {
            return cached.value
        }
        if let inFlight = openTradesTask,
           inFlight.owner == owner {
            return try await inFlight.task.value
        }
        openTradesTask?.task.cancel()
        let task = Task {
            try await APIService.shared.fetchOpenTrades(accessToken: accessToken)
        }
        openTradesTask = (owner, task)
        do {
            let value = try await task.value
            if openTradesTask?.owner == owner {
                openTradesTask = nil
            }
            openTradesCache = (owner, value, Date())
            return value
        } catch {
            if openTradesTask?.owner == owner {
                openTradesTask = nil
            }
            throw error
        }
    }

    func brokerAccounts(
        accessToken: String,
        force: Bool = false
    ) async throws -> [BrokerAccountResponse] {
        let owner = APIRefreshKey.ownerScope(accessToken: accessToken)
        if !force,
           let cached = brokerAccountsCache,
           cached.owner == owner,
           Date().timeIntervalSince(cached.savedAt) < portfolioFreshness {
            return cached.value
        }
        if let inFlight = brokerAccountsTask,
           inFlight.owner == owner {
            return try await inFlight.task.value
        }
        brokerAccountsTask?.task.cancel()
        let task = Task {
            try await APIService.shared.fetchBrokerAccounts(accessToken: accessToken)
        }
        brokerAccountsTask = (owner, task)
        do {
            let value = try await task.value
            if brokerAccountsTask?.owner == owner {
                brokerAccountsTask = nil
            }
            brokerAccountsCache = (owner, value, Date())
            return value
        } catch {
            if brokerAccountsTask?.owner == owner {
                brokerAccountsTask = nil
            }
            throw error
        }
    }

    func reconcileAquaClosedHistory(
        accessToken: String
    ) async -> Bool {
        let owner = APIRefreshKey.ownerScope(accessToken: accessToken)
        if let retryAfter = aquaHistoryRetryAfter[owner], retryAfter > Date() {
            print("[CalendarHistory] owner=\(owner) action=cooldown")
            return false
        }
        if let inFlight = aquaHistoryTask, inFlight.owner == owner {
            print("[CalendarHistory] owner=\(owner) action=coalesced")
            do {
                try await inFlight.task.value
                return true
            } catch {
                return false
            }
        }

        aquaHistoryTask?.task.cancel()
        let task = Task {
            try await APIService.shared.syncAquaClosedHistory(
                accessToken: accessToken
            )
        }
        aquaHistoryTask = (owner, task)
        print("[CalendarHistory] owner=\(owner) action=start")
        do {
            try await task.value
            if aquaHistoryTask?.owner == owner {
                aquaHistoryTask = nil
            }
            aquaHistoryRetryAfter.removeValue(forKey: owner)
            print("[CalendarHistory] owner=\(owner) action=complete")
            return true
        } catch {
            if aquaHistoryTask?.owner == owner {
                aquaHistoryTask = nil
            }
            aquaHistoryRetryAfter[owner] = Date().addingTimeInterval(
                aquaHistoryFailureCooldown
            )
            print(
                "[CalendarHistory] owner=\(owner) action=failed "
                + "cooldownSeconds=\(Int(aquaHistoryFailureCooldown))"
            )
            return false
        }
    }

    func watchlists(
        accessToken: String,
        force: Bool = false
    ) async throws -> [WatchlistResponse] {
        let owner = APIRefreshKey.ownerScope(accessToken: accessToken)
        if !force,
           let cached = watchlistsCache,
           cached.owner == owner,
           Date().timeIntervalSince(cached.savedAt) < watchlistFreshness {
            return cached.value
        }
        if let inFlight = watchlistsTask, inFlight.owner == owner {
            return try await inFlight.task.value
        }
        watchlistsTask?.task.cancel()
        let task = Task {
            try await APIService.shared.fetchWatchlists(accessToken: accessToken)
        }
        watchlistsTask = (owner, task)
        do {
            let value = try await task.value
            if watchlistsTask?.owner == owner { watchlistsTask = nil }
            watchlistsCache = (owner, value, Date())
            return value
        } catch {
            if watchlistsTask?.owner == owner { watchlistsTask = nil }
            throw error
        }
    }

    func syncAquaPositions(
        _ payload: MatchTraderSyncRequest,
        accessToken: String
    ) async throws -> BrokerSyncResponse {
        let owner = APIRefreshKey.ownerScope(accessToken: accessToken)
        let account = payload.accountId?.lowercased() ?? "portfolio"
        let key = "\(owner):\(account)"
        if let inFlight = aquaPositionSyncTasks[key] {
            print("[AquaPositionSync] scope=\(account) action=coalesced")
            return try await inFlight.value
        }
        let task = Task {
            try await APIService.shared.syncMatchTraderPositions(
                payload,
                accessToken: accessToken
            )
        }
        aquaPositionSyncTasks[key] = task
        do {
            let value = try await task.value
            aquaPositionSyncTasks.removeValue(forKey: key)
            return value
        } catch {
            aquaPositionSyncTasks.removeValue(forKey: key)
            throw error
        }
    }

    func portfolioMarks(
        accessToken: String,
        force: Bool = false
    ) async throws -> PortfolioMarkToMarketResponse {
        let owner = APIRefreshKey.ownerScope(accessToken: accessToken)
        if !force,
           let cached = portfolioMarksCache,
           cached.owner == owner,
           Date().timeIntervalSince(cached.savedAt) < portfolioFreshness {
            print("[MarketMarks] action=cache-hit")
            return cached.value
        }
        if let inFlight = portfolioMarksTask, inFlight.owner == owner {
            print("[MarketMarks] action=coalesced")
            return try await inFlight.task.value
        }
        let task = Task {
            try await APIService.shared.markOpenTradesToMarket(
                accessToken: accessToken
            )
        }
        portfolioMarksTask = (owner, task)
        do {
            let value = try await task.value
            if portfolioMarksTask?.owner == owner {
                portfolioMarksTask = nil
            }
            portfolioMarksCache = (owner, value, Date())
            return value
        } catch {
            if portfolioMarksTask?.owner == owner {
                portfolioMarksTask = nil
            }
            throw error
        }
    }

    func beginProviderRefresh(
        provider: String,
        connectionID: String,
        accessToken: String,
        maximumAge: TimeInterval,
        force: Bool = false
    ) -> Bool {
        let key = providerRefreshKey(
            provider: provider,
            connectionID: connectionID,
            accessToken: accessToken
        )
        if providerRefreshInFlight.contains(key) {
            print(
                "[ProviderRefresh] provider=\(provider) "
                + "connection=\(connectionID) action=coalesced"
            )
            return false
        }
        if !force,
           let completed = providerRefreshCompletedAt[key],
           Date().timeIntervalSince(completed) < maximumAge {
            let age = Int(Date().timeIntervalSince(completed))
            print(
                "[ProviderRefresh] provider=\(provider) "
                + "connection=\(connectionID) action=skipped-fresh "
                + "ageSeconds=\(age)"
            )
            return false
        }
        providerRefreshInFlight.insert(key)
        print(
            "[ProviderRefresh] provider=\(provider) "
            + "connection=\(connectionID) action=start"
        )
        return true
    }

    func krakenInstruments(
        accessToken: String,
        force: Bool = false
    ) async throws -> KrakenInstrumentUniverseResponse {
        if !force,
           let cached = krakenInstrumentCache,
           Date().timeIntervalSince(cached.savedAt) < krakenInstrumentFreshness {
            print("[InstrumentUniverse] provider=kraken action=cache-hit")
            return cached.value
        }
        if let krakenInstrumentTask {
            print("[InstrumentUniverse] provider=kraken action=coalesced")
            return try await krakenInstrumentTask.value
        }
        let task = Task {
            try await APIService.shared.fetchKrakenInstruments(
                accessToken: accessToken
            )
        }
        krakenInstrumentTask = task
        do {
            let value = try await task.value
            krakenInstrumentTask = nil
            krakenInstrumentCache = (value, Date())
            return value
        } catch {
            krakenInstrumentTask = nil
            if let cached = krakenInstrumentCache {
                print("[InstrumentUniverse] provider=kraken action=stale-preserved")
                return cached.value
            }
            throw error
        }
    }

    func finishProviderRefresh(
        provider: String,
        connectionID: String,
        accessToken: String,
        success: Bool
    ) {
        let key = providerRefreshKey(
            provider: provider,
            connectionID: connectionID,
            accessToken: accessToken
        )
        providerRefreshInFlight.remove(key)
        if success {
            providerRefreshCompletedAt[key] = Date()
        }
        print(
            "[ProviderRefresh] provider=\(provider) "
            + "connection=\(connectionID) action="
            + (success ? "complete" : "failed-preserved")
        )
    }

    /// Runtime entry is process-scoped on purpose. It survives SwiftUI root
    /// reconstruction and short backgrounding, but a genuine cold launch
    /// creates a new coordinator and therefore still requires explicit entry.
    func enterRuntime() {
        runtimeEntered = true
        backgroundedAt = nil
    }

    func recordBackground(at date: Date = Date()) {
        guard runtimeEntered else { return }
        backgroundedAt = date
    }

    func shouldResumeRuntime(at date: Date = Date()) -> Bool {
        guard runtimeEntered else { return false }
        guard let backgroundedAt else { return true }
        if date.timeIntervalSince(backgroundedAt) <= runtimeInactivityLimit {
            self.backgroundedAt = nil
            return true
        }
        runtimeEntered = false
        self.backgroundedAt = nil
        return false
    }

    func leaveRuntime() {
        runtimeEntered = false
        backgroundedAt = nil
    }

    func clear() {
        profileTask?.cancel()
        profileTask = nil
        persistedProfile = nil
        lastForegroundCompletion = nil
        openTradesTask?.task.cancel()
        brokerAccountsTask?.task.cancel()
        aquaHistoryTask?.task.cancel()
        watchlistsTask?.task.cancel()
        portfolioMarksTask?.task.cancel()
        krakenInstrumentTask?.cancel()
        for task in aquaPositionSyncTasks.values { task.cancel() }
        openTradesTask = nil
        brokerAccountsTask = nil
        aquaHistoryTask = nil
        watchlistsTask = nil
        portfolioMarksTask = nil
        krakenInstrumentTask = nil
        krakenInstrumentCache = nil
        openTradesCache = nil
        brokerAccountsCache = nil
        aquaHistoryRetryAfter.removeAll()
        watchlistsCache = nil
        portfolioMarksCache = nil
        aquaPositionSyncTasks.removeAll()
        providerRefreshCompletedAt.removeAll()
        providerRefreshInFlight.removeAll()
        leaveRuntime()
        UserDefaults.standard.removeObject(forKey: profileKey)
    }

    private func save(
        _ profile: APIService.CurrentUserResponse,
        accessToken: String
    ) {
        let value = PersistedProfile(
            ownerScope: APIRefreshKey.ownerScope(accessToken: accessToken),
            profile: profile,
            savedAt: Date()
        )
        persistedProfile = value
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }

    private func providerRefreshKey(
        provider: String,
        connectionID: String,
        accessToken: String
    ) -> String {
        let owner = APIRefreshKey.ownerScope(accessToken: accessToken)
        return "\(owner):\(provider.lowercased()):\(connectionID.lowercased())"
    }
}
