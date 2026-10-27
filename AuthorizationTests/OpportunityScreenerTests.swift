import Foundation
import XCTest
@testable import ChaseINGreenAuthorization

final class OpportunityScreenerTests: XCTestCase {
    private func fixture() throws -> ScreenerResponse {
        let url = Bundle.module.url(forResource: "opportunity_screener_contract", withExtension: "json", subdirectory: "Fixtures")!
        return try ScreenerResponse.decode(Data(contentsOf: url))
    }
    func testBackendContractAndTypedNavigation() throws {
        let generation = try XCTUnwrap(try fixture().generation)
        XCTAssertEqual(generation.universeCount, 9)
        XCTAssertEqual(generation.scoringPolicy, "movement-ema-structure-v1")
        let nq = try XCTUnwrap(generation.candidates.first { $0.instrument.symbol == "NQ=F" })
        XCTAssertEqual(nq.instrument.navigationSymbol, "NQ=F")
        XCTAssertEqual(nq.instrument.instrumentType, "continuous_future")
        XCTAssertNotNil(nq.instrument.contractIdentity)
        let dow = try XCTUnwrap(generation.candidates.first { $0.instrument.symbol == "^DJI" })
        XCTAssertEqual(dow.instrument.navigationSymbol, "^DJI")
        XCTAssertEqual(dow.instrument.instrumentType, "cash_index")
        let crypto = try XCTUnwrap(generation.candidates.first { $0.instrument.symbol == "BTC-USD" })
        XCTAssertEqual(crypto.instrument.provider, "kraken")
        XCTAssertEqual(crypto.instrument.navigationSymbol, "BTC-USD")
        XCTAssertEqual(crypto.instrument.providerSymbol, "XXBTZUSD")
        XCTAssertTrue(generation.candidates.allSatisfy { !$0.executionAuthority && $0.instrument.supportedNavigation })
    }
    func testFiltersReasonsAndMissingScores() throws {
        let generation = try XCTUnwrap(try fixture().generation)
        XCTAssertEqual(generation.filtered(asset: "CRYPTO", direction: "BOTH").count, 2)
        XCTAssertTrue(generation.filtered(asset: "ALL", direction: "SHORT").allSatisfy { $0.direction == "SHORT" })
        XCTAssertTrue(generation.candidates.contains { $0.score == nil })
        XCTAssertTrue(generation.candidates.allSatisfy { $0.displayReasons.count <= 4 })
        XCTAssertEqual(ScreenerCandidate.reasonLabel("SHORT_MOMENTUM"), "Bearish momentum")
        XCTAssertEqual(ScreenerCandidate.reasonLabel("UNKNOWN"), "Additional evidence unavailable")
    }
    func testExpiryDoesNotRequireNetworkRefresh() throws {
        let generation = try XCTUnwrap(try fixture().generation)
        XCTAssertFalse(generation.isExpired(at: Date(timeIntervalSince1970: 0)))
        XCTAssertTrue(generation.isExpired(at: Date.distantFuture))
    }
    func testUnavailableGeneration() throws {
        let response = try ScreenerResponse.decode(Data(#"{"status":"unavailable","generation":null}"#.utf8))
        XCTAssertNil(response.generation)
    }
}
