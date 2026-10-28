import Foundation

struct ScreenerInstrument: Decodable, Hashable, Sendable {
    let canonicalId: String
    let symbol: String
    let name: String
    let assetClass: String
    let instrumentType: String
    let provider: String
    let providerSymbol: String
    let venue: String?
    let currency: String
    let contractIdentity: String?
    let identityNote: String?

    // Explicit provider symbols, never display aliases such as NAS100/US30.
    var navigationSymbol: String { provider == "kraken" ? symbol : providerSymbol }
    var supportedNavigation: Bool {
        ["yahoo", "kraken"].contains(provider) && !navigationSymbol.isEmpty && !canonicalId.isEmpty
    }
}

struct ScreenerCandidate: Decodable, Identifiable, Sendable {
    let instrument: ScreenerInstrument
    let rank: Int?
    let score: Double?
    let direction: String
    let state: String
    let reasons: [String]
    let freshness: String
    let executionAuthority: Bool
    let relativePerformance: ScreenerRelativePerformance?
    let activity: ScreenerActivityEvidence?
    let recovery: ScreenerRecoveryEvidence?
    var id: String { instrument.canonicalId }
    var displayReasons: [String] { displayReasons(stale: false) }
    func displayReasons(stale: Bool) -> [String] {
        let technical = reasons.map(Self.reasonLabel)
        let riskCodes = Set(["DATA_STALE", "DATA_UNAVAILABLE", "BREAK_FAILED", "EXTENDED_FROM_STRUCTURE"])
        var risk = reasons.filter { riskCodes.contains($0) }.map(Self.reasonLabel)
        let remaining = reasons.filter { !riskCodes.contains($0) }.map(Self.reasonLabel)
        var discovery: [String] = []
        if let recovery, let warning = recovery.warning(stale: stale) { risk.append(warning) }
        if let recovery, let reason = recovery.reasonLabel(stale: stale) { discovery.append(reason) }
        if let activity, let reason = activity.reasonLabel(stale: stale) { discovery.append(reason) }
        if let relativePerformance { discovery.append(relativePerformance.reasonLabel(stale: stale)) }
        if activity == nil && recovery == nil && relativePerformance == nil { return Array(technical.prefix(4)) }
        var seen = Set<String>()
        return Array((risk + discovery + remaining).filter { seen.insert($0).inserted }.prefix(4))
    }
    static func reasonLabel(_ code: String) -> String {
        switch code {
        case "LONG_MOMENTUM": "Bullish momentum"
        case "SHORT_MOMENTUM": "Bearish momentum"
        case "LONG_STRUCTURE": "Bullish range structure"
        case "SHORT_STRUCTURE": "Bearish range structure"
        case "BREAKOUT_CONFIRMED": "Closed-candle breakout"
        case "BREAKDOWN_CONFIRMED": "Closed-candle breakdown"
        case "BREAK_FAILED": "Price returned inside broken structure"
        case "EXTENDED_FROM_STRUCTURE": "Extended from structure"
        case "DATA_STALE": "Market evidence is stale"
        case "DATA_UNAVAILABLE": "Market evidence unavailable"
        case "DIRECTION_MIXED": "Directional evidence mixed"
        case "INSUFFICIENT_CLOSED_EVIDENCE": "Insufficient closed-candle evidence"
        default: "Additional evidence unavailable"
        }
    }
}

struct ScreenerGeneration: Decodable, Sendable {
    let generationId: String
    let universeId: String
    let scoringPolicy: String
    let evaluatedAt: String
    let observedAt: String?
    let expiresAt: String
    let status: String
    let universeCount: Int
    let observedCount: Int
    let rankedCount: Int
    let candidates: [ScreenerCandidate]
    func isExpired(at date: Date = Date()) -> Bool {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fractional = parser.date(from: expiresAt)
        parser.formatOptions = [.withInternetDateTime]
        guard let expiry = fractional ?? parser.date(from: expiresAt) else { return true }
        return status == "stale" || date >= expiry
    }
    func filtered(asset: String, direction: String) -> [ScreenerCandidate] {
        candidates.filter { (asset == "ALL" || $0.instrument.assetClass == asset)
            && (direction == "BOTH" || $0.direction == direction) }
    }
}

struct ScreenerResponse: Decodable, Sendable {
    let availability: String?
    let status: String
    let generation: ScreenerGeneration?
    static func decode(_ data: Data) throws -> Self {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Self.self, from: data)
    }
}


// Optional additive contract; old Phase 1 responses continue decoding unchanged.
struct ScreenerReturnWindow: Decodable, Sendable {
    let instrument: ScreenerInstrument
    let sessionPolicy: String
    let sessionId: String
    let sessionStart: String
    let sessionEnd: String
    let startAt: String
    let endAt: String
    let startPrice: Double
    let endPrice: Double
    let observedAt: String
    let retrievedAt: String
    let informationAvailableAt: String
    let expiresAt: String
    let source: String
    let sampleCount: Int
    let expectedCount: Int
    let limitations: [String]
}

