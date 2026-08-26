import XCTest
@testable import ChaseINGreenAuthorization

final class BrokerPositionIdentityTests: XCTestCase {
    func testSameSymbolPositionStateDoesNotCollideAcrossAccounts() {
        let accountA = BrokerPositionIdentity(
            provider: "Aqua Funding",
            accountID: "account-a",
            positionID: "btc-position",
            fallbackTradeID: "trade-a"
        )
        let accountB = BrokerPositionIdentity(
            provider: "Aqua Funding",
            accountID: "account-b",
            positionID: "btc-position",
            fallbackTradeID: "trade-b"
        )

        XCTAssertNotEqual(accountA, accountB)
        XCTAssertNotEqual(accountA.rawValue, accountB.rawValue)
    }

    func testSameBrokerPositionTextDoesNotCollideAcrossProviders() {
        let aqua = BrokerPositionIdentity(
            provider: "Aqua Funding",
            accountID: "account-a",
            positionID: "position-1",
            fallbackTradeID: "trade-a"
        )
        let kraken = BrokerPositionIdentity(
            provider: "Kraken — Personal",
            accountID: "account-a",
            positionID: "position-1",
            fallbackTradeID: "trade-b"
        )

        XCTAssertNotEqual(aqua, kraken)
    }
}
