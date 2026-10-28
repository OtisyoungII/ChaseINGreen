import XCTest
@testable import ChaseINGreenAuthorization

final class MarketNumberFormatTests: XCTestCase {
    struct Holding: Decodable {
        let quantity: Double
        let price: Double
        let displayQuantity: String
        let displayPrice: String
    }
    func testBackendContractFixtures() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "market_truth_contract", withExtension: "json", subdirectory: "Fixtures"))
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        for row in try decoder.decode([Holding].self, from: Data(contentsOf: url)) {
            XCTAssertEqual(MarketNumberFormat.quantity(row.quantity), row.displayQuantity)
            XCTAssertEqual(MarketNumberFormat.price(row.price), row.displayPrice)
            XCTAssertNotEqual(MarketNumberFormat.quantity(row.quantity), "0.00")
            XCTAssertNotEqual(MarketNumberFormat.price(row.price), "0.00")
            XCTAssertGreaterThan(row.quantity * row.price, 0)
        }
    }
    func testZeroMissingAndTinyValues() {
        XCTAssertEqual(MarketNumberFormat.quantity(0), "0")
        XCTAssertEqual(MarketNumberFormat.price(0), "0.00")
        XCTAssertEqual(MarketNumberFormat.quantity(nil), "Unavailable")
        XCTAssertEqual(MarketNumberFormat.price(.nan), "Unavailable")
        XCTAssertEqual(MarketNumberFormat.money(0.00001), "<$0.01")
        XCTAssertEqual(MarketNumberFormat.quantity(0.000742), "0.000742")
        XCTAssertNotEqual(MarketNumberFormat.price(1e-30), "0")
        XCTAssertEqual(MarketNumberFormat.money(0.00365182 * 81105.60), "$296.18")
    }
    func testAdditiveDiscoverStateAndOldResponse() throws {
        XCTAssertNil(try ScreenerResponse.decode(Data(#"{"status":"unavailable"}"#.utf8)).availability)
        XCTAssertEqual(try ScreenerResponse.decode(Data(#"{"status":"unavailable","availability":"disabled"}"#.utf8)).availability, "disabled")
    }
}
