import Foundation

enum PatternAnnotationKind: Equatable, Decodable {
    case horizontalLevel, priceRegion, patternPoint, label, unknown(String)

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "horizontal_level": self = .horizontalLevel
        case "price_region": self = .priceRegion
        case "pattern_point": self = .patternPoint
        case "label": self = .label
        default: self = .unknown(raw)
        }
    }
}

struct PatternStreamIdentity: Decodable, Equatable {
    let provider: String?
    let symbol: String
    let requestedTimeframe: String
    let effectiveTimeframe: String

    enum CodingKeys: String, CodingKey {
        case provider, symbol
        case requestedTimeframe = "requested_timeframe"
        case effectiveTimeframe = "effective_timeframe"
    }
}

struct PatternChartAnnotationDTO: Decodable, Identifiable, Equatable {
    let annotationID: String
    let annotationType: PatternAnnotationKind
    let semanticRole: String
    let semanticRoles: [String]
    let label: String
    let labels: [String]
    let patternID: String
    let patternState: String
    let sourceCandleIDs: [String]
    let finality: String
    let price: Double?
    let priceLow: Double?
    let priceHigh: Double?
    let decisionAuthority: Bool

    var id: String { annotationID }

    enum CodingKeys: String, CodingKey {
        case annotationID = "annotation_id"
        case annotationType = "annotation_type"
        case semanticRole = "semantic_role"
        case semanticRoles = "semantic_roles"
        case label, labels
        case patternID = "pattern_id"
        case patternState = "pattern_state"
        case sourceCandleIDs = "source_candle_ids"
        case finality, price
        case priceLow = "price_low"
        case priceHigh = "price_high"
        case decisionAuthority = "decision_authority"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        annotationID = try c.decode(String.self, forKey: .annotationID)
        annotationType = try c.decode(PatternAnnotationKind.self, forKey: .annotationType)
        semanticRole = try c.decode(String.self, forKey: .semanticRole)
        semanticRoles = try c.decodeIfPresent([String].self, forKey: .semanticRoles) ?? [semanticRole]
        label = try c.decode(String.self, forKey: .label)
        labels = try c.decodeIfPresent([String].self, forKey: .labels) ?? [label]
        patternID = try c.decode(String.self, forKey: .patternID)
        patternState = try c.decode(String.self, forKey: .patternState)
        sourceCandleIDs = try c.decodeIfPresent([String].self, forKey: .sourceCandleIDs) ?? []
        finality = try c.decode(String.self, forKey: .finality)
        price = try c.decodeIfPresent(Double.self, forKey: .price)
        priceLow = try c.decodeIfPresent(Double.self, forKey: .priceLow)
        priceHigh = try c.decodeIfPresent(Double.self, forKey: .priceHigh)
        decisionAuthority = try c.decodeIfPresent(Bool.self, forKey: .decisionAuthority) ?? false
    }
}

struct MarketPatternDTO: Decodable, Identifiable, Equatable {
    let patternID: String
    let patternNamespace: String
    let patternType: String
    let state: String
    let finality: String
    let dataStatus: String
    let decisionAuthority: Bool
    let lifecycleEventAuthority: String?
    let lifecycleEventNotificationEligible: Bool
    let transition: String?

    var id: String { patternID }
    var isAuthoritativePresentation: Bool {
        decisionAuthority == false
            && (state == "confirmed" || state == "continuing")
            && finality == "closed" && dataStatus == "available"
            && lifecycleEventAuthority == "authoritative_closed_available"
    }

    enum CodingKeys: String, CodingKey {
        case patternID = "pattern_id"
        case patternNamespace = "pattern_namespace"
        case patternType = "pattern_type"
        case state, finality
        case dataStatus = "data_status"
        case decisionAuthority = "decision_authority"
        case lifecycleEventAuthority = "lifecycle_event_authority"
        case lifecycleEventNotificationEligible = "lifecycle_event_notification_eligible"
        case transition
    }
}

enum PatternPresentationAuthority {
    static func authoritativePatternIDs(in patterns: [MarketPatternDTO]) -> Set<String> {
        Set(patterns.lazy.filter(\.isAuthoritativePresentation).map(\.patternID))
    }

