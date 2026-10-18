import Foundation
import Combine
@preconcurrency import Auth0

extension Notification.Name {
    static let chaseINGreenAccessTokenRefreshed = Notification.Name(
        "chaseingreen.auth.access-token-refreshed"
    )
    static let chaseINGreenReauthenticationRequired = Notification.Name(
        "chaseingreen.auth.reauthentication-required"
    )
}

/// Owns the one Auth0 CredentialsManager used by both the authenticated shell
/// and the API transport. Concurrent 401 responses join one renewal instead
/// of launching independent refresh-token exchanges.
final class AuthSessionCoordinator: ObservableObject, @unchecked Sendable {
    static let shared = AuthSessionCoordinator()

    /// Last server-resolved `/me` capabilities for the authenticated session.
    /// Screens observe this shared truth instead of briefly manufacturing a
    /// Free user while their own entitlement request is pending.
    @Published private(set) var capabilityProfile: SessionCapabilityProfile?

    private let credentialsManager = CredentialsManager(
        authentication: Auth0.authentication(),
        storeKey: "chaseingreen.auth0.credentials"
    )
    private let lock = NSLock()
    private var accessToken: String?
    private var entitlementEpoch = EntitlementSessionEpoch()
    var sessionGeneration: UInt64 { lock.withLock { entitlementEpoch.generation } }
    var currentAccessToken: String? { lock.withLock { accessToken } }
    func isCurrentSession(_ expected: UInt64) -> Bool {
        lock.withLock { entitlementEpoch.accepts(expected) && accessToken != nil }
    }
    private func clearPresentation(for expected: UInt64) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.sessionGeneration == expected else { return }
            self.capabilityProfile = nil
            SubscriptionManager.shared.resetForAccountChange()
            AppRefreshCoordinator.shared.clear()
        }
    }
    private var refreshInProgress = false
    private var refreshWaiters: [CheckedContinuation<String, any Error>] = []

    private init() {}

    func activate(_ credentials: Credentials, persist: Bool) {
        if persist {
            _ = credentialsManager.store(credentials: credentials)
        }
        let activation = lock.withLock { () -> (generation: UInt64, changed: Bool) in
            guard accessToken != credentials.accessToken else {
                return (entitlementEpoch.generation, false)
            }
            entitlementEpoch.advance()
            accessToken = credentials.accessToken
            refreshInProgress = false
            let pending = refreshWaiters
            refreshWaiters.removeAll()
            pending.forEach { $0.resume(throwing: CancellationError()) }
            return (entitlementEpoch.generation, true)
        }
        if activation.changed {
            clearPresentation(for: activation.generation)
        }
    }

    func token(fallback: String) -> String {
        lock.withLock { accessToken ?? fallback }
    }

    /// Returns credentials with enough lifetime for a new API request. Auth0's
    /// CredentialsManager renews and persists them when necessary and
    /// serializes renewal work performed through this single instance.
    func validAccessToken(
        minTTL: Int = AuthRequestRecoveryPolicy.credentialMinimumTTL
    ) async throws -> String {
        let expectedGeneration = sessionGeneration
        guard isCurrentSession(expectedGeneration) else {
            throw authenticationRequiredError()
        }

        return try await withCheckedThrowingContinuation { continuation in
            credentialsManager.credentials(minTTL: minTTL) { [weak self] result in
                guard let self else {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                switch result {
                case .success(let credentials):
                    let outcome = self.lock.withLock { () -> (accepted: Bool, changed: Bool) in
                        guard self.entitlementEpoch.accepts(expectedGeneration),
                              self.accessToken != nil else {
                            return (false, false)
                        }
                        let changed = self.accessToken != credentials.accessToken
                        self.accessToken = credentials.accessToken
                        return (true, changed)
                    }
                    guard AuthRequestRecoveryPolicy.acceptsCredentialResult(
                        startedGeneration: expectedGeneration,
                        currentGeneration: self.sessionGeneration,
                        isAuthenticated: outcome.accepted
                    ) else {
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    if outcome.changed {
                        self.publishRefreshedToken(
                            credentials.accessToken,
                            generation: expectedGeneration
                        )
                    }
                    continuation.resume(returning: credentials.accessToken)

                case .failure(let error):
                    guard self.isCurrentSession(expectedGeneration) else {
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    if self.requiresReauthentication(error) {
                        DispatchQueue.main.async {
                            guard self.isCurrentSession(expectedGeneration) else { return }
                            NotificationCenter.default.post(
                                name: .chaseINGreenReauthenticationRequired,
                                object: nil
                            )
                        }
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func restore(
        minTTL: Int = 60,
        completion: @escaping (CredentialsManagerResult<Credentials>) -> Void
    ) {
        let restoreGeneration = sessionGeneration
        credentialsManager.credentials(minTTL: minTTL) { [weak self] result in
            guard let self, self.sessionGeneration == restoreGeneration else {
                completion(.failure(.noCredentials))
                return
            }
            if case .success(let credentials) = result {
                self.activate(credentials, persist: false)
            }
            completion(result)
        }
    }

    func clear() {
        _ = credentialsManager.clear()
        lock.withLock {
            entitlementEpoch.advance()
            accessToken = nil
            refreshInProgress = false
            let waiters = refreshWaiters
            refreshWaiters.removeAll()
            let error = NSError(
                domain: "AuthSessionCoordinator",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication was cleared."]
            )
            waiters.forEach { $0.resume(throwing: error) }
        }
        clearPresentation(for: sessionGeneration)
    }

    @MainActor
    func publishCapabilityProfile(_ profile: APIService.CurrentUserResponse, generation: UInt64) {
        guard isCurrentSession(generation) else { return }
        capabilityProfile = profile.sessionCapabilityProfile
    }

    func renewAfterUnauthorized(
        endpoint: String,
        rejectedToken: String
    ) async throws -> String {
        if let current = currentAccessToken, current != rejectedToken {
            return current
        }

        return try await withCheckedThrowingContinuation { continuation in
            var shouldStart = false
            var renewalGeneration: UInt64 = 0
            lock.withLock {
                refreshWaiters.append(continuation)
                if !refreshInProgress {
                    refreshInProgress = true
                    shouldStart = true
                    renewalGeneration = entitlementEpoch.generation
                }
            }
            guard shouldStart else { return }

            print("[AuthRefresh] reason=expired-token action=start")
            credentialsManager.renew { [weak self] result in
                guard let self else { return }
                let tokenResult = result.map(\.accessToken)
                let waiters: [CheckedContinuation<String, any Error>] =
                    self.lock.withLock {
                        guard self.entitlementEpoch.accepts(renewalGeneration) else { return [] }
                        self.refreshInProgress = false
                        if case .success(let token) = tokenResult {
                            self.accessToken = token
                        }
                        let waiting = self.refreshWaiters
                        self.refreshWaiters.removeAll()
                        return waiting
                    }

                guard self.isCurrentSession(renewalGeneration) else { return }
                switch tokenResult {
                case .success(let token):
                    print("[AuthRefresh] action=success")
                    DispatchQueue.main.async {
                        guard self.isCurrentSession(renewalGeneration) else { return }
                        NotificationCenter.default.post(
                            name: .chaseINGreenAccessTokenRefreshed,
                            object: token
                        )
                    }
                case .failure(let error):
                    print(
                        "[AuthRefresh] action=failed reason="
                        + String(describing: type(of: error))
                    )
                    if self.requiresReauthentication(error) {
                        DispatchQueue.main.async {
                            guard self.isCurrentSession(renewalGeneration) else { return }
                            NotificationCenter.default.post(
                                name: .chaseINGreenReauthenticationRequired,
                                object: nil
                            )
                        }
                    }
                }
                for waiter in waiters {
                    switch tokenResult {
                    case .success(let token):
                        waiter.resume(returning: token)
                    case .failure(let error):
                        waiter.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func authenticationRequiredError() -> NSError {
        NSError(
            domain: "AuthSessionCoordinator",
            code: 401,
            userInfo: [NSLocalizedDescriptionKey: "Authentication is required."]
        )
    }

    private func publishRefreshedToken(_ token: String, generation: UInt64) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isCurrentSession(generation) else { return }
            NotificationCenter.default.post(
                name: .chaseINGreenAccessTokenRefreshed,
                object: token
            )
        }
    }

    private func requiresReauthentication(_ error: CredentialsManagerError) -> Bool {
        if error == .noCredentials || error == .noRefreshToken {
            return true
        }
        guard let authenticationError = error.cause as? AuthenticationError else {
            return false
        }
        return authenticationError.isInvalidRefreshToken
            || authenticationError.isRefreshTokenDeleted
            || authenticationError.isLoginRequired
    }
}
