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

/// An aggregate cannot acquire freshness by adding retained account values.
enum AccountEquityPresentation {
    struct Evidence {
        let value: Double?
        let fresh: Bool
        let currency: String?
        var capitalScope: String = "unknown"
    }
    static func aggregate(_ evidence: [Evidence]) -> (title: String, value: Double?) {
        guard !evidence.isEmpty else { return ("Account equity unavailable", nil) }
        let scopes = Set(evidence.map(\.capitalScope))
        if scopes.count > 1 { return ("Separate capital types · no combined total", nil) }
        let freshCount = evidence.filter(\.fresh).count
        guard freshCount == 0 || freshCount == evidence.count else {
            return ("Mixed freshness · total unavailable", nil)
        }
        let title = freshCount == 0 ? "Last-known equity" : "Current snapshot equity"
        let currencies = Set(evidence.compactMap { $0.currency?.uppercased() })
        guard currencies.count == 1, evidence.allSatisfy({ $0.currency?.isEmpty == false }),
              evidence.allSatisfy({ $0.value?.isFinite == true }) else { return (title, nil) }
        return (title, evidence.compactMap(\.value).reduce(0, +))
    }
    static func accountLabel(name: String?, number: String?, classification: String?) -> String {
        let suffix = ManualAccountIdentityPolicy.lastFour(number).map { "…\($0)" }
        return [name, suffix, classification].compactMap { value in
            guard let value, !value.isEmpty else { return nil }; return value
        }.joined(separator: " · ")
    }
}

/// Facets describe supplied metadata; they never confer trading authorization.
enum AccountWorkspaceClassification {
    static let categories = ["All", "Active", "Funded", "Challenge", "Competition", "Personal", "Business", "Retirement", "Disconnected", "Historical"]
    static func historical(status: String?, active: Bool, participation: String?) -> Bool {
        !active || participation == "ignored" || ["archived", "blocked", "breached", "closed", "disabled", "failed", "inactive", "passed", "expired", "deleted", "revoked", "terminated", "violated"].contains(status?.lowercased() ?? "")
    }
    static func matches(_ category: String, status: String?, active: Bool, participation: String?, type: String?, ownership: String?, funding: String?, connection: String?) -> Bool {
        let history = historical(status: status, active: active, participation: participation)
        let kind = type?.lowercased() ?? ""
        switch category {
        case "All": return true
        case "Historical": return history
        case "Active": return !history && status?.lowercased() == "active"
        case "Funded": return !history && (funding?.lowercased() == "funded" || kind == "funded")
        case "Challenge": return !history && ["challenge", "evaluation"].contains(kind)
        case "Competition": return !history && kind == "competition"
        case "Personal": return !history && ownership?.lowercased() == "personal"
        case "Business": return !history && ownership?.lowercased() == "business"
        case "Retirement": return !history && ["ira", "roth", "roth ira", "retirement"].contains(kind)
        case "Disconnected": return ["disconnected", "revoked", "reauth_required"].contains(connection?.lowercased() ?? "")
        default: return false
        }
    }
}
