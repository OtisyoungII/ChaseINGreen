import Foundation

struct TraderIdentity: Decodable, Equatable {
    let broker, connection_id: String
    let canonical_account_id, native_account_id, instrument_id, symbol, exchange, currency: String?
}
struct TraderAccountTruth: Decodable {
    let identity: TraderIdentity
    let freshness: String
    let received_at: String
    let balance, equity: Double?
}
struct TraderPositionTruth: Decodable, Identifiable {
    var id: String { position_id ?? identity.instrument_id ?? "UNKNOWN" }
    let position_id: String?
    let identity: TraderIdentity
    let side, origin, freshness: String
    let quantity, average_entry, current_price, unrealized_pnl, realized_pnl: Double?
}
struct TraderProtectionTruth: Decodable {
    let identity: TraderIdentity
    let protection_state: String
    let stop_price, coverage_percent: Double?
}
struct TraderSnapshot: Decodable {
    let account: TraderAccountTruth
    let positions: [TraderPositionTruth]
    let protection: [TraderProtectionTruth]
}
struct TraderObservation: Decodable, Identifiable {
    let id, session_id, recorded_at: String
    let control_state: String?
    let snapshot: TraderSnapshot
    let events: [TraderRecordedEvent]
    let live_transport, execution_enabled: Bool
}
struct TraderObservations: Decodable { let observations: [TraderObservation]; let live_transport: Bool }

struct TraderChartEvent: Identifiable, Equatable {
    enum Kind: String { case price, entry, add, averageEntry, stop, partial, exit, decision }
    let id, sessionID, instrumentID: String
    let kind: Kind
    let at: Date
    let value: Double?
    let evidenceReference: String
}
struct TraderChartBuffer {
    let sessionID, instrumentID: String
    private(set) var events: [TraderChartEvent] = []
    static let capacity = 256
    mutating func accept(_ event: TraderChartEvent) -> Bool {
        guard event.sessionID == sessionID, event.instrumentID == instrumentID,
              !event.evidenceReference.isEmpty, !events.contains(where: { $0.id == event.id }),
              event.value?.isFinite != false,
              events.last.map({ event.at >= $0.at }) ?? true else { return false }
        events.append(event)
        if events.count > Self.capacity { events.removeFirst(events.count - Self.capacity) }
        return true
    }
}

struct TraderRecordedEvent: Decodable, Identifiable {
    var id: String { event_id }
    let event_id, session_id, event_type, event_at, received_at, freshness: String
    let evidence_references: [String]
}
