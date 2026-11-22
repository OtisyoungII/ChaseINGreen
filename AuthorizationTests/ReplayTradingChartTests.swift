import XCTest
@testable import ChaseINGreenAuthorization

final class ReplayTradingChartTests: XCTestCase {
    private func bars(_ count: Int) -> [MarketCandle] {
        (0..<count).map { i in
            let close = 100 + Double(i) * 0.2 + sin(Double(i))
            return MarketCandle(timestamp: Date(timeIntervalSince1970: Double(i * 900)),
                open: close-0.3,high: close+1,low: close-1,close: close,finality: "closed",dataStatus:"available")
        }
    }
    func testHeikinAshiUsesActualOHLCAndCausalRecurrence() {
        let input=bars(3), result=QuantIndicatorEngine.heikinAshi(input)
        XCTAssertEqual(result[0].open,(input[0].open+input[0].close)/2)
        XCTAssertEqual(result[1].open,(result[0].open+result[0].close)/2)
        XCTAssertEqual(result[1].close,(input[1].open+input[1].high+input[1].low+input[1].close)/4)
        XCTAssertEqual(QuantIndicatorEngine.heikinAshi(Array(input.prefix(2))).map(\.close),Array(result.prefix(2)).map(\.close))
    }
    func testBollingerHasRealBandsAndNoFutureLeakage() {
        let values=bars(40).map(\.close)
        let all=QuantIndicatorEngine.bollinger(values,period:20,deviations:2)
        XCTAssertTrue(all.middle.prefix(19).allSatisfy { $0 == nil })
        XCTAssertEqual(all.middle[19]!,values.prefix(20).reduce(0,+)/20,accuracy:1e-10)
        let prefix=QuantIndicatorEngine.bollinger(Array(values.prefix(25)),period:20,deviations:2)
        XCTAssertEqual(prefix.upper,Array(all.upper.prefix(25)))
        XCTAssertGreaterThan(all.upper[19]!,all.middle[19]!)
        XCTAssertLessThan(all.lower[19]!,all.middle[19]!)
    }
    func testEMAWarmupAndPrefixAlignment() {
        let values=bars(220).map(\.close)
        for period in [12,26,50,200] {
            let series=QuantIndicatorEngine.emaSeries(values,period:period)
            XCTAssertTrue(series.prefix(period-1).allSatisfy { $0 == nil })
            XCTAssertNotNil(series[period-1])
            XCTAssertEqual(QuantIndicatorEngine.emaSeries(Array(values.prefix(205)),period:period),Array(series.prefix(205)))
        }
    }
    func testMACDPanelAndRSIHaveNoFutureValues() {
        let all=ReplayChartEvidence.indicators(bars(60)), early=ReplayChartEvidence.indicators(bars(40))
        XCTAssertTrue(all.macd.prefix(34).allSatisfy { $0 == nil })
        XCTAssertTrue(all.rsi.prefix(14).allSatisfy { $0 == nil })
        XCTAssertEqual(early.macd,Array(all.macd.prefix(40)))
        XCTAssertEqual(early.signal,Array(all.signal.prefix(40)))
        XCTAssertEqual(early.rsi,Array(all.rsi.prefix(40)))
        for i in 34..<60 { XCTAssertEqual(all.histogram[i]!,all.macd[i]!-all.signal[i]!,accuracy:1e-10) }
        XCTAssertTrue(all.rsi.compactMap { $0 }.allSatisfy { (0...100).contains($0) })
    }
    func testHistoricalProtectionAndClosedPositionLevels() {
        let t=Date(timeIntervalSince1970:0)
        let first=ReplayFrame(at:t,numbers:["entry":100,"stop":95,"quantity":2],details:["status":"ACTIVE"])
        let next=ReplayFrame(at:t.addingTimeInterval(10),numbers:["entry":100,"stop":101,"quantity":1],details:["status":"ACTIVE"])
        let done=ReplayFrame(at:t.addingTimeInterval(20),numbers:["quantity":0],details:["status":"SIMULATED_CLOSED"])
        let v=ReplayVariant(id:"recorded",label:"Original",mode:"RECORDED_SHADOW",method:"Recorded",evidence_hash:nil,frames:[first,next,done],markers:[],scorecard:[:])
        XCTAssertEqual(ReplayChartEvidence.activeLevels(v.frame(at:t.addingTimeInterval(9)))["stop"],95)
        XCTAssertEqual(ReplayChartEvidence.activeLevels(v.frame(at:t.addingTimeInterval(10)))["stop"],101)
        XCTAssertTrue(ReplayChartEvidence.activeLevels(v.frame(at:t.addingTimeInterval(20))).isEmpty)
    }
    func testMarkersCannotUseUnrevealedCandle() {
        let input=bars(3)
        XCTAssertNil(ReplayChartEvidence.candleIndex(at:Date(timeIntervalSince1970:-1),candles:input))
        XCTAssertEqual(ReplayChartEvidence.candleIndex(at:Date(timeIntervalSince1970:1000),candles:input),1)
        XCTAssertTrue(ReplayChartEvidence.indicators([]).macd.isEmpty)
    }
    func testViewportSynchronizesPanelsAndBoundsPan() {
        var viewport=ChartViewport();viewport.zoom(scale:2,loadedCount:100)
        viewport.pan(candles:500,loadedCount:100)
        XCTAssertEqual(viewport.range(loadedCount:100).lowerBound,0)
        viewport.reset();XCTAssertEqual(viewport.range(loadedCount:100).upperBound,100)
    }
}
