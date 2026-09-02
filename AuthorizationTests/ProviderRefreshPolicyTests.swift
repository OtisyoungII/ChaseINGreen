import XCTest
@testable import ChaseINGreenAuthorization

final class ProviderRefreshPolicyTests: XCTestCase {
    func testProviderSpecificScopesDoNotFanOut() {
        XCTAssertTrue(ProviderRefreshScope.provider("aqua").allows("match-trader"))
        XCTAssertFalse(ProviderRefreshScope.provider("aqua").allows("kraken"))
        XCTAssertFalse(ProviderRefreshScope.provider("aqua").allows("ibkr"))
        XCTAssertFalse(ProviderRefreshScope.provider("kraken").allows("aqua"))
        XCTAssertFalse(ProviderRefreshScope.provider("ibkr").allows("kraken"))
    }

    func testGlobalPortfolioAllowsEverySupportedProvider() {
        for provider in ["aqua", "kraken", "ibkr"] {
            XCTAssertTrue(ProviderRefreshScope.globalPortfolio.allows(provider))
        }
    }

    func testPresentationScopeNeverStartsExpensiveProviderSync() {
        XCTAssertEqual(
            ProviderRefreshPolicy.decision(
                provider: "aqua",
                scope: .presentation,
                isInFlight: false,
                lastSuccess: nil,
                lastFailure: nil,
                maximumAge: 180,
                failureCooldown: 300,
                force: false
            ),
            .presentationOnly
        )
    }

    func testDuplicateFreshAndFailedRefreshesAreSkipped() {
        let now = Date()
        XCTAssertEqual(
            ProviderRefreshPolicy.decision(
                provider: "kraken",
                scope: .globalPortfolio,
                isInFlight: true,
                lastSuccess: nil,
                lastFailure: nil,
                now: now,
                maximumAge: 180,
                failureCooldown: 300,
                force: false
            ),
            .coalesced
        )
        XCTAssertEqual(
            ProviderRefreshPolicy.decision(
                provider: "kraken",
                scope: .globalPortfolio,
                isInFlight: false,
                lastSuccess: now.addingTimeInterval(-30),
                lastFailure: nil,
                now: now,
                maximumAge: 180,
                failureCooldown: 300,
                force: false
            ),
            .fresh
        )
        XCTAssertEqual(
            ProviderRefreshPolicy.decision(
                provider: "ibkr",
                scope: .globalPortfolio,
                isInFlight: false,
                lastSuccess: nil,
                lastFailure: now.addingTimeInterval(-30),
                now: now,
                maximumAge: 180,
                failureCooldown: 300,
                force: false
            ),
            .failureCooldown
        )
    }

    func testExplicitGlobalRefreshCanBypassFreshnessButNotInFlight() {
        let now = Date()
        XCTAssertEqual(
            ProviderRefreshPolicy.decision(
                provider: "aqua",
                scope: .globalPortfolio,
                isInFlight: false,
                lastSuccess: now,
                lastFailure: now,
                now: now,
                maximumAge: 180,
                failureCooldown: 300,
                force: true
            ),
            .start
        )
        XCTAssertEqual(
            ProviderRefreshPolicy.decision(
                provider: "aqua",
                scope: .globalPortfolio,
                isInFlight: true,
                lastSuccess: now,
                lastFailure: nil,
                now: now,
                maximumAge: 180,
                failureCooldown: 300,
                force: true
            ),
            .coalesced
        )
    }
}
