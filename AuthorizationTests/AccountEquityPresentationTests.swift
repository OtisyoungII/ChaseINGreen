import XCTest
@testable import ChaseINGreenAuthorization

final class AccountEquityPresentationTests: XCTestCase {
    func testRetainedEquityNotCurrent() {
        let result = AccountEquityPresentation.aggregate([
            .init(value: 10, fresh: false, currency: "USD"),
            .init(value: 20, fresh: false, currency: "USD")])
        XCTAssertEqual(result.title, "Last-known equity")
        XCTAssertEqual(result.value, 30)
    }
    func testMixedFreshnessNotSummed() {
        let result = AccountEquityPresentation.aggregate([
            .init(value: 10, fresh: true, currency: "USD"),
            .init(value: 20, fresh: false, currency: "USD")])
        XCTAssertNil(result.value)
        XCTAssertTrue(result.title.contains("Mixed freshness"))
    }
    func testMissingValueNotZero() {
        XCTAssertNil(AccountEquityPresentation.aggregate([
            .init(value: nil, fresh: false, currency: "USD")]).value)
        XCTAssertNil(AccountEquityPresentation.aggregate([]).value)
    }
    func testCurrenciesNotSilentlyMixed() {
        XCTAssertNil(AccountEquityPresentation.aggregate([
            .init(value: 10, fresh: true, currency: "USD"),
            .init(value: 20, fresh: true, currency: "EUR")]).value)
    }
    func testFreshZeroIsValid() {
        let result = AccountEquityPresentation.aggregate([.init(value: 0, fresh: true, currency: "USD")])
        XCTAssertEqual(result.value, 0)
        XCTAssertEqual(result.title, "Current snapshot equity")
    }
    func testSameNameDistinctSuffixWithoutInferredClassification() {
        XCTAssertEqual(AccountEquityPresentation.accountLabel(name: "Owner", number: "U00001111", classification: nil), "Owner · …1111")
        XCTAssertNotEqual(AccountEquityPresentation.accountLabel(name: "Owner", number: "U00002222", classification: nil), "Owner · …1111")
    }
}

final class AccountWorkspaceClassificationTests: XCTestCase {
    func testIgnoredAndExpiredRemainOutsideActiveTotals() {
        XCTAssertTrue(AccountWorkspaceClassification.historical(status: "active", active: true, participation: "ignored"))
        XCTAssertTrue(AccountWorkspaceClassification.historical(status: "expired", active: true, participation: "active"))
    }
    func testAccountClassificationNotInferredFromBalanceOrName() {
        XCTAssertFalse(AccountWorkspaceClassification.matches("Funded", status: "active", active: true, participation: "active", type: nil, ownership: nil, funding: nil, connection: "connected"))
        XCTAssertFalse(AccountWorkspaceClassification.matches("Business", status: "active", active: true, participation: "active", type: nil, ownership: nil, funding: nil, connection: "connected"))
    }
    func testVerifiedClassificationAndDisconnectedAreIndependent() {
        XCTAssertTrue(AccountWorkspaceClassification.matches("Personal", status: "active", active: true, participation: "active", type: "cash", ownership: "personal", funding: nil, connection: "disconnected"))
        XCTAssertTrue(AccountWorkspaceClassification.matches("Disconnected", status: "active", active: true, participation: "active", type: "cash", ownership: "personal", funding: nil, connection: "disconnected"))
    }
}

final class AquaConnectionPresentationTests: XCTestCase {
    func testExpiredTimestampCannotDisplayAuthenticated() {
        XCTAssertEqual(AquaSessionReadinessPolicy.displayStatus(authenticated: true, tokenExpired: false, expiresAt: "2020-01-01T00:00:00Z"), "Session expired · refresh required")
    }
    func testMissingExpiryIsNotAssumedFresh() {
        XCTAssertEqual(AquaSessionReadinessPolicy.displayStatus(authenticated: true, tokenExpired: false, expiresAt: nil), "Current session verification unavailable")
    }
}

final class CapitalScopePresentationTests: XCTestCase {
    func testChallengeAndOwnedAssetsNeverSummed() {
        XCTAssertNil(AccountEquityPresentation.aggregate([
            .init(value: 10000, fresh: true, currency: "USD", capitalScope: "prop"),
            .init(value: 100, fresh: true, currency: "USD", capitalScope: "brokerage")]).value)
    }
}