    static func isAuthoritative(
        _ annotation: PatternChartAnnotationDTO,
        authoritativePatternIDs: Set<String>
    ) -> Bool {
        annotation.decisionAuthority == false
            && authoritativePatternIDs.contains(annotation.patternID)
    }
}

struct MarketPatternResponse: Decodable, Equatable {
    let schemaVersion: String
    let symbol: String
    let timeframe: String
    let status: String
    let streamIdentity: PatternStreamIdentity
    let patterns: [MarketPatternDTO]
    let annotations: [PatternChartAnnotationDTO]
    let decisionAuthority: Bool
    let reasonCodes: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case symbol, timeframe, status, patterns, annotations
        case streamIdentity = "stream_identity"
        case decisionAuthority = "decision_authority"
        case reasonCodes = "reason_codes"
    }
}

struct PatternStreamExpectation: Equatable {
    let symbol: String
    let requestedTimeframe: String
    let effectiveTimeframe: String
    let provider: String?

    func accepts(_ response: MarketPatternResponse) -> Bool {
        guard response.status == "available",
              response.decisionAuthority == false,
              normalized(response.symbol) == normalized(symbol),
              normalized(response.streamIdentity.symbol) == normalized(symbol),
              response.streamIdentity.requestedTimeframe.lowercased() == requestedTimeframe.lowercased(),
              response.streamIdentity.effectiveTimeframe.lowercased() == effectiveTimeframe.lowercased()
        else { return false }
        guard let expectedProvider = provider, !expectedProvider.isEmpty else { return true }
        return normalized(response.streamIdentity.provider ?? "") == normalized(expectedProvider)
    }

