import XCTest
@testable import ChaseINGreenAuthorization

final class PortfolioMarketAttentionTests: XCTestCase {
    func testResearchYesDoesNotHideExecutionBlockOrVenue() throws {
        let json = #"{"as_of":"2026-11-20T23:00:00Z","rows":[{"instrument":"BTC","native_symbol":"BTCUSD","venue":"aqua","market_state":"AVAILABLE","session_state":"OPEN","attention_state":"FOCUSED","current_pressure":"LONG","decision":"YES","reason":"research thesis","execution_eligibility":"BLOCKED","execution_reason":"BLOCKED_BY_EXISTING_EXPOSURE"}]}"#
        let value = try JSONDecoder().decode(OperationsPortfolioAttention.self, from: Data(json.utf8))
        XCTAssertEqual(value.rows[0].decision, "YES")
        XCTAssertEqual(value.rows[0].execution_eligibility, "BLOCKED")
        XCTAssertEqual(value.rows[0].id, "aqua:BTCUSD")
        XCTAssertNil(value.rows[0].provider_timestamp)
    }
    func testStaleSnapshotCannotAppearCurrent() {
        XCTAssertFalse(OperationsPresentation.currentSnapshot("2026-11-20T23:00:00Z", now: Date(timeIntervalSince1970: 1_800_000_000)))
    }
}
