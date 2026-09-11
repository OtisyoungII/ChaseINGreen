import XCTest
@testable import ChaseINGreenAuthorization

final class BrokerInstrumentContextTests: XCTestCase {
    func testExactHoldingIdentityPreservesProviderPairAndConnection() {
        let context = BrokerInstrumentContext(
            provider: "kraken",
            connectionID: "business",
            providerPair: "PEPEUSD",
            canonicalSymbol: "PEPE-USD",
            canonicalAsset: "PEPE",
            displayName: "Pepe"
        )
        XCTAssertEqual(context?.connectionID, "business")
        XCTAssertEqual(context?.providerPair, "PEPEUSD")
        XCTAssertEqual(context?.canonicalSymbol, "PEPE-USD")
    }

    func testManualActivityDoesNotManufactureBrokerContext() {
        XCTAssertNil(BrokerInstrumentContext(
            provider: "manual",
            connectionID: nil,
            providerPair: nil,
            canonicalSymbol: "BRENT",
            canonicalAsset: nil,
            displayName: "Brent"
        ))
    }

    func testExpectedKrakenHoldingsOwnOnlyTheirExactInstrument() {
        for asset in ["BTC", "ETH", "PEPE", "SOL", "HBAR"] {
            let context = BrokerInstrumentContext(
                provider: "kraken",
                connectionID: "personal",
                providerPair: "\(asset)USD",
                canonicalSymbol: "\(asset)-USD",
                canonicalAsset: asset,
                displayName: asset
            )
            XCTAssertTrue(context?.owns(canonicalSymbol: "\(asset)-USD") == true)
            XCTAssertFalse(context?.owns(canonicalSymbol: "BRENT") == true)
        }
    }
}
