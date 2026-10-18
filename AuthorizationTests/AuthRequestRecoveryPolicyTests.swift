import XCTest
@testable import ChaseINGreenAuthorization

final class AuthRequestRecoveryPolicyTests: XCTestCase {
    func testValidAuthenticatedRequestDoesNotRenewOrRetry() {
        XCTAssertFalse(AuthRequestRecoveryPolicy.shouldRetry(
            statusCode: 200,
            hasAuthenticatedRequest: true,
            unauthorizedRetries: 0
        ))
        XCTAssertEqual(AuthRequestRecoveryPolicy.credentialMinimumTTL, 60)
    }

    func testExpiredRenewableCredentialCanRemainInCurrentSession() {
        XCTAssertTrue(AuthRequestRecoveryPolicy.acceptsCredentialResult(
            startedGeneration: 7,
            currentGeneration: 7,
            isAuthenticated: true
        ))
    }

    func testAuthenticated401RetriesExactlyOnce() {
        XCTAssertTrue(AuthRequestRecoveryPolicy.shouldRetry(
            statusCode: 401,
            hasAuthenticatedRequest: true,
            unauthorizedRetries: 0
        ))
        XCTAssertFalse(AuthRequestRecoveryPolicy.shouldRetry(
            statusCode: 401,
            hasAuthenticatedRequest: true,
            unauthorizedRetries: 1
        ))
    }

    func testUnauthenticated401NeverStartsCredentialRecovery() {
        XCTAssertFalse(AuthRequestRecoveryPolicy.shouldRetry(
            statusCode: 401,
            hasAuthenticatedRequest: false,
            unauthorizedRetries: 0
        ))
    }

    func testConcurrentRequestsShareOneSessionGeneration() {
        let generation: UInt64 = 19
        XCTAssertTrue(AuthRequestRecoveryPolicy.acceptsCredentialResult(
            startedGeneration: generation,
            currentGeneration: generation,
            isAuthenticated: true
        ))
        XCTAssertTrue(AuthRequestRecoveryPolicy.acceptsCredentialResult(
            startedGeneration: generation,
            currentGeneration: generation,
            isAuthenticated: true
        ))
    }

    func testLogoutRejectsInFlightCredentialResult() {
        XCTAssertFalse(AuthRequestRecoveryPolicy.acceptsCredentialResult(
            startedGeneration: 4,
            currentGeneration: 5,
            isAuthenticated: false
        ))
    }

    func testAccountSwitchRejectsPreviousUsersCredentialResult() {
        XCTAssertFalse(AuthRequestRecoveryPolicy.acceptsCredentialResult(
            startedGeneration: 10,
            currentGeneration: 11,
            isAuthenticated: true
        ))
    }

    func testNetworkFailurePreservesAuthentication() {
        XCTAssertFalse(AuthRequestRecoveryPolicy.requiresAuthentication(
            credentialsMissing: false,
            refreshTokenInvalid: false,
            networkUnavailable: true
        ))
    }

    func testMissingOrInvalidRefreshCredentialRequiresAuthentication() {
        XCTAssertTrue(AuthRequestRecoveryPolicy.requiresAuthentication(
            credentialsMissing: true,
            refreshTokenInvalid: false,
            networkUnavailable: false
        ))
        XCTAssertTrue(AuthRequestRecoveryPolicy.requiresAuthentication(
            credentialsMissing: false,
            refreshTokenInvalid: true,
            networkUnavailable: false
        ))
    }
}
