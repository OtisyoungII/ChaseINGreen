import Foundation

/// Market Accessibility principle:
/// A trader should not need to have learned trading from the same teacher,
/// broker, market, or vocabulary to understand ChaseInGreen. Normalize
/// concepts internally and present familiar market-appropriate language.
enum MarketAccessibility {
    enum Market: String, CaseIterable {
        case general, equities, options, crypto, forex, futures
    }

    enum Concept: String, CaseIterable {
        case bullish, bearish, neutral, strengthening, weakening
        case breakout, pullback, continuation, rejection, support, resistance
        case long, short, bid, ask, spread, realizedPnL, unrealizedPnL
        case tick, point, contract, session, rth, eth, margin
        case notionalExposure, rollover, frontMonthContract
        case regularSession, extendedSession, preMarket, afterHours, overnightSession
        case sessionOpen, sessionClose, currentSession, priorSession
        case currentSessionHigh, currentSessionLow, priorSessionHigh, priorSessionLow
        case sessionRange, sessionTransition
    }

    static func term(_ concept: Concept, market: Market = .general) -> String {
        switch concept {
        case .bullish: return "Bullish"
        case .bearish: return "Bearish"
        case .neutral: return "Neutral"
        case .strengthening: return "Strengthening"
        case .weakening: return "Weakening"
        case .breakout: return "Breakout"
        case .pullback: return "Pullback"
        case .continuation: return "Continuation"
        case .rejection: return "Rejection"
        case .support: return "Support"
        case .resistance: return "Resistance"
        case .long: return "Long"
        case .short: return "Short"
        case .bid: return "Bid"
        case .ask: return "Ask"
        case .spread: return "Spread"
        case .realizedPnL: return "Realized P&L"
        case .unrealizedPnL: return "Unrealized P&L"
        case .tick: return market == .futures ? "Tick" : "Minimum Price Movement"
        case .point: return "Point"
        case .contract: return market == .futures ? "Futures Contract" : "Contract"
        case .session: return "Trading Session"
        case .rth: return "Regular Trading Hours (RTH)"
        case .eth: return "Extended Trading Hours (ETH)"
        case .margin: return "Margin"
        case .notionalExposure: return "Notional Exposure"
        case .rollover: return "Contract Rollover"
        case .frontMonthContract: return "Front-Month Contract"
        case .regularSession: return "Regular Session"
        case .extendedSession: return "Extended Session"
        case .preMarket: return "Pre-Market"
        case .afterHours: return "After-Hours"
        case .overnightSession: return "Overnight Session"
        case .sessionOpen: return "Session Open"
        case .sessionClose: return "Session Close"
        case .currentSession: return "Current Session"
        case .priorSession: return "Prior Session"
        case .currentSessionHigh: return "Current-Session High"
        case .currentSessionLow: return "Current-Session Low"
        case .priorSessionHigh: return "Prior-Session High"
        case .priorSessionLow: return "Prior-Session Low"
        case .sessionRange: return "Session Range"
        case .sessionTransition: return "Trading-Day / Session Transition"
        }
    }

    static func direction(_ raw: String?) -> String? {
        switch normalized(raw) {
        case "bullish", "bull", "up", "uptrend": return term(.bullish)
        case "bearish", "bear", "down", "downtrend": return term(.bearish)
        case "neutral", "mixed", "sideways", "range": return term(.neutral)
        default: return nil
        }
    }

    static func strength(_ raw: String?) -> String? {
        switch normalized(raw) {
        case "strong", "strengthening", "increasing": return "Strong"
        case "weak", "weakening", "decreasing": return "Weak"
        default: return nil
        }
    }

    static func descriptiveState(
        timeframe: String,
        direction: String?,
        strength: String?,
        finality: String?
    ) -> String {
        var parts = [MarketBarInterval.parse(timeframe).displayName]
        if let direction = Self.direction(direction) { parts.append(direction.uppercased()) }
        if let strength = Self.strength(strength) { parts.append(strength.uppercased()) }
        if normalized(finality) != "closed" { parts.append("CONFIRMATION PENDING CLOSE") }
        return parts.joined(separator: " · ")
    }

