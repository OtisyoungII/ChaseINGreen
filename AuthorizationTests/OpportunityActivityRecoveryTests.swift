import Foundation
import XCTest
@testable import ChaseINGreenAuthorization

final class OpportunityActivityRecoveryTests: XCTestCase {
    private func data() throws -> Data {
        let url = Bundle.module.url(forResource: "opportunity_activity_recovery_contract", withExtension: "json", subdirectory: "Fixtures")!
        return try Data(contentsOf: url)
    }
    private func candidates() throws -> [ScreenerCandidate] {
        try XCTUnwrap(try ScreenerResponse.decode(data()).generation).candidates
    }
    func testBackendVolumeAndRecoveryContract() throws {
        let nvda = try XCTUnwrap(try candidates().first { $0.instrument.symbol == "NVDA" })
        let activity = try XCTUnwrap(nvda.activity)
        XCTAssertEqual(activity.status, "AVAILABLE")
        XCTAssertEqual(activity.rvol, 2)
        XCTAssertEqual(activity.sampleCount, 20)
        XCTAssertEqual(activity.expectedSampleCount, 20)
        XCTAssertEqual(activity.liquidityStatus, "UNAVAILABLE")
        XCTAssertNotNil(activity.cutoffAt)
        XCTAssertNotNil(activity.informationAvailableAt)
        let recovery = try XCTUnwrap(nvda.recovery)
        XCTAssertEqual(recovery.state, "RECOVERING")
        XCTAssertTrue(recovery.qualifies)
        XCTAssertNotNil(recovery.invalidationLevel)
        XCTAssertNotNil(recovery.baseOriginAt)
        XCTAssertEqual(recovery.emaPeriod, 20)
        XCTAssertTrue(nvda.displayReasons.contains { $0.contains("Recovery structure improving") })
        XCTAssertTrue(nvda.displayReasons.contains { $0.contains("Volume 2.0× same-time median") })
        XCTAssertLessThanOrEqual(nvda.displayReasons.count, 4)
        XCTAssertFalse(nvda.executionAuthority)
    }
    func testCryptoIsVenueSpecificAndIndicesDoNotHaveFakeVolume() throws {
        let all = try candidates()
        let eth = try XCTUnwrap(all.first { $0.instrument.symbol == "ETH-USD" })
        XCTAssertEqual(eth.activity?.volumeUnit, "Kraken_base_asset_units")
        XCTAssertTrue(eth.displayReasons.contains { $0.contains("Kraken volume") && $0.contains("closed UTC hour") })
        let dow = try XCTUnwrap(all.first { $0.instrument.symbol == "^DJI" })
        XCTAssertEqual(dow.activity?.status, "NOT_APPLICABLE")
        XCTAssertNil(dow.activity?.rvol)
        XCTAssertFalse(dow.displayReasons.contains { $0.contains("Volume") })
    }
    func testStaleNeverPresentsPositiveRecoveryOrRvol() throws {
        let candidate = try XCTUnwrap(try candidates().first { $0.instrument.symbol == "NVDA" })
        let reasons = candidate.displayReasons(stale: true)
        XCTAssertTrue(reasons.contains("Recovery evidence is stale"))
        XCTAssertFalse(reasons.contains { $0.contains("Recovery structure improving") || $0.contains("same-time median") })
    }
    func testInvalidationWarningsPrecedePositiveReasons() throws {
        var raw = try JSONSerialization.jsonObject(with: data()) as! [String: Any]
        var generation = raw["generation"] as! [String: Any]
        var all = generation["candidates"] as! [[String: Any]]
        let index = all.firstIndex { ($0["instrument"] as! [String: Any])["symbol"] as? String == "NVDA" }!
        for state in ["INVALIDATED", "EXTENDED", "DEPRESSED", "STABILIZING", "UNKNOWN_STATE"] {
            var evidence = all[index]["recovery"] as! [String: Any]
            evidence["state"] = state
            evidence["qualifies"] = false
            all[index]["recovery"] = evidence
            all[index]["reasons"] = ["LONG_MOMENTUM", "LONG_STRUCTURE", "BREAKOUT_CONFIRMED", "EXTENDED_FROM_STRUCTURE"]
            generation["candidates"] = all
            raw["generation"] = generation
            let parsed = try ScreenerResponse.decode(JSONSerialization.data(withJSONObject: raw)).generation!.candidates[index]
            XCTAssertTrue(parsed.displayReasons.contains("Extended from structure"))
            XCTAssertFalse(parsed.displayReasons.contains { $0.contains("Recovery structure improving") })
            if state == "INVALIDATED" { XCTAssertTrue(parsed.displayReasons.contains { $0.contains("Recovery invalidated") }) }
            if state == "EXTENDED" { XCTAssertTrue(parsed.displayReasons.contains { $0.contains("Recovery extended") }) }
            XCTAssertLessThanOrEqual(parsed.displayReasons.count, 4)
        }
    }
    func testOldPhaseOneAndTwoAResponsesRemainCompatible() throws {
        for name in ["opportunity_screener_contract", "opportunity_relative_performance_contract"] {
            let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
            let result = try ScreenerResponse.decode(Data(contentsOf: url))
            XCTAssertTrue(result.generation!.candidates.allSatisfy { $0.activity == nil && $0.recovery == nil })
        }
        XCTAssertNil(try ScreenerResponse.decode(Data(#"{"status":"unavailable","generation":null}"#.utf8)).generation)
    }
}
