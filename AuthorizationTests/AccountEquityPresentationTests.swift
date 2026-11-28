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
