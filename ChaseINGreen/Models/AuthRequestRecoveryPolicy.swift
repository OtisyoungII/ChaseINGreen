import Foundation

/// Deterministic transport rules for authenticated request recovery. Token
/// acquisition and renewal remain owned by AuthSessionCoordinator.
enum AuthRequestRecoveryPolicy {
    static let credentialMinimumTTL = 60
    static let maximumUnauthorizedRetries = 1

    static func shouldRetry(
        statusCode: Int,
        hasAuthenticatedRequest: Bool,
        unauthorizedRetries: Int
    ) -> Bool {
        statusCode == 401
            && hasAuthenticatedRequest
            && unauthorizedRetries < maximumUnauthorizedRetries
    }

    static func acceptsCredentialResult(
        startedGeneration: UInt64,
        currentGeneration: UInt64,
        isAuthenticated: Bool
    ) -> Bool {
        isAuthenticated && startedGeneration == currentGeneration
    }

    static func requiresAuthentication(
        credentialsMissing: Bool,
        refreshTokenInvalid: Bool,
        networkUnavailable: Bool
    ) -> Bool {
        guard !networkUnavailable else { return false }
        return credentialsMissing || refreshTokenInvalid
    }
}
