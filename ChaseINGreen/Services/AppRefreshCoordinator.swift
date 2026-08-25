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
}
