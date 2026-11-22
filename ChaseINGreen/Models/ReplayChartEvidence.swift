import Foundation

/// Presentation-only computations. All inputs are already revealed, closed OHLC.
enum ReplayChartEvidence {
    static func candles(_ replay: EpisodeReplay, at cursor: Date) -> [MarketCandle] {
        replay.visibleCandles(at: cursor).map {
            MarketCandle(timestamp: $0.end, open: $0.open, high: $0.high, low: $0.low,
                         close: $0.close, candleID: $0.id, finality: "closed", dataStatus: "available",
                         provider: replay.venue, symbol: replay.symbol)
        }
    }
    static func indicators(_ candles: [MarketCandle]) -> ReplayIndicatorSeries {
        let closes = candles.map(\.close)
        var line = [Double?](), signal = [Double?](), histogram = [Double?](), rsi = [Double?]()
        for i in closes.indices {
            let prefix = Array(closes.prefix(i + 1))
            let m = QuantIndicatorEngine.macd(prefix)
            line.append(m?.line); signal.append(m?.signal)
            histogram.append(m.map { $0.line - $0.signal })
            rsi.append(QuantIndicatorEngine.rsi(prefix, period: 14))
        }
        return ReplayIndicatorSeries(macd: line, signal: signal, histogram: histogram, rsi: rsi)
    }
    static func activeLevels(_ frame: ReplayFrame?) -> [String: Double] {
        guard let frame, let quantity = frame.numbers["quantity"], quantity > 0,
              frame.details["status"] != "SIMULATED_CLOSED" else { return [:] }
        return frame.numbers.filter { ["entry", "stop", "target"].contains($0.key) }
    }
    static func candleIndex(at time: Date, candles: [MarketCandle]) -> Int? {
        // Align between-close events with the last actually revealed candle, never a future bar.
        candles.lastIndex { $0.timestamp <= time }
    }
}
struct ReplayIndicatorSeries {
    var macd: [Double?] = [], signal: [Double?] = [], histogram: [Double?] = [], rsi: [Double?] = []
}

extension QuantIndicatorEngine {
    static func heikinAshi(_ source: [MarketCandle]) -> [MarketCandle] {
        var result = [MarketCandle]()
        for candle in source {
            let close = (candle.open + candle.high + candle.low + candle.close) / 4
            let open = result.last.map { ($0.open + $0.close) / 2 } ?? (candle.open + candle.close) / 2
            result.append(MarketCandle(timestamp: candle.timestamp, open: open,
                high: max(candle.high, open, close), low: min(candle.low, open, close), close: close,
                volume: candle.volume, candleID: candle.candleID, bucketStart: candle.bucketStart,
                bucketEnd: candle.bucketEnd, finality: candle.finality, dataStatus: candle.dataStatus,
                provider: candle.provider, symbol: candle.symbol, sourceTimeframe: candle.sourceTimeframe,
                effectiveTimeframe: candle.effectiveTimeframe, volumeKind: candle.volumeKind,
                sessionID: candle.sessionID, confidence: candle.confidence))
        }
        return result
    }
}