struct ScreenerRelativePerformance: Decodable, Sendable {
    let schemaVersion: String
    let benchmarkPolicyVersion: String
    let calculationVersion: String
    let status: String
    let reason: String
    let benchmark: ScreenerInstrument?
    let instrumentWindow: ScreenerReturnWindow?
    let benchmarkWindow: ScreenerReturnWindow?
    let instrumentReturnPct: Double?
    let benchmarkReturnPct: Double?
    let relativeReturnPercentagePoints: Double?
    let interpretation: String?
    let alignmentToleranceSeconds: Int
    let neutralTolerancePercentagePoints: Double
    let informationAvailableAt: String?
    let expiresAt: String?
    let coverage: String
    let limitations: [String]

    func reasonLabel(stale: Bool) -> String {
        if stale || status == "STALE" { return "Relative performance is stale" }
        if status == "NOT_APPLICABLE" { return "No comparison benchmark defined" }
        guard schemaVersion == "relative-performance-v1", status == "AVAILABLE", coverage == "complete",
              let benchmark, let value = relativeReturnPercentagePoints, value.isFinite,
              let window = instrumentWindow, let other = benchmarkWindow,
              window.startAt == other.startAt, window.endAt == other.endAt,
              window.sessionPolicy == other.sessionPolicy else {
            return "Relative performance unavailable"
        }
        let basis: String
        switch window.sessionPolicy {
        case "us-regular-first-15m-close-v1": basis = "since first regular 15m close"
        case "crypto-utc-rolling-60m-closed-15m-v1": basis = "over closed 60m · UTC"
        default: return "Relative performance unavailable"
        }
        let name = benchmark.providerSymbol == "^GSPC" ? "S&P 500" : benchmark.symbol
        let amount = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), abs(value))
        switch interpretation {
        case "OUTPERFORMING" where value > neutralTolerancePercentagePoints:
            return "Outperforming \(name) by \(amount)pp \(basis)"
        case "UNDERPERFORMING" where value < -neutralTolerancePercentagePoints:
            return "Underperforming \(name) by \(amount)pp \(basis)"
        case "NEUTRAL" where abs(value) <= neutralTolerancePercentagePoints + 1e-12:
            return "Tracking \(name) within 0.05pp \(basis)"
        default: return "Relative performance unavailable"
        }
    }
}


struct ScreenerActivityEvidence: Decodable, Sendable {
    let instrument: ScreenerInstrument
    let calculationVersion: String
    let status: String
    let reason: String
    let sessionPolicy: String?
    let volumeUnit: String?
    let source: String?
    let sampleCount: Int
    let expectedSampleCount: Int
    let currentCumulativeVolume: Double?
    let historicalMedianCumulativeVolume: Double?
    let rvol: Double?
    let participation: String?
    let cutoffAt: String?
    let observedAt: String?
    let retrievedAt: String?
    let informationAvailableAt: String?
    let expiresAt: String?
    let coverage: String
    let liquidityStatus: String
    let limitations: [String]

    func reasonLabel(stale: Bool) -> String? {
        guard !stale, calculationVersion == "same-cutoff-median-volume-v1", status == "AVAILABLE",
              coverage == "complete", sampleCount == 20, expectedSampleCount == 20,
              let rvol, rvol.isFinite, rvol >= 0 else { return nil }
        let value = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), rvol)
        switch sessionPolicy {
        case "us-provider-regular-15m-volume-v1": return "Volume \(value)× same-time median · regular session"
        case "kraken-UTC-day-closed-60m-volume-v1": return "Kraken volume \(value)× same-time median · closed UTC hour"
        default: return nil
        }
    }
}

struct ScreenerRecoveryEvidence: Decodable, Sendable {
    let instrument: ScreenerInstrument
    let calculationVersion: String
    let status: String
    let reason: String
    let state: String?
    let qualifies: Bool
    let drawdownLookback: Int
    let minimumObservations: Int
    let baseLookback: Int
    let emaPeriod: Int
    let drawdownThresholdPct: Double
    let observedAt: String?
    let retrievedAt: String?
    let informationAvailableAt: String?
    let expiresAt: String?
    let source: String?
    let baseOriginAt: String?
    let priorDrawdownPct: Double?
    let supportLevel: Double?
    let invalidationLevel: Double?
    let reclaimLevel: Double?
    let emaValue: Double?
    let higherLow: Bool
    let failedBreakdown: Bool
    let momentumImproving: Bool
    let relativeTurn: Bool
    let participationElevated: Bool
    let limitations: [String]

    func warning(stale: Bool) -> String? {
        if stale || status == "STALE" { return "Recovery evidence is stale" }
        guard status == "AVAILABLE", calculationVersion == "closed-daily-recovery-v1" else { return nil }
        if reason == "CURRENT_PRICE_BELOW_INVALIDATION" { return "Recovery paused · current price below support" }
        if reason == "CURRENT_PRICE_EXTENDED" { return "Recovery extended at current price" }
        if state == "INVALIDATED" { return "Recovery invalidated · defining structure failed" }
        if state == "EXTENDED" { return "Recovery extended · not an early recovery candidate" }
        return nil
    }
    func reasonLabel(stale: Bool) -> String? {
        guard !stale, status == "AVAILABLE", calculationVersion == "closed-daily-recovery-v1", qualifies else { return nil }
        switch state {
        case "RECLAIMING": return "Recovery reclaim confirmed on closed daily bar"
        case "RECOVERING": return "Recovery structure improving · closed daily evidence"
        default: return nil
        }
    }
}
