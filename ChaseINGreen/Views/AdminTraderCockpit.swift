import SwiftUI

/// Presentation and audit intents only. No provider client or trading authority.
struct AdminTraderCockpit: View {
    let accessToken: String
    @State private var observations: [TraderObservation] = []
    @State private var selectedID: String?
    @State private var selectedInstrument: String?
    @State private var busy = false
    @State private var message: String?
    @State private var pendingIntent: String?
    private let intents = ["AUTO_OFF_REQUESTED", "AUTO_EXIT_REQUESTED", "MANUAL_TAKEOVER_REQUESTED", "REDUCE_REQUESTED", "PARTIAL_REQUESTED", "DISABLE_ADDS_REQUESTED", "TIGHTEN_PROTECTION_REQUESTED"]
    private var selected: TraderObservation? { observations.first { $0.id == selectedID } }
    private func value(_ n: Double?) -> String { n.map { String($0) } ?? "UNKNOWN" }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AUTO TRADER COCKPIT — OBSERVATION ONLY").font(.headline)
            Button("Read durable trade observations") {
                Task {
                    busy = true
                    defer { busy = false }
                    do {
                        observations = try await APIService.shared.fetchTraderObservations(accessToken: accessToken).observations
                        if !observations.contains(where: { $0.id == selectedID }) { selectedID = observations.first?.id; selectedInstrument = nil }
                        message = observations.isEmpty ? "No durable normalized observations available." : nil
                    } catch { message = "Observation unavailable. No broker action performed." }
                }
            }.disabled(busy)
            if let message { Text(message).font(.caption).foregroundStyle(.orange) }
            ForEach(observations) { observation in
                Button("\(observation.snapshot.account.identity.broker) · \(observation.snapshot.account.identity.native_account_id ?? "UNKNOWN ACCOUNT") · \(observation.recorded_at)") {
                    selectedID = observation.id; selectedInstrument = nil
                }.font(.caption)
            }
            if let s = selected {
                Text("Broker: \(s.snapshot.account.identity.broker) · Mode: OBSERVE / EXECUTION LOCKED")
                Text("Account: \(s.snapshot.account.identity.canonical_account_id ?? "UNKNOWN")")
                Text("Audit control state at observation: \(s.control_state ?? "UNKNOWN")")
                Text("Broker evidence at receipt: \(s.snapshot.account.freshness) · \(s.snapshot.account.received_at)")
                Text("Market data freshness: UNKNOWN · Live transport: NOT CONNECTED")
                ForEach(s.snapshot.positions) { position in
                    Button("\(position.identity.symbol ?? "UNKNOWN") · \(position.side)") { selectedInstrument = position.id }
                }
                if let p = s.snapshot.positions.first(where: { $0.id == selectedInstrument }) {
                    Text("\(p.side) · \(p.origin) · \(p.identity.instrument_id ?? "UNKNOWN")")
                    Text("Quantity: \(value(p.quantity)) · Average entry: \(value(p.average_entry))")
                    Text("Recorded price: \(value(p.current_price)) · Unrealized: \(value(p.unrealized_pnl)) · Realized: \(value(p.realized_pnl))")
                    Text("Risk: UNKNOWN · Protection at receipt: \(s.snapshot.protection.first(where: { $0.identity.instrument_id == p.identity.instrument_id })?.protection_state ?? "UNKNOWN")")
                }
                Text("Historical evidence does not establish current account health or current protection.").font(.caption)
                VStack {
                    Image(systemName: "chart.xyaxis.line").font(.largeTitle)
                    Text("LIVE DATA NOT AVAILABLE").bold()
                    Text("Chart awaits qualified price events. Entry/add/stop/partial/exit markers require their own evidence.").font(.caption)
                }.frame(maxWidth: .infinity, minHeight: 150).background(.secondary.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
                Text("DURABLE DECISION / BROKER EVENT FEED").font(.caption.bold())
                ForEach(s.events.prefix(100)) { event in
                    Text("\(event.event_at) · \(event.event_type) · \(event.freshness)").font(.caption)
                }
                Text("AUDIT INTENTS ONLY — no order or protection request will be sent").font(.caption.bold())
                ForEach(intents, id: \.self) { intent in
                    Button("Record " + intent.replacingOccurrences(of: "_", with: " ")) { pendingIntent = intent }.disabled(busy)
                }
                Text("AUTO OFF prevents new risk in the control model. AUTO EXIT is a separate reduction intent. Neither executes here.").font(.caption)
            }
        }
        .confirmationDialog("Record audit-only intent? No broker action will occur.", isPresented: Binding(get: { pendingIntent != nil }, set: { if !$0 { pendingIntent = nil } })) {
            if let intent = pendingIntent, let s = selected {
                Button("Record intent only") {
                    pendingIntent = nil
                    Task {
                        busy = true
                        defer { busy = false }
                        do {
                            try await APIService.shared.recordTraderIntent(accessToken: accessToken, observationID: s.id, intent: intent, requestID: UUID())
                            message = "INTENT RECORDED ONLY — no broker request sent; no fill or stop confirmed."
                        } catch { message = "Intent result unavailable. No automatic retry. This control does not execute broker requests." }
                    }
                }
            }
            Button("Cancel", role: .cancel) { pendingIntent = nil }
        }
    }
}
