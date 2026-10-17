import Foundation

/// Provider observation facts. Decoding or foregrounding never renews the clock.
struct AcceptedValuation: Codable, Equatable, Hashable {
    var version: Int?
    var valuationId: String?
    var instrument: String?
    var price: Double?
    var provider: String?
    var observedAt: String?
    var receivedAt: String?
    var freshness: String?
    var observationKind: String?
    var forcedStale: Bool?
    var availability: String?
    var maxAgeSeconds: Double?
    var netPnl: Double?
    var grossPnl: Double?
    var fallbackUsed: Bool?
    var peakNetPnl: Double?
    var reason: String?

    enum CodingKeys: String, CodingKey {
        case version, instrument, price, provider, freshness, availability, reason
        case valuationId = "valuation_id", observedAt = "observed_at", receivedAt = "received_at"
        case fallbackUsed = "fallback_used"
        case peakNetPnl = "peak_net_pnl"
        case observationKind = "observation_kind", forcedStale = "forced_stale"
        case maxAgeSeconds = "max_age_seconds", netPnl = "net_pnl", grossPnl = "gross_pnl"
    }

    private func date(_ value: String?) -> Date? {
        guard let observedAt = value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: observedAt) ?? ISO8601DateFormatter().date(from: observedAt)
    }

    var observationDate: Date? { date(observedAt) }

    func state(at now: Date = Date()) -> String {
        guard let price, price.isFinite, price > 0 else { return "unavailable" }
        guard instrument?.isEmpty == false, ["yahoo", "kraken", "ibkr", "aqua", "match_trader"].contains(provider ?? ""),
              reason != "instrument_mismatch", reason != "position_changed", let observed = observationDate else { return "unknown" }
        let age = now.timeIntervalSince(observed)
        guard age >= 0, let receipt = date(receivedAt), receipt >= observed, receipt <= now else { return "unknown" }
        if forcedStale == true || availability == "provider_unavailable"
            || observationKind == "daily_bar" || observationKind == "historical_close"
            || age > min(maxAgeSeconds ?? 120, 120) { return "stale" }
        return "fresh"
    }

    func label(at now: Date = Date(), offline: Bool = false) -> String {
        let time = observationDate?.formatted(date: .abbreviated, time: .standard) ?? "observation time unknown"
        if offline { return "Offline — showing last known value • \(time)" }
        if availability == "provider_unavailable" { return "Provider temporarily unavailable — last known value • \(time)" }
        let source = (fallbackUsed == true ? "Fallback • " : "") + (provider ?? "Market")
        switch state(at: now) {
        case "fresh": return "\(source) • observed \(time)"
        case "stale": return "\(source) • Stale — last updated \(time)"
        default: return "Current market observation unavailable • \(time)"
        }
    }

    func manualExitPrice(at now: Date = Date()) -> Double? {
        state(at: now) == "fresh" ? price : nil
    }

    static func groupPrice(_ values: [AcceptedValuation]) -> Double? {
        guard let first = values.first, let instrument = first.instrument,
              values.allSatisfy({ $0.instrument == instrument && $0.price == first.price }) else { return nil }
        return first.price
    }
}

enum ValuationAvailability: String, Codable {
    case loading, entitlement, stale, offline
    case manualField = "manual_field"
    case unsupportedField = "unsupported_field"
    case missingObservation = "missing_observation"
    case providerUnavailable = "provider_unavailable"
    case missingInput = "missing_input"
    case notApplicable = "not_applicable"
    case retryableUnknown = "retryable_unknown"
    static func failure(_ error: Error) -> ValuationAvailability {
        let error = error as NSError
        if error.domain == NSURLErrorDomain && [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost].contains(error.code) { return .offline }
        if let state = error.userInfo["availability_state"] as? String,
           let known = ValuationAvailability(rawValue: state) { return known }
        if (500...599).contains(error.code) { return .providerUnavailable }
        return .retryableUnknown
    }

    var label: String {
        switch self {
        case .loading: return "Loading"
        case .entitlement: return "Gold feature — upgrade to enable monitoring"
        case .manualField: return "Manual account — broker field unavailable"
        case .unsupportedField: return "Broker does not provide this field"
        case .missingObservation: return "Current market observation unavailable"
        case .stale: return "Stale — last known valuation"
        case .offline: return "Offline — showing last known value"
        case .providerUnavailable: return "Provider temporarily unavailable — showing last known value"
        case .missingInput: return "Missing user input"
        case .notApplicable: return "Not applicable"
        case .retryableUnknown: return "Could not refresh — try again"
        }
    }
}
