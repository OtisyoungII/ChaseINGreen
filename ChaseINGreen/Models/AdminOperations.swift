import Foundation

struct OperationsMetric: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let value: Double?
    let state: String
    let observed_at: String?
    let unit: String?
    var formatted: String {
        guard let value, value.isFinite else { return state == "NOT CONFIGURED" ? state : "UNKNOWN" }
        return value.formatted(.number.precision(.fractionLength(0...8)))
    }
}
struct OperationsHolding: Decodable, Identifiable {
    let native_account, conid, side, provider_at, received_at, currency: String?
    let average_cost, provider_mark, unrealized_pnl: Double?
    var id: String { [native_account ?? "", conid ?? symbol].joined(separator: ":") }
    let symbol: String
    let quantity: Double?
    let state: String
    let observed_at: String?
    let protection: String
}
struct OperationsAccount: Decodable, Identifiable {
    let currency, provider_at, received_at: String?
    let id, label, provider, ownership, connection_suffix, status, connection_status, authentication: String
    let native_account, canonical_account, last_sync, observed_at: String?
    let last_seen, account_type, customer_type, qualification, positions_status, executions_status: String?
    let active, visible: Bool?
    let binding_verified: Bool
    let metrics, asset_balances, risk: [OperationsMetric]
    let holdings: [OperationsHolding]
    let orders_status, protection, restrictions, eligibility, reason: String
}
struct OperationsWatch: Decodable, Identifiable {
    let id, label, group, canonical_instrument: String
    var enabled: Bool
    var priority: Int
    let catalog_symbol, market_symbol, execution_symbol, provider, provider_symbol, observed_at, next_observation, market_id: String?
    let last_attempt, last_success, last_failure, failure_category: String?
    let support, status, reason: String
    let observation_eligible, trading_eligible: Bool
}
struct OperationsMarket: Decodable, Identifiable {
    let id, label, symbol, provider, provider_symbol, status, direction, setup, note: String
    let execution_symbol, observed_at, evaluated_at: String?
    let attempt: OperationsAttempt?
    let configured, observed: Bool
    let attempted: Bool?
    let rank: Int?
    let score, price, last_known_price: Double?
    let reasons: [String]
    let metrics: [OperationsMetric]
}
struct OperationsScanner: Decodable {
    let status: String
    let configured, observed, stale, ranked: Int
    let attempted, failed: Int?
    let last_cycle, generation_id: String?
    let acquisition_failed: Bool
    let attempt_note: String
    let rows: [OperationsMarket]
}
struct OperationsPlan: Decodable {
    let side: String
    let expires_at: String?
    let metrics: [OperationsMetric]
}
struct OperationsStep: Decodable {
    let kind: String
    let reasons: [String]
    let observed_at: String?
    let metrics: [OperationsMetric]
}
struct OperationsEvent: Decodable, Identifiable {
    let id, at, type, source, instrument, new_state: String
    let account_id, timeframe, previous_state: String?
    let reasons: [String]
    let steps: [OperationsStep]
    let simulated: Bool
    let plan: OperationsPlan?
}
struct OperationsFeed: Decodable {
    let events: [OperationsEvent]
    let next_cursor: String?
    let note: String
}
struct AdminOperationsSnapshot: Decodable {
    let observation: OperationsObservation?
    let generated_at, mode, blocker: String
    let heartbeat, last_observation_cycle, last_decision: String?
    let refresh_seconds: Int
    let trading_enabled: Bool
    let revision: Int
    let accounts: [OperationsAccount]
    let watch: [OperationsWatch]
    let scanner: OperationsScanner
    let feed: OperationsFeed
    let risk_status, recovery, timing_gate: String
}

