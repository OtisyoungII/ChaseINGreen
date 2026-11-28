import XCTest
@testable import ChaseINGreenAuthorization

final class CustomerChartRestorationTests: XCTestCase {
    func testEMARequiresRealDepth() {
        for period in [12, 26, 50, 200] {
            XCTAssertTrue(QuantIndicatorEngine.emaSeries(Array(repeating: 10, count: period - 1), period: period).allSatisfy { $0 == nil })
            XCTAssertEqual(QuantIndicatorEngine.emaSeries(Array(repeating: 10, count: period), period: period).last!, 10)
        }
    }
    func testATRClosedEvidenceOnlyAndWarmup() {
        let candles = (0..<15).map { index in
            MarketCandle(timestamp: Date(timeIntervalSince1970: Double(index * 60)), open: 10, high: 12, low: 8, close: 10, finality: "closed")
        }
        XCTAssertEqual(QuantIndicatorEngine.atr(candles), 4)
        XCTAssertNil(QuantIndicatorEngine.atr(Array(candles.prefix(14))))
        let pending = MarketCandle(timestamp: Date(), open: 10, high: 1000, low: 1, close: 500, finality: "forming")
        XCTAssertEqual(QuantIndicatorEngine.atr(candles + [pending]), 4)
    }
    func testVolumeMissingDoesNotBecomeVWAP() {
        let candles = (0..<20).map { index in
            MarketCandle(timestamp: Date(timeIntervalSince1970: Double(index * 60)), open: 10, high: 12, low: 8, close: 10, finality: "closed")
        }
        XCTAssertTrue(QuantIndicatorEngine.calculate(candles).vwap.allSatisfy { $0 == nil })
    }
}
