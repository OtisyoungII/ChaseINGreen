import Foundation
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
final class AuthSessionCoordinator: @unchecked Sendable {
    static let shared = AuthSessionCoordinator()

    private let credentialsManager = CredentialsManager(
        authentication: Auth0.authentication(),
        storeKey: "chaseingreen.auth0.credentials"
    )
    private let lock = NSLock()
    private var accessToken: String?
    private var refreshInProgress = false
    private var refreshWaiters: [CheckedContinuation<String, any Error>] = []

    private init() {}

    func activate(_ credentials: Credentials, persist: Bool) {
        if persist {
            _ = credentialsManager.store(credentials: credentials)
        }
        lock.withLock { accessToken = credentials.accessToken }
    }

    func token(fallback: String) -> String {
        lock.withLock { accessToken ?? fallback }
    }

    func restore(
        minTTL: Int = 60,
        completion: @escaping (CredentialsManagerResult<Credentials>) -> Void
    ) {
        credentialsManager.credentials(minTTL: minTTL) { [weak self] result in
            if case .success(let credentials) = result {
                self?.lock.withLock { self?.accessToken = credentials.accessToken }
            }
            completion(result)
        }
    }

    func clear() {
        _ = credentialsManager.clear()
        lock.withLock {
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
    }

    func renewAfterUnauthorized(endpoint: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            var shouldStart = false
            lock.withLock {
                refreshWaiters.append(continuation)
                if !refreshInProgress {
                    refreshInProgress = true
                    shouldStart = true
                }
            }
            guard shouldStart else { return }

            print("[AuthRefresh] reason=expired-token action=start")
            credentialsManager.credentials(minTTL: 300) { [weak self] result in
                guard let self else { return }
                let tokenResult = result.map(\.accessToken)
                let waiters: [CheckedContinuation<String, any Error>] =
                    self.lock.withLock {
                        self.refreshInProgress = false
                        if case .success(let token) = tokenResult {
                            self.accessToken = token
                        }
                        let waiting = self.refreshWaiters
                        self.refreshWaiters.removeAll()
                        return waiting
                    }

                switch tokenResult {
                case .success(let token):
                    print("[AuthRefresh] action=success")
                    DispatchQueue.main.async {
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
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .chaseINGreenReauthenticationRequired,
                            object: nil
                        )
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
}
