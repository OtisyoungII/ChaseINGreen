import SwiftUI

/// Internal observer, never an execution or broker-refresh control.
struct AdminAutoTraderView: View {
    let accessToken: String
    @Environment(\.scenePhase) private var scenePhase
    @State private var snapshot: AdminOperationsSnapshot?
    @State private var watch: [OperationsWatch] = []
    @State private var events: [OperationsEvent] = []
    @State private var cursor: String?
    @State private var busy = false
    @State private var dirty = false
    @State private var error: String?
    @State private var selected: String?
    @State private var visible = false
    @State private var brokerEvidence: BrokerOperationsEvidence?
    @State private var evidenceBusy = false
    @State private var evidenceError: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Text("OES • ADMIN OPERATIONS").font(.caption.bold()).foregroundStyle(AppTheme.gold)
                Text("Auto Trader").font(.largeTitle.bold())
                Text("Account truth, market coverage and recorded decisions. Observation only.").foregroundStyle(.secondary)
                if let error { Text(error).foregroundStyle(.orange) }
                if let s = snapshot {
                    system(s, at: context.date)
                    section("ACCOUNT TRUTH") {
                        if s.accounts.isEmpty { Text("No eligible IBKR/Kraken/Aqua connections returned. Deleted Personal accounts are excluded.") }
                        ForEach(s.accounts) { account in accountCard(account, snapshotTime: s.generated_at) }
                    }
                    section("SELECTED TRADE VIEWER") { AdminTraderCockpit(accessToken: accessToken) }
                    section("BROKER PLAY-BY-PLAY — RECORDED TRUTH") {
                        Text("Shared evidence for intelligence and learning. Historical records, not a live engine. No provider calls from this viewer.").font(.caption)
                        Button(brokerEvidence == nil ? "Read recorded broker events" : "Read next evidence page") {
                            Task {
                                evidenceBusy = true
                                defer { evidenceBusy = false }
                                do {
                                    brokerEvidence = try await APIService.shared.fetchBrokerOperationsEvidence(accessToken: accessToken, cursor: brokerEvidence?.cursor)
                                    evidenceError = nil
                                } catch { evidenceError = "Broker evidence unavailable. No broker action performed." }
                            }
                        }.disabled(evidenceBusy)
                        if let evidenceError { Text(evidenceError).foregroundStyle(.orange) }
                        if let evidence = brokerEvidence {
                            ForEach(evidence.events) { event in
                                VStack(alignment: .leading) {
                                    Text("\(event.broker) · \(event.account) · \(event.event_type)").bold()
                                    Text("Recorded: \(event.observed_at ?? "UNKNOWN") · \(event.freshness)")
                                    Text("\(event.symbol) · quantity \(event.quantity.map { String($0) } ?? "UNKNOWN") · price \(event.price.map { String($0) } ?? "UNKNOWN")")
                                    Text("Origin: \(event.origin) · Protection: \(event.protection)")
                                    ForEach(event.warnings, id: \.self) { Text($0).foregroundStyle(.orange) }
                                }.font(.caption)
                            }
                            Text(evidence.note).font(.caption)
                        }
                        Text("CONTROL STATION — NOT ARMED").bold()
                        Text("AUTO OFF · AUTO EXIT · MANUAL TAKEOVER · REDUCE · PARTIAL · DISABLE ADDS · TIGHTEN PROTECTION · STOP-LOSS MODE")
                        Text("Controls unavailable until broker reconciliation and protection are verified. No command is sent. Human takeover must precede any future return to Auto.").font(.caption)
                    }
                    section("SOURCE COVERAGE — ALL DESIRED MARKETS") {
                        ForEach(s.observation?.source_registry ?? []) { item in
                            DisclosureGroup("\(item.canonical) · \(item.coverage)") {
                                Text("Active: \(item.active_provider ?? "NONE") · Trading: FALSE")
                                Text("Match-Trader: \(item.match_access)")
                                ForEach(item.sources) { source in
                                    Text("\(source.provider) · \(source.role) · \(source.native_symbol ?? "UNKNOWN")")
                                    Text("\(source.classification) · \(source.access_state)")
                                    Text("Contract: \(source.contract_identity ?? "UNKNOWN") · Basis: \(source.quote_basis)")
                                    Text("Adapter frames: \(source.supported_timeframes.joined(separator: ", ")) · Derived: \(source.derived_timeframes.joined(separator: ", "))")
                                }
                                let q = item.quality
                                Text("Freshness: \(OperationsPresentation.currentSnapshot(s.generated_at, now: context.date) ? (q.freshness_class ?? "UNKNOWN") : "STALE SNAPSHOT") · Quote age: \(q.quote_age.map { $0.formatted() } ?? "UNKNOWN") s · Trade age: \(q.trade_age.map { $0.formatted() } ?? "UNKNOWN") s")
                                Text("Request latency: \(q.request_latency_ms.map { $0.formatted() } ?? "UNKNOWN") ms")
                                Text("Attempt: \(q.request_start ?? "NONE") · Receipt: \(q.receipt_timestamp ?? "UNKNOWN")")
                                Text("Provider: \(q.provider_timestamp ?? "UNKNOWN") · Last success: \(item.last_success ?? "NONE")")
                                Text("Bid / ask: \(q.bid.map { $0.formatted() } ?? "UNKNOWN") / \(q.ask.map { $0.formatted() } ?? "UNKNOWN") · Spread: \(q.spread.map { $0.formatted() } ?? "UNKNOWN")")
                                Text("Candle: \(q.candle_finality ?? "UNKNOWN") · \(q.candle_timestamp ?? "UNKNOWN") · \(q.timeframe_provenance ?? "UNKNOWN")")
                                Text("Fallback: \(q.fallback_reason ?? "NONE") · Failure: \(q.failure_state ?? "NONE")")
                                Text("Source epoch: \(item.source_epoch)")
                            }.font(.caption)
                        }
                        Text("Kraken baseline, Nov 12: 6/6 requests; 205–317 ms; BTC last-trade age 0.32–4.95 s. Historical sample, not a guarantee.")
                        Text("Spot holdings do not authorize shorting. Margin, futures and puts: UNKNOWN. Live execution: FALSE.")
                    }
                    section("WATCHING NOW") {
                        Text("Selected public-market observations. Server lifecycle controls monitoring; opening this screen never starts it.").font(.caption)
                        ForEach($watch) { $item in
                            DisclosureGroup {
                                Toggle("\(item.group) · \(item.label)", isOn: $item.enabled)
                                    .onChange(of: item.enabled) { _, _ in dirty = true }
                                Text("\(item.support) · \(OperationsPresentation.permittedStatus(item.status, snapshotTime: s.generated_at, now: context.date)) · Trading: disabled").font(.caption)
                                Text("\(item.provider ?? "Source unresolved") / \(item.provider_symbol ?? "symbol unresolved")").font(.caption)
                                if let hint = item.catalog_symbol, item.support == "UNSUPPORTED" {
                                    Text("Catalog only: \(hint) — provider coverage not verified").font(.caption2)
                                }
                                Text("Last observation: \(item.observed_at ?? "UNKNOWN") · Age: \(OperationsPresentation.age(item.observed_at, now: context.date))").font(.caption2)
                                Text("Next observation: \(item.next_observation ?? "NOT SCHEDULED")").font(.caption2)
                                Text(item.reason).font(.caption2).foregroundStyle(.secondary)
                                Stepper("Priority \(item.priority)", value: $item.priority, in: 0...100)
                                    .onChange(of: item.priority) { _, _ in dirty = true }
                                Button("Inspect \(item.label)") { selected = s.observation?.rows.contains(where: { $0.instrument == item.id }) == true ? item.id : item.market_id }
                                Text("Attempt: \(item.last_attempt ?? "NEVER") · Last success: \(item.last_success ?? "NEVER")").font(.caption2)
                                Text("Last failure: \(item.last_failure ?? "NONE RECORDED") · \(item.failure_category ?? "—")").font(.caption2)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(item.label) · \(item.enabled ? "Selected" : "Disabled")")
                                    Text(OperationsPresentation.permittedStatus(item.status, snapshotTime: s.generated_at, now: context.date)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Divider()
                        }
                        Button("Save watch preferences") { Task { await save() } }
                            .buttonStyle(.borderedProminent).disabled(!dirty || busy)
                        if dirty { Text("Unsaved preferences — automatic snapshot refresh paused.").font(.caption) }
                    }
                    section("SCANNER — BROAD DISCOVERY") {
                        Text("Configured \(s.scanner.configured) · Observed \(s.scanner.observed) · Ranked \(s.scanner.ranked) · Stale \(s.scanner.stale)")
                        Text("Attempted: \(s.scanner.attempted.map(String.init) ?? "UNKNOWN") · Failed: \(s.scanner.failed.map(String.init) ?? "UNKNOWN")").font(.caption)
                        Text(s.scanner.attempt_note).font(.caption2)
                        if s.scanner.acquisition_failed { Text("Last acquisition failed; retained generation may be stale.").foregroundStyle(.orange) }
                        ForEach(s.scanner.rows) { row in
                            Button { selected = row.id } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(row.symbol) · \(row.direction) · \(row.setup)").bold()
                                    Text(OperationsPresentation.ranking(row, snapshotTime: s.generated_at, now: context.date)).font(.caption)
                                    Text(row.reasons.joined(separator: " · ")).font(.caption2)
                                    if let attempt = row.attempt { Text("Attempt: \(attempt.attempt_at) · \(attempt.result)").font(.caption2) }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain)
                            Divider()
                        }
                    }
                    section("LIVE DECISION FEED — RECORDED EVIDENCE") {
                        if let live = s.observation {
                            Text("Observation events — current process").bold()
                            Text(live.retention_note).font(.caption)
                            ForEach(live.events) { event in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(event.at) · \(event.instrument ?? "Cycle")").font(.caption)
                                    Text(event.type.replacingOccurrences(of: "_", with: " ")).font(.caption.bold())
                                    Text(event.result ?? "Recorded transition").font(.caption)
                                }
                            }
                            Divider()
                        }
                        Text("Recorded recommendation / simulation ledger").bold()
                        Text(s.feed.note).font(.caption)
                        if events.isEmpty { Text("No recorded decision events. This is not evidence of an active engine.") }
                        ForEach(events) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(event.at) · \(event.instrument)").font(.caption)
                                Text(event.type.replacingOccurrences(of: "_", with: " ").uppercased()).bold()
                                Text("\(event.source) · \(event.new_state)").font(.caption)
                                Text("Account: \(event.account_id.map { String($0.suffix(8)) } ?? "UNKNOWN")").font(.caption2)
                                if !event.reasons.isEmpty { Text(event.reasons.joined(separator: " · ")).font(.caption) }
                                ForEach(Array(event.steps.enumerated()), id: \.offset) { _, step in
                                    Text("SIMULATED · \(step.kind) · \(step.observed_at ?? event.at)").font(.caption.bold())
                                    Text(step.reasons.joined(separator: " · ")).font(.caption)
                                    metrics(step.metrics)
                                }
                                if let plan = event.plan {
                                    DisclosureGroup("Recorded simulated plan — not a live order") {
                                        Text("\(plan.side.uppercased()) · Expires \(plan.expires_at ?? "UNKNOWN")")
                                        metrics(plan.metrics)
                                    }
                                }
                            }
                            Divider()
                        }
                        if cursor != nil && events.count < 120 {
                            Button("Load older events (up to 120)") { Task { await older() } }.disabled(busy)
                        }
                    }
                    section("SELECTED INSTRUMENT") {
                        if let row = s.observation?.rows.first(where: { $0.instrument == selected }) {
                            Text(row.instrument).font(.headline)
                            Text("\(row.provider ?? "UNKNOWN") / \(row.provider_symbol ?? "UNRESOLVED")")
                            Text("\(OperationsPresentation.permittedStatus(row.result, snapshotTime: s.generated_at)) · Observed \(row.observed_at ?? "UNKNOWN")")
                            Text("Snapshot price: \(row.price.map { $0.formatted() } ?? "UNKNOWN") · Provider volume: \(row.volume.map { $0.formatted() } ?? "UNKNOWN")")
                            Text("Broker execution identity: UNRESOLVED · Trading: DISABLED")
                            if let failure = row.frame_failure { Text("Latest timeframe failure: \(failure)").foregroundStyle(.orange) }
                            ForEach(row.timeframes) { frame in
                                DisclosureGroup("\(frame.timeframe) · \(frame.role) · \(OperationsPresentation.permittedStatus(frame.status, snapshotTime: s.generated_at))") {
                                    Text("\(frame.bar_count) closed bars · \(frame.observed_at ?? "UNKNOWN")")
                                    Text("Direction: \(frame.state?.direction ?? "UNKNOWN")")
                                    Text("EMA slope: \(frame.state?.ema_slope.map { $0.formatted() } ?? "UNKNOWN") · EMA separation: \(frame.state?.ema_separation.map { $0.formatted() } ?? "UNKNOWN")")
                                    Text("Directional efficiency: \(frame.state?.directional_efficiency.map { $0.formatted() } ?? "UNKNOWN")")
                                    Text("Range expansion: \(frame.state?.range_expansion_ratio.map { $0.formatted() } ?? "UNKNOWN") · Normalized volatility range: \(frame.state?.normalized_range_span.map { $0.formatted() } ?? "UNKNOWN")")
                                    Text("Choppy: \(frame.state?.choppy.map { String($0) } ?? "UNKNOWN") · Compressed: \(frame.state?.compressed.map { String($0) } ?? "UNKNOWN")")
                                    if let reason = frame.reason { Text(reason) }
                                }.font(.caption)
                            }
                            Text("RSI, MACD, VWAP, ATR and Bollinger: UNKNOWN. No timing or trade decision is generated from this observation.").font(.caption)
                        } else if let row = s.scanner.rows.first(where: { $0.id == selected }) {
                            Text("\(row.label) · \(row.symbol)").font(.headline)
                            Text("Source: \(row.provider) / \(row.provider_symbol)")
                            Text("Broker execution symbol: \(row.execution_symbol ?? "UNRESOLVED")")
                            Text("Snapshot price: \(row.price.map { $0.formatted() } ?? "UNKNOWN") · \(OperationsPresentation.permittedStatus(row.status, snapshotTime: s.generated_at, now: context.date))")
                            if let last = row.last_known_price { Text("Last known price (not current): \(last.formatted())").foregroundStyle(.orange) }
                            Text("Observed: \(row.observed_at ?? "UNKNOWN")")
                            Text("Evaluated: \(row.evaluated_at ?? "UNKNOWN")")
                            Text("\(row.direction) · \(row.setup) · \(OperationsPresentation.permittedStatus(row.status, snapshotTime: s.generated_at, now: context.date))")
                            Text(row.reasons.joined(separator: " · "))
                            Text(row.note).font(.caption)
                            metrics(row.metrics, snapshotTime: s.generated_at)
                            Text("Daily / 4H / 1H / 5m state, RSI, MACD, VWAP, ATR, Bollinger, spread and patterns: UNAVAILABLE unless explicitly recorded above.").font(.caption)
                        } else { Text("Select an instrument above. Detail requires a recorded observation; configured coverage alone is not market evidence.") }
                    }
                    section("TRADE PLAN") {
                        Text("NO ACTIVE TRADE PLAN VERIFIED")
                        Text("Historical simulated plans appear with their ledger events. No operational engine publishes an active account-specific plan here yet. Risk/reward, projected equity and scaled entries are unavailable.").font(.caption)
                    }
                    section("RISK / SAFETY") {
                        Text("Automation: DISABLED · Recovery: \(s.recovery)")
                        Text("Risk per trade / daily loss / risk budget / protection policy: \(s.risk_status)")
                        Text("Timing gate (:18 / :38): \(s.timing_gate)")
                        Text("Existing account-configured drawdown limits appear on account cards. Missing current account facts do not authorize sizing.").font(.caption)
                    }
                } else if busy { ProgressView("Reading operations snapshot…") }
                else { Text("Operations snapshot unavailable. No account or engine state inferred.") }
                Button("Refresh stored evidence") { Task { await load() } }.disabled(busy || dirty)
            }.padding()
        }
        .background(AppTheme.cardBlack)
        .foregroundStyle(AppTheme.primaryText)
        .navigationTitle("Admin Auto Trader")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await load()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(OperationsPresentation.refreshSeconds)) }
                catch { return }
                guard !Task.isCancelled else { return }
                if visible && !dirty { await load() }
            }
        }
    }
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).foregroundStyle(AppTheme.gold)
            content()
        }.padding().frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 14))
    }
    private func metrics(_ values: [OperationsMetric], snapshotTime: String? = nil) -> some View {
        ForEach(values) { metric in
            HStack(alignment: .top) {
                Text(metric.name.replacingOccurrences(of: "_", with: " "))
                Spacer()
                VStack(alignment: .trailing) {
                    Text(metric.formatted)
                    Text(snapshotTime.map { OperationsPresentation.permittedStatus(metric.state, snapshotTime: $0) } ?? metric.state).font(.caption2).foregroundStyle(.secondary)
                }
            }.font(.caption)
        }
    }
    private func system(_ s: AdminOperationsSnapshot, at: Date) -> some View {
        section("SYSTEM STATUS") {
            Text(OperationsPresentation.currentSnapshot(s.generated_at, now: at) ? s.mode : "BLOCKED — SNAPSHOT STALE").font(.title2.bold())
            Text(s.blocker)
            Text("Snapshot: \(s.generated_at)").font(.caption)
            if !OperationsPresentation.currentSnapshot(s.generated_at, now: at) {
                Text("DISPLAYED SNAPSHOT STALE — refresh required").foregroundStyle(.orange)
            }
            Text("Scheduler heartbeat: \(s.heartbeat ?? "UNKNOWN — no scheduler heartbeat")")
            Text("Observation cycle: \(s.last_observation_cycle ?? "UNKNOWN")")
            Text("Scanner cycle: \(s.scanner.last_cycle ?? "UNKNOWN")")
            Text("Latest ledger decision: \(s.last_decision ?? "UNKNOWN")")
            if let observation = s.observation {
                Text("Last successful market observation: \(observation.last_success ?? "NEVER")")
                Text("Cycle started: \(observation.cycle_started ?? "NEVER")")
                Text("Next expected cycle: \(observation.next_cycle ?? "NOT SCHEDULED")")
                Text("Last cycle: \(observation.duration_seconds.map { String(format: "%.2fs", $0) } ?? "UNKNOWN") · \(observation.requests) requests · concurrency \(observation.concurrency)").font(.caption)
            }
            Text("Display refresh every 30 seconds. Scheduler heartbeat, cycle completion and per-market success are different facts. No broker refresh or execution.").font(.caption)
        }
    }
    private func accountCard(_ a: OperationsAccount, snapshotTime: String) -> some View {
        DisclosureGroup {
            Text("Connection …\(a.connection_suffix) · Native \(a.native_account ?? "UNKNOWN")")
            Text("Canonical binding: \(a.binding_verified ? "present" : "UNVERIFIED") · Auth: \(a.authentication)")
            Text("Last sync: \(a.last_sync ?? "UNKNOWN") · Snapshot: \(a.observed_at ?? "UNKNOWN")")
            metrics(a.metrics, snapshotTime: snapshotTime)
            Text("Provider asset balances").bold()
            if a.provider == "ibkr" {
                Text("ACCOUNT TRUTH — persisted evidence only")
                Text("Currency \(a.currency ?? "UNKNOWN") · Provider time \(a.provider_at ?? "UNKNOWN") · Received \(a.received_at ?? "UNKNOWN")")
                Text("Canonical: \(a.canonical_account ?? "UNKNOWN") · Native: \(a.native_account ?? "UNKNOWN")")
                Text("Type: \(a.account_type ?? "UNKNOWN") · Customer: \(a.customer_type ?? "UNKNOWN")")
                Text("Active: \(a.active.map { String($0) } ?? "UNKNOWN") · Visible: \(a.visible.map { String($0) } ?? "UNKNOWN")")
                Text("Last seen: \(a.last_seen ?? "UNKNOWN") · Last sync: \(a.last_sync ?? "UNKNOWN")")
                Text("Positions: \(a.positions_status ?? "UNKNOWN") · Executions: \(a.executions_status ?? "UNKNOWN")")
                Text("MARKET DATA: \(a.qualification ?? "IBKR_MARKET_DATA_NOT_QUALIFIED")")
                Text("No current session or execution authority implied.")
            }
            metrics(a.asset_balances, snapshotTime: snapshotTime)
            ForEach(a.holdings) { h in
                if a.provider == "ibkr" {
                    Text("Account \(h.native_account ?? "UNKNOWN") · conid \(h.conid ?? "UNKNOWN") · \(h.side ?? "UNKNOWN")")
                    Text("Cost \(h.average_cost.map { String($0) } ?? "UNKNOWN") · Provider mark \(h.provider_mark.map { String($0) } ?? "UNKNOWN") · Unrealized P/L \(h.unrealized_pnl.map { String($0) } ?? "UNKNOWN") \(h.currency ?? "")")
                    Text("Provider time \(h.provider_at ?? "UNKNOWN") · Received \(h.received_at ?? "UNKNOWN")")
                }
                Text("\(h.symbol): \(h.quantity.map { $0.formatted(.number.precision(.fractionLength(0...10))) } ?? "UNKNOWN") · \(OperationsPresentation.permittedStatus(h.state, snapshotTime: snapshotTime)) · Protection \(h.protection)")
            }
            if a.holdings.isEmpty { Text("Holdings: no rows available; not proof of an empty broker account.") }
            Text("Orders: \(a.orders_status) · Restrictions: \(a.restrictions) · Eligibility: \(a.eligibility)")
            metrics(a.risk)
            Text(a.reason).font(.caption)
        } label: {
            VStack(alignment: .leading) {
                Text("\(a.provider.uppercased()) · \(a.label) · \(a.ownership)").bold()
                Text("\(OperationsPresentation.permittedStatus(a.status, snapshotTime: snapshotTime)) · \(a.connection_status)").font(.caption)
            }
        }
    }
    @MainActor private func load() async {
        guard !busy, !dirty else { return }
        busy = true; defer { busy = false }
        do {
            let fresh = try await APIService.shared.fetchAdminOperations(accessToken: accessToken)
            guard !Task.isCancelled else { return }
            snapshot = fresh; watch = fresh.watch; events = fresh.feed.events; cursor = fresh.feed.next_cursor; error = nil
        } catch { snapshot = nil; self.error = "Operations unavailable or access denied. No current state inferred." }
    }
    @MainActor private func save() async {
        guard !busy, let snapshot else { return }
        busy = true
        do {
            try await APIService.shared.saveAdminWatch(accessToken: accessToken, revision: snapshot.revision, items: watch)
            dirty = false; busy = false; await load()
        } catch { busy = false; self.error = "Preferences not saved. Refresh/reopen to resolve a conflict; no automatic write retry." }
    }
    @MainActor private func older() async {
        guard !busy, let cursor else { return }
        busy = true; defer { busy = false }
        do {
            let page = try await APIService.shared.fetchAdminOperationsEvents(accessToken: accessToken, cursor: cursor)
            let ids = Set(events.map(\.id))
            events = Array((events + page.events.filter { !ids.contains($0.id) }).prefix(120)); self.cursor = page.next_cursor
        } catch { self.error = "Older event page unavailable." }
    }
}
