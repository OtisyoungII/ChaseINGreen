import XCTest
@testable import ChaseINGreenAuthorization

final class AdminNavigationPresentationTests: XCTestCase {
    func testMoneyUnknownIsNotZeroAndPrecisionIsHuman() {
        XCTAssertEqual(AdminNavigationPresentation.money(nil), "Unavailable")
        XCTAssertEqual(AdminNavigationPresentation.money(.nan), "Unavailable")
        XCTAssertFalse(AdminNavigationPresentation.money(676.11999512).contains("119995"))
        XCTAssertTrue(AdminNavigationPresentation.money(676.11999512).contains("676.12"))
        XCTAssertTrue(AdminNavigationPresentation.money(3, currency: nil).contains("currency unknown"))
        XCTAssertNotEqual(AdminNavigationPresentation.quantity(0.000123), "0")
    }
    func testMalformedTimeDoesNotInventFreshness() {
        XCTAssertEqual(AdminNavigationPresentation.time(nil), "Time unavailable")
        XCTAssertEqual(AdminNavigationPresentation.time("invalid"), "Time unavailable")
    }
    func testAccountIdentityAndZeroHoldingsAndStaleStatus() throws {
        let data = Data(#"{"id":"canonical","label":"Otis D Young","provider":"ibkr","ownership":"personal","connection_suffix":"uuid","status":"LIVE","connection_status":"connected","authentication":"authenticated","native_account":"U21161141","binding_verified":true,"metrics":[],"asset_balances":[],"risk":[],"holdings":[{"symbol":"OLD","quantity":0,"state":"OBSERVED","protection":"UNKNOWN"},{"symbol":"CHTR","quantity":1.4,"state":"OBSERVED","protection":"UNKNOWN"},{"symbol":"UNKNOWN","quantity":null,"state":"UNKNOWN","protection":"UNKNOWN"}],"orders_status":"UNKNOWN","protection":"UNKNOWN","restrictions":"UNKNOWN","eligibility":"UNKNOWN","reason":"test"}"#.utf8)
        let account = try JSONDecoder().decode(OperationsAccount.self, from: data)
        XCTAssertEqual(AdminNavigationPresentation.account(account), "IBKR Personal · …1141")
        XCTAssertEqual(AdminNavigationPresentation.openHoldings(account).map(\.symbol), ["CHTR", "UNKNOWN"])
        XCTAssertEqual(AdminNavigationPresentation.status(account, snapshot: "bad"), "STALE")
        XCTAssertEqual(account.holdings.count, 3, "Presentation must retain original evidence")
    }
}
