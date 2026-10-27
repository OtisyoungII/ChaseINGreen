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
    var id: String { instrument.canonicalId }
    var displayReasons: [String] { Array(reasons.prefix(4)).map(Self.reasonLabel) }
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
    let status: String
    let generation: ScreenerGeneration?
    static func decode(_ data: Data) throws -> Self {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Self.self, from: data)
    }
}