    private func normalized(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

struct ChartViewport: Equatable {
    var visibleCount: Int = 60
    var trailingOffset: Int = 0

    mutating func reset() { trailingOffset = 0 }

    mutating func pan(candles: Int, loadedCount: Int) {
        let maximum = max(loadedCount - min(visibleCount, loadedCount), 0)
        trailingOffset = min(max(trailingOffset + candles, 0), maximum)
    }

    mutating func zoom(scale: Double, loadedCount: Int) {
        guard scale.isFinite, scale > 0 else { return }
        let next = Int((Double(visibleCount) / scale).rounded())
        visibleCount = min(max(next, min(12, max(loadedCount, 1))), max(loadedCount, 1))
        pan(candles: 0, loadedCount: loadedCount)
    }

    func range(loadedCount: Int) -> Range<Int> {
        guard loadedCount > 0 else { return 0..<0 }
        let count = min(max(visibleCount, 1), loadedCount)
        let end = max(loadedCount - min(trailingOffset, loadedCount - count), count)
        return (end - count)..<end
    }
}

struct ChartGeometry {
    static func y(price: Double, minimum: Double, maximum: Double, top: Double, height: Double) -> Double {
        let range = max(maximum - minimum, 0.000_000_1)
        return top + (1 - (price - minimum) / range) * height
    }

    static func x(index: Int, count: Int, left: Double, width: Double) -> Double {
        count > 1 ? left + Double(index) / Double(count - 1) * width : left + width / 2
    }
}

enum QuantMetricID: String, CaseIterable, Codable, Hashable {
    case ema, vwap, bollinger, rsi, macd
}

/// Generic sensor evidence. Future option measurements use metric IDs such as
/// delta/gamma/theta/vega/rho and context keys for strike, expiration,
/// moneyness, underlying thesis, expected magnitude, and expected speed.
/// These values remain observations and never carry execution permission.
struct QuantitativeEvidence: Equatable {
    let metricID: String
    let timeframe: String
    let value: Double?
    let series: [Double]
    let state: String?
    let units: String
    let provider: String?
    let sourceTimeframe: String?
    let effectiveTimeframe: String?
    let finality: String
    let freshnessAgeSeconds: Double?
    let dataConfidence: Int?
    let analysisConfidence: Double?
    let decisionConfidence: Double?
    let calibrationStatus: String
    let context: [String: String]
    let decisionAuthority: Bool
}

struct QuantIndicatorSnapshot: Equatable {
    let ema20: [Double?]
    let bollingerUpper: [Double?]
    let bollingerMiddle: [Double?]
    let bollingerLower: [Double?]
    let rsi14: Double?
    let macd: Double?
    let macdSignal: Double?
    let macdHistogram: Double?
    let vwap: [Double?]
}

enum QuantIndicatorEngine {
    static func calculate(_ candles: [MarketCandle]) -> QuantIndicatorSnapshot {
        let closes = candles.map(\.close)
        let ema20 = emaSeries(closes, period: 20)
        let bands = bollinger(closes, period: 20, deviations: 2)
        let macdValues = macd(closes)
        return QuantIndicatorSnapshot(
            ema20: ema20,
            bollingerUpper: bands.upper,
            bollingerMiddle: bands.middle,
            bollingerLower: bands.lower,
            rsi14: rsi(closes, period: 14),
            macd: macdValues?.line,
            macdSignal: macdValues?.signal,
            macdHistogram: macdValues.map { $0.line - $0.signal },
            vwap: sessionVWAP(candles)
        )
    }

    static func emaSeries(_ values: [Double], period: Int) -> [Double?] {
        guard period > 0, let first = values.first else { return [] }
        let alpha = 2.0 / Double(period + 1)
        var current = first
        return values.enumerated().map { index, value in
            if index > 0 { current = alpha * value + (1 - alpha) * current }
            return index + 1 >= period ? current : nil
        }
    }

    static func rsi(_ values: [Double], period: Int) -> Double? {
        guard period > 0, values.count >= period + 1 else { return nil }
        var averageGain = max(values[1] - values[0], 0)
        var averageLoss = max(values[0] - values[1], 0)
        let alpha = 1.0 / Double(period)
        for index in 2..<values.count {
            let change = values[index] - values[index - 1]
            averageGain = alpha * max(change, 0) + (1 - alpha) * averageGain
            averageLoss = alpha * max(-change, 0) + (1 - alpha) * averageLoss
        }
        if averageLoss == 0 { return averageGain == 0 ? 50 : 100 }
        return 100 - 100 / (1 + averageGain / averageLoss)
    }

    static func bollinger(_ values: [Double], period: Int, deviations: Double)
        -> (upper: [Double?], middle: [Double?], lower: [Double?]) {
        guard period > 0 else { return ([], [], []) }
        var upper = Array<Double?>(repeating: nil, count: values.count)
        var middle = upper, lower = upper
        for end in (period - 1)..<values.count {
            let window = values[(end - period + 1)...end]
            let mean = window.reduce(0, +) / Double(period)
            let variance = window.reduce(0) { $0 + pow($1 - mean, 2) } / Double(period)
            let width = sqrt(variance) * deviations
            middle[end] = mean; upper[end] = mean + width; lower[end] = mean - width
        }
        return (upper, middle, lower)
    }

    static func macd(_ values: [Double]) -> (line: Double, signal: Double)? {
        guard values.count >= 35 else { return nil }
        let fast = emaRaw(values, period: 12), slow = emaRaw(values, period: 26)
        let line = zip(fast, slow).map(-)
        guard let signal = emaRaw(line, period: 9).last, let last = line.last else { return nil }
        return (last, signal)
    }

    private static func emaRaw(_ values: [Double], period: Int) -> [Double] {
        guard let first = values.first else { return [] }
        let alpha = 2.0 / Double(period + 1)
        var current = first
        return values.enumerated().map { index, value in
            if index > 0 { current = alpha * value + (1 - alpha) * current }
            return current
        }
    }

    static func sessionVWAP(_ candles: [MarketCandle]) -> [Double?] {
        guard !candles.isEmpty,
              candles.allSatisfy({ $0.finality == "closed" && $0.volumeKind == "traded_volume"
                  && $0.volume != nil && $0.sessionID != nil }),
              Set(candles.compactMap(\.sessionID)).count == 1
        else { return Array(repeating: nil, count: candles.count) }
        var weighted = 0.0, volume = 0.0
        return candles.map { candle in
            let amount = candle.volume ?? 0
            weighted += ((candle.high + candle.low + candle.close) / 3) * amount
            volume += amount
            return volume > 0 ? weighted / volume : nil
        }
    }
}
