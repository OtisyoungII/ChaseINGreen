import XCTest
@testable import ChaseINGreenAuthorization

final class WorkstationInstrumentSearchTests: XCTestCase {
    func testExactPrefixPartialOrderAndIdentity() {
        let items = [
            WorkstationInstrumentItem(id: "wrapped", label: "WBTC/USD", symbol: "WBTCUSD"),
            WorkstationInstrumentItem(id: "native-1", label: "BTC/USD", symbol: "BTCUSD"),
            WorkstationInstrumentItem(id: "native-2", label: "BTC", symbol: "BTC")]
        XCTAssertEqual(WorkstationInstrumentSearch.results(items, query: "btc").map(\.id), ["native-2", "native-1", "wrapped"])
        XCTAssertEqual(WorkstationInstrumentSearch.results(items, query: "BTC/USD").first?.id, "native-1")
    }
    func testPromotionNeverOverridesMatchingOrMergesProducts() {
        let items = [
            WorkstationInstrumentItem(id: "spot", label: "BTC/USD", symbol: "BTCUSD", assetClass: "Spot crypto"),
            WorkstationInstrumentItem(id: "future", label: "BTC future", symbol: "BTC", assetClass: "Futures"),
            WorkstationInstrumentItem(id: "eth", label: "ETH/USD", symbol: "ETHUSD", assetClass: "Spot crypto")]
        XCTAssertEqual(WorkstationInstrumentSearch.results(items, query: "", recent: ["eth"]).first?.id, "eth")
        XCTAssertEqual(WorkstationInstrumentSearch.results(items, query: "", owned: ["ETHUSD"]).first?.id, "eth")
        XCTAssertEqual(WorkstationInstrumentSearch.results(items, query: "BTC", assetClass: "Spot crypto").map(\.id), ["spot"])
        XCTAssertTrue(WorkstationInstrumentSearch.results(items, query: "not-a-pair").isEmpty)
    }
    func testLargeCatalogAndMetadataSearch() {
        var items = (0..<10000).map { WorkstationInstrumentItem(id: "pair-\($0)", label: "Asset \($0)/USD", symbol: "ASSET\($0)USD") }
        items.append(WorkstationInstrumentItem(id: "XBTUSD", label: "BTC/USD", symbol: "BTCUSD", detail: "Bitcoin"))
        let start = Date()
        XCTAssertEqual(WorkstationInstrumentSearch.results(items, query: "Bitcoin").map(\.id), ["XBTUSD"])
        XCTAssertEqual(WorkstationInstrumentSearch.results(items, query: "BTC").first?.id, "XBTUSD")
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }
    func testMissingValuesAndTinyAmounts() {
        XCTAssertEqual(MarketNumberFormat.currency(nil, code: "USD"), "—")
        XCTAssertFalse(MarketNumberFormat.quantity(8.7e-9).lowercased().contains("e"))
        XCTAssertFalse(MarketNumberFormat.quantity(1e-19).lowercased().contains("e"))
        XCTAssertNotEqual(MarketNumberFormat.quantity(1e-19), "0")
        XCTAssertNotEqual(MarketNumberFormat.currency(-1234567.89, code: "USD"), "—")
        XCTAssertTrue(MarketNumberFormat.currency(1.25, code: nil).contains("currency unknown"))
        XCTAssertEqual(MarketNumberFormat.timestamp(nil), "Time unavailable")
    }
}