enum OperationsPresentation {
    static let refreshSeconds = 30
    static func date(_ text: String?) -> Date? {
        guard let text else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return parser.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
    static func currentSnapshot(_ timestamp: String, now: Date = Date()) -> Bool {
        guard let at = date(timestamp) else { return false }
        return (0...Double(refreshSeconds + 5)).contains(now.timeIntervalSince(at))
    }
    static func age(_ timestamp: String?, now: Date = Date()) -> String {
        guard let at = date(timestamp), now >= at else { return "UNKNOWN" }
        return "\(Int(now.timeIntervalSince(at)))s"
    }
    static func ranking(_ row: OperationsMarket, snapshotTime: String, now: Date = Date()) -> String {
        let fresh = currentSnapshot(snapshotTime, now: now)
        let rank = fresh ? row.rank.map(String.init) ?? "—" : "—"
        let score = fresh ? row.score.map { String(format: "%.2f", $0) } ?? "—" : "—"
        return "\(permittedStatus(row.status, snapshotTime: snapshotTime, now: now)) · Rank \(rank) · Score \(score)"
    }
    static func permittedStatus(_ status: String, snapshotTime: String, now: Date = Date()) -> String {
        ["LIVE", "AVAILABLE", "FRESH", "SUCCESS", "VERIFIED"].contains(status) && !currentSnapshot(snapshotTime, now: now) ? "STALE" : status
    }
}

struct OperationsObservationState: Decodable {
    let direction: String?
    let ema_slope, ema_separation, directional_efficiency, range_expansion_ratio, normalized_range_span: Double?
    let compressed, choppy: Bool?
}
struct OperationsTimeframe: Decodable, Identifiable {
    var id: String { timeframe }
    let timeframe, role, status: String
    let observed_at, reason: String?
    let bar_count: Int
    let state: OperationsObservationState?
}
struct OperationsObservationRow: Decodable, Identifiable {
    var id: String { instrument }
    let instrument, cycle_id, last_attempt, result: String
    let provider, provider_symbol, observed_at, last_success, last_failure, last_failure_category, frame_failure: String?
    let price, volume, latency_ms: Double?
    let timeframes: [OperationsTimeframe]
}
struct OperationsObservationEvent: Decodable, Identifiable {
    let id, at, type, source, cycle_id: String
    let sequence: Int
    let instrument, result: String?
}
struct OperationsObservation: Decodable {
    let mode, epoch, retention_note: String
    let scheduler_heartbeat, cycle_started, cycle_completed, last_success, next_cycle, cycle_id, reason: String?
    let duration_seconds: Double?
    let requests, concurrency, event_retention: Int
    let source_registry: [OperationsSourceRegistry]?
    let rows: [OperationsObservationRow]
    let events: [OperationsObservationEvent]
    let trading_enabled: Bool
}
struct OperationsAttempt: Decodable {
    let attempt_at, cycle_id, result: String
    let observed_at: String?
    let latency_ms: Double?
}


struct OperationsSourceBinding: Decodable, Identifiable {
    var id: String { provider }
    let provider, role, classification, access_state, quote_basis: String
    let native_symbol, contract_identity: String?
    let supported_timeframes, derived_timeframes: [String]
    let observation_eligible, trading_eligible: Bool
}
struct OperationsSourceQuality: Decodable {
    let request_start, receipt_timestamp, provider_timestamp, quote_timestamp, trade_timestamp: String?
    let freshness_class, candle_timestamp, candle_finality, timeframe_provenance, failure_state, fallback_reason: String?
    let quote_age, trade_age, request_latency_ms, bid, ask, spread, last: Double?
}
struct OperationsSourceRegistry: Decodable, Identifiable {
    var id: String { canonical }
    let canonical, coverage, match_access, source_epoch: String
    let active_provider, last_success: String?
    let sources: [OperationsSourceBinding]
    let quality: OperationsSourceQuality
    let trading_eligible: Bool
}

struct BrokerOperationsEvidence: Decodable {
    let events: [BrokerOperationsEvent]
    let cursor: [String]?
    let more: Bool
    let controls: [BrokerOperationsControl]
    let note: String
}
struct BrokerOperationsControl: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let enabled: Bool
    let reason: String
}
struct BrokerOperationsEvent: Decodable, Identifiable {
    let id, broker, account, connection, event_type, freshness, symbol: String
    let observed_at, received_at: String?
    let quantity, price: Double?
    let origin, protection: String
    let warnings: [String]
    let execution_enabled: Bool
}
