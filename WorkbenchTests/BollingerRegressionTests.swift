import Foundation

@main
enum BollingerRegressionTests {
    static func main() {
        func unavailable(_ values: [Double], period: Int = 20, deviations: Double = 2) {
            let bands = QuantIndicatorEngine.bollinger(values, period: period, deviations: deviations)
            for series in [bands.upper, bands.middle, bands.lower] {
                precondition(series.count == values.count)
                precondition(series.allSatisfy { $0 == nil })
            }
        }
        // The original 19..<count range trapped for counts 0...18.
        for count in 0..<20 {
            unavailable(Array(repeating: 100, count: count))
        }
        for period in [Int.min, -1, 0, 21, Int.max] {
            unavailable(Array(repeating: 100, count: 20), period: period)
        }
        for deviation in [-1, Double.nan, .infinity, -.infinity] {
            unavailable(Array(repeating: 100, count: 20), deviations: deviation)
        }
        for invalid in [Double.nan, .infinity, -.infinity] {
            unavailable([1, invalid, 3], period: 3)
        }
        unavailable(Array(repeating: Double.greatestFiniteMagnitude, count: 20))
        unavailable([-1e200, 1e200], period: 2)
        unavailable([0, 4], period: 2, deviations: .greatestFiniteMagnitude)

        let bands = QuantIndicatorEngine.bollinger([1, 2, 3, 4], period: 3, deviations: 2)
        precondition(bands.middle == [nil, nil, 2, 3])
        precondition(abs(bands.upper[2]! - (2 + 2 * sqrt(2.0 / 3))) < 1e-12)
        precondition(abs(bands.lower[3]! - (3 - 2 * sqrt(2.0 / 3))) < 1e-12)
        let flat = QuantIndicatorEngine.bollinger(Array(repeating: 100, count: 20), period: 20, deviations: 2)
        precondition(flat.upper[19] == 100 && flat.lower[19] == 100)
        let single = QuantIndicatorEngine.bollinger([3, 4], period: 1, deviations: 2)
        precondition(single.upper == [3, 4] && single.lower == [3, 4])
        let zero = QuantIndicatorEngine.bollinger([1, 3], period: 2, deviations: 0)
        precondition(zero.upper == zero.middle && zero.lower == zero.middle)
        let recovery = QuantIndicatorEngine.bollinger([.nan, 2, 4, 6], period: 2, deviations: 2)
        precondition(recovery.middle == [nil, nil, 3, 5])

        for count in 0...20 {
            let candles = (0..<count).map { index in
                MarketCandle(timestamp: Date(timeIntervalSince1970: Double(index)),
                             open: 100, high: 100, low: 100, close: 100, volume: nil)
            }
            let snapshot = QuantIndicatorEngine.calculate(candles)
            precondition(snapshot.bollingerMiddle.count == count)
            precondition(snapshot.bollingerMiddle.compactMap { $0 }.count == (count == 20 ? 1 : 0))
        }
        print("Bollinger regression tests passed: short calculate inputs, invalid parameters/numbers, overflow, valid math, and window recovery")
    }
}