    private static func normalized(_ raw: String?) -> String {
        (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct MarketSessionMetadata: Equatable {
    let market: MarketAccessibility.Market?
    let venueIdentifier: String?
    let timezoneIdentifier: String?
    let sessionIdentifier: String?
    let sessionType: String?
    let sessionStart: Date?
    let sessionEnd: Date?
    let isContinuousTrading: Bool?
    let supportsExtendedHours: Bool?

    /// Session identity is supplied by the venue/data contract. Calendar dates
    /// never synthesize or advance it.
    func authoritativeSessionIdentifier(at date: Date) -> String? {
        guard let sessionIdentifier, !sessionIdentifier.isEmpty else { return nil }
        if let sessionStart, date < sessionStart { return nil }
        if let sessionEnd, date >= sessionEnd { return nil }
        return sessionIdentifier
    }
}

struct MarketSessionContext: Equatable {
    let calendarDate: Date
    let metadata: MarketSessionMetadata?

    var authoritativeSessionIdentifier: String? {
        metadata?.authoritativeSessionIdentifier(at: calendarDate)
    }
}

enum MarketSessionRelevance {
    static func concepts(
        for market: MarketAccessibility.Market,
        metadata: MarketSessionMetadata?
    ) -> Set<MarketAccessibility.Concept> {
        guard let metadata,
              metadata.sessionIdentifier != nil ||
              metadata.sessionType != nil ||
              metadata.sessionStart != nil ||
              metadata.sessionEnd != nil else {
            return []
        }
        if market == .crypto, metadata.isContinuousTrading == true {
            return []
        }

        var result: Set<MarketAccessibility.Concept> = [
            .session, .currentSession, .priorSession,
            .currentSessionHigh, .currentSessionLow,
            .priorSessionHigh, .priorSessionLow,
            .sessionRange, .sessionTransition
        ]

        switch market {
        case .equities:
            result.insert(.regularSession)
            if metadata.supportsExtendedHours == true {
                result.formUnion([.extendedSession, .preMarket, .afterHours])
            }
        case .futures:
            result.insert(.rth)
            if metadata.supportsExtendedHours == true {
                result.formUnion([.eth, .overnightSession])
            } else {
                addDeclaredSessionType(metadata.sessionType, to: &result)
            }
        case .crypto:
            break
        case .forex, .options, .general:
            addDeclaredSessionType(metadata.sessionType, to: &result)
        }

        if metadata.sessionStart != nil { result.insert(.sessionOpen) }
        if metadata.sessionEnd != nil { result.insert(.sessionClose) }
        return result
    }

    private static func addDeclaredSessionType(
        _ raw: String?,
        to concepts: inout Set<MarketAccessibility.Concept>
    ) {
        switch raw?.lowercased() {
        case "regular", "rth": concepts.insert(.regularSession)
        case "extended", "eth": concepts.insert(.extendedSession)
        case "pre_market", "premarket": concepts.insert(.preMarket)
        case "after_hours": concepts.insert(.afterHours)
        case "overnight": concepts.insert(.overnightSession)
        default: break
        }
    }
}

enum SessionLevelReference: String, Equatable {
    case currentSessionHigh
    case currentSessionLow
    case priorSessionHigh
    case priorSessionLow
}

enum SessionLevelRelationship: String, Equatable {
    case established
    case remainsBelow
    case remainsAbove
    case taken
    case remainsIntact
}

struct SessionLevelObservation: Equatable {
    let reference: SessionLevelReference
    let relationship: SessionLevelRelationship
    let price: Double?
    let sessionIdentifier: String
}

enum PositionSessionEvent: Equatable {
    case regularSessionEndedWhilePositionOpen
    case extendedTradingContinued
    case overnightReversalReducedUnrealizedProfit

    var customerDescription: String {
        switch self {
        case .regularSessionEndedWhilePositionOpen:
            return "The regular session ended while the position remained open."
        case .extendedTradingContinued:
            return "Price continued moving during extended trading."
        case .overnightReversalReducedUnrealizedProfit:
            return "An overnight reversal reduced unrealized profit."
        }
    }
}

struct MarketBarInterval: Equatable {
    enum Basis: Equatable {
        case time(seconds: TimeInterval)
        case ticks(count: Int)
        case unsupported
    }

    let rawValue: String
    let basis: Basis
    let displayName: String

    static func parse(_ raw: String) -> MarketBarInterval {
        let clean = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let timeAliases: [String: (TimeInterval, String)] = [
            "1m": (60, "1m"), "m1": (60, "1m"),
            "2m": (120, "2m"), "m2": (120, "2m"),
            "3m": (180, "3m"), "m3": (180, "3m"),
            "5m": (300, "5m"), "m5": (300, "5m"),
            "15m": (900, "15m"), "m15": (900, "15m"),
            "30m": (1_800, "30m"), "m30": (1_800, "30m"),
            "45m": (2_700, "45m"), "m45": (2_700, "45m"),
            "1h": (3_600, "1H"), "h1": (3_600, "1H"), "60m": (3_600, "1H"),
            "2h": (7_200, "2H"), "h2": (7_200, "2H"), "120m": (7_200, "2H"),
            "3h": (10_800, "3H"), "h3": (10_800, "3H"), "180m": (10_800, "3H"),
            "4h": (14_400, "4H"), "h4": (14_400, "4H"), "240m": (14_400, "4H"),
            "1d": (86_400, "1D"), "d1": (86_400, "1D"), "24h": (86_400, "1D")
        ]
        if let (seconds, name) = timeAliases[clean] {
            return MarketBarInterval(rawValue: raw, basis: .time(seconds: seconds), displayName: name)
        }

        let compact = clean.replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        for suffix in ["ticks", "tick", "t"] where compact.hasSuffix(suffix) {
            let countText = String(compact.dropLast(suffix.count))
            if let count = Int(countText), count > 0 {
                return MarketBarInterval(
                    rawValue: raw,
                    basis: .ticks(count: count),
                    displayName: "\(count)-tick"
                )
            }
        }
        return MarketBarInterval(rawValue: raw, basis: .unsupported, displayName: raw.uppercased())
    }

    var activityDescription: String? {
        guard case .ticks(let count) = basis else { return nil }
        return "Closes after \(count.formatted()) qualifying ticks"
    }
}

struct FuturesInstrumentMetadata: Equatable {
    let minimumTickPoints: Double?
    let tickValue: Double?
    let contractMultiplier: Double?
    let initialMargin: Double?

    func pointTickConversion(points: Double) -> String? {
        guard points.isFinite, points >= 0,
              let minimumTickPoints,
              minimumTickPoints.isFinite, minimumTickPoints > 0 else {
            return nil
        }
        let ticks = points / minimumTickPoints
        return "\(Self.number(points)) points = \(Self.number(ticks)) ticks"
    }

    private static func number(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value)) }
        return String(format: "%.4f", value).replacingOccurrences(
            of: #"\.?0+$"#,
            with: "",
            options: .regularExpression
        )
    }
}
