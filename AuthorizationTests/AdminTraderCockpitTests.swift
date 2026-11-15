import XCTest
@testable import ChaseINGreenAuthorization

final class AdminTraderCockpitTests: XCTestCase {
    func testChartRetentionScopeAndNoExecutionInference() {
        var buffer = TraderChartBuffer(sessionID: "s", instrumentID: "i")
        for n in 0..<300 {
            XCTAssertTrue(buffer.accept(TraderChartEvent(id: String(n), sessionID: "s", instrumentID: "i", kind: .decision,
                at: Date(timeIntervalSince1970: Double(n)), value: nil, evidenceReference: "fixture")))
        }
        XCTAssertEqual(buffer.events.count, 256)
        XCTAssertTrue(buffer.events.allSatisfy { $0.kind == .decision })
        XCTAssertFalse(buffer.accept(TraderChartEvent(id: "wrong", sessionID: "other", instrumentID: "i", kind: .entry, at: Date(), value: 1, evidenceReference: "fixture")))
        XCTAssertFalse(buffer.accept(buffer.events.last!))
    }
    func testMissingEconomicsRemainNil() throws {
        let data = Data(#"{"identity":{"broker":"ibkr","connection_id":"c"},"side":"LONG","origin":"UNKNOWN","freshness":"STALE","quantity":null,"average_entry":null,"current_price":null,"unrealized_pnl":null,"realized_pnl":null}"#.utf8)
        let value = try JSONDecoder().decode(TraderPositionTruth.self, from: data)
        XCTAssertNil(value.current_price)
        XCTAssertNil(value.quantity)
        XCTAssertEqual(value.origin, "UNKNOWN")
    }
}
