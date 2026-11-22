import SwiftUI

struct TradingLabSnapshot: Decodable {
    let status: String
    let at: String?
    let focus: String?
    let universe_count, focused_count, unavailable_count: Int?
    let simulated: Bool
    let execution_authorized: Bool
    let next_evaluation: String
    let pnl_label: String
    let board: [TradingLabMarket]
    let realm_board: [TradingLabMarket]?
    let realm: TradingLabRealm?
    let venue_counts: [String: Int]?
    let unique_market_count: Int?
    let multi_venue_markets: [String]?
    let focus_market: String?
    let decisions: [TradingLabDecision]
    let open_positions: [TradingLabPosition]
    let completed: [TradingLabCompleted]
    let stats: TradingLabStats
}
struct TradingLabRealm: Decodable {
    let direction, breadth, regime, sampling: String
    let leaders, laggards, confirming, diverging: [String]
}
struct TradingLabStats: Decodable { let completed, wins, losses: Int; let gross_pnl, open_risk: Double }
struct TradingLabMarket: Decodable, Identifiable {
    var id: String { symbol }
    let symbol, decision, reason, attention: String
    let direction, thesis, regime, confidence, reconsideration, comparison_summary: String?
    let bid, ask, spread, price: Double?
    let observed_at: String?
    let analysis_layer, market_state: String?
    let venue_coverage, pressure, cross_venue_state, venue, reference_symbol: String?
    let movement_percent: Double?
    let venues: [TradingLabMarket]?
}
struct TradingLabDecision: Decodable { let symbol, at, decision, reason: String }
struct TradingLabPlan: Decodable { let side: String; let entry, quantity, stop, target: Double; let slippage_source, size_basis: String }
struct TradingLabManagement: Decodable { let action, reason, thesis: String }
struct TradingLabState: Decodable {
    let status: String
    let entry_fill, current_price, unrealized_pnl, highest_unrealized, lowest_unrealized, sampled_profit_giveback: Double?
    let stop, remaining, gross_pnl: Double
    let filled_at, closed_at, exit_reason: String?
    let management: TradingLabManagement?
}
struct TradingLabPosition: Decodable, Identifiable {
    let id, symbol: String
    let plan: TradingLabPlan
    let decision: TradingLabMarket
    let state: TradingLabState
}
struct TradingLabCompleted: Decodable, Identifiable {
    let id, episode, symbol, at, entry_quality, management_quality, exit_quality, outcome, lesson: String
    let gross_pnl: Double
    let state: TradingLabState
    let decision: TradingLabMarket
}
struct TradingLabHistory: Decodable {
    let simulated, execution_authorized, earlier_history_available: Bool
    let timeline: [TradingLabTimeline]
}
struct TradingLabTimeline: Decodable { let at, action, reason: String; let price, quantity, gross_pnl: Double? }

extension APIService {
    func tradingLab(accessToken: String, action: String? = nil) async throws -> TradingLabSnapshot {
        let body = try action.map { try JSONEncoder().encode(["action": $0]) }
        let data = try await sendRequest(path: "/admin/auto-trader/trading-lab" + (action == nil ? "" : "/control"), method: action == nil ? "GET" : "POST", accessToken: accessToken, body: body, label: "tradingLabSimulation")
        return try JSONDecoder().decode(TradingLabSnapshot.self, from: data)
    }
    func tradingLabHistory(accessToken: String, episode: String) async throws -> TradingLabHistory {
        guard let id = UUID(uuidString: episode) else { throw URLError(.badURL) }
        let data = try await sendRequest(path: "/admin/auto-trader/trading-lab/\(id.uuidString)/history", method: "GET", accessToken: accessToken, label: "tradingLabHistory")
        return try JSONDecoder().decode(TradingLabHistory.self, from: data)
    }
}

private func labNumber(_ value: Double?) -> String { value.map { String(format: "%.4f", $0) } ?? "Unavailable" }

struct AdminTradingLabView: View {
    let accessToken: String
    @Environment(\.scenePhase) private var phase
    @State private var snapshot: TradingLabSnapshot?
    @State private var error: String?
    @State private var busy = false
    @State private var confirmation: String?
    var body: some View {
        List {
            Section { Label("SIMULATED TRADING — NO BROKER ORDERS", systemImage: "flask.fill").font(.headline).foregroundStyle(.cyan) }
            if let error { Text(error).foregroundStyle(.orange) }
            Section("Episode history") {
                    NavigationLink("Episode History & Replay") { AdminEpisodeHistoryView(accessToken: accessToken) }
                        .accessibilityIdentifier("admin.tradingLab.episodeReplay")
                }
            if let s = snapshot {
                TradingLabStatus(snapshot: s)
                Section("Open simulated positions") {
                    if s.open_positions.isEmpty { Text("No open simulations. Chase keeps evaluating the market.").foregroundStyle(.secondary) }
                    ForEach(s.open_positions) { position in
                        NavigationLink { TradingLabDetail(accessToken: accessToken, episode: position.id, symbol: position.symbol, decision: position.decision) } label: { TradingLabPositionCard(position: position) }
                    }
                }
                Section("Decision feed") {
                    ForEach(Array(s.decisions.prefix(20).enumerated()), id: \.offset) { _, d in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(d.symbol) · \(d.decision.replacingOccurrences(of: "_", with: " "))").font(.subheadline.bold())
                            Text(d.reason).font(.caption)
                            Text(AdminNavigationPresentation.time(d.at)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                if let realm = s.realm { TradingLabRealmCard(realm: realm, focus: s.focus_market) }
                TradingLabMarketBoard(rows: s.realm_board ?? s.board)
                Section("Completed simulations") {
                    if s.completed.isEmpty { Text("No completed simulations yet.").foregroundStyle(.secondary) }
                    ForEach(s.completed) { trade in
                        NavigationLink { TradingLabDetail(accessToken: accessToken, episode: trade.episode, symbol: trade.symbol, decision: trade.decision, completed: trade) } label: {
                            VStack(alignment: .leading) {
                                Text("\(trade.symbol) · \(trade.outcome)").font(.headline)
                                Text("Gross $\(labNumber(trade.gross_pnl)) · \(trade.state.exit_reason ?? "Closed")").font(.caption)
                                Text("Decision quality: \(trade.entry_quality)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Simulation controls") {
                    Button(s.status == "PAUSED" ? "Resume Lab" : "Pause Lab") { Task { await load(action: s.status == "PAUSED" ? "RESUME" : "PAUSE") } }
                    Button("Start Lab") { Task { await load(action: "START") } }
                    Button("Close all shadow positions", role: .destructive) { confirmation = "CLOSE_ALL" }
                    Button("Reset session statistics") { confirmation = "RESET_STATS" }
                    Text("Pause prevents new simulated entries. Existing simulations keep their protection and management. Closing waits for a fresh market sample. Reset preserves history.").font(.caption).foregroundStyle(.secondary)
                }.disabled(busy)
            } else if error == nil { ProgressView("Loading Trading Lab") }
        }
        .navigationTitle("Trading Lab").navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(AppTheme.deepBlack)
        .task(id: phase) {
            guard phase == .active else { return }
            await load()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(10)) } catch { return }
                await load()
            }
        }
        .refreshable { await load() }
        .confirmationDialog("Simulation only — no broker action", isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } })) {
            Button(confirmation == "CLOSE_ALL" ? "Close simulated positions" : "Reset statistics, preserve history") {
                let action = confirmation; confirmation = nil
                Task { await load(action: action) }
            }
            Button("Cancel", role: .cancel) { confirmation = nil }
        }
    }
    private func load(action: String? = nil) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do {
            let s = try await APIService.shared.tradingLab(accessToken: accessToken, action: action)
            guard s.simulated && !s.execution_authorized else { throw URLError(.cannotParseResponse) }
            snapshot = s; error = nil
        } catch { self.error = "Trading Lab unavailable. Last displayed values may be stale." }
    }
}

private struct TradingLabStatus: View {
    let snapshot: TradingLabSnapshot
    var body: some View {
        Section("Chase status") {
            LabeledContent("Trading Lab", value: snapshot.status)
            LabeledContent("Current focus", value: snapshot.focus_market ?? snapshot.focus ?? "No ranked focus")
            LabeledContent("Weekend universe", value: "\(snapshot.unique_market_count ?? snapshot.universe_count ?? snapshot.board.count) unique markets")
            LabeledContent("Venue coverage", value: "Aqua \(snapshot.venue_counts?["aqua"] ?? 0) · Kraken \(snapshot.venue_counts?["kraken"] ?? 0)")
            LabeledContent("Multiple venues", value: "\(snapshot.multi_venue_markets?.count ?? 0)")
            LabeledContent("Closed / unavailable roster", value: "\(snapshot.unavailable_count ?? 0)")
            LabeledContent("Focused", value: "\(snapshot.focused_count ?? 0)")
            LabeledContent("Open shadow positions", value: "\(snapshot.open_positions.count)")

            LabeledContent("Last evaluation", value: AdminNavigationPresentation.time(snapshot.at))
            Text(snapshot.next_evaluation).font(.caption)
            LabeledContent("Session simulated gross P/L", value: "$" + labNumber(snapshot.stats.gross_pnl))
            LabeledContent("Open simulated price risk", value: "$" + labNumber(snapshot.stats.open_risk))
            LabeledContent("Win / loss", value: "\(snapshot.stats.wins) / \(snapshot.stats.losses)")
            Text(snapshot.pnl_label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
private struct TradingLabPositionCard: View {
    let position: TradingLabPosition
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(position.symbol) · \(position.plan.side.uppercased()) · SIMULATED").font(.headline)
            Text(position.state.status.replacingOccurrences(of: "_", with: " ")).font(.caption).foregroundStyle(.cyan)
            Text("Entry \(labNumber(position.state.entry_fill)) · Current \(labNumber(position.state.current_price))")
            Text("Size \(labNumber(position.state.remaining)) normalized units")
            Text("Stop \(labNumber(position.state.stop)) · Target \(labNumber(position.plan.target))")
            Text("Open $\(labNumber(position.state.unrealized_pnl)) · MFE $\(labNumber(position.state.highest_unrealized)) · MAE $\(labNumber(position.state.lowest_unrealized))")
            Text("Give-back $\(labNumber(position.state.sampled_profit_giveback))")
            Text(position.decision.thesis ?? position.decision.reason)
            Text("\(position.state.management?.action ?? "WAIT FOR NEXT SAMPLE") — \(position.state.management?.reason ?? "Entry requires a subsequent real quote")")
            Text("Opened: \(AdminNavigationPresentation.time(position.state.filled_at))").foregroundStyle(.secondary)
        }.font(.caption)
    }
}
private struct TradingLabDetail: View {
    let accessToken, episode, symbol: String
    let decision: TradingLabMarket
    var completed: TradingLabCompleted? = nil
    @State private var history: TradingLabHistory?
    @State private var failed = false
    var body: some View {
        List {
            Section {
                NavigationLink("Replay this episode", destination: AdminEpisodeReplayView(accessToken: accessToken, episode: episode))
            }
            Section("SIMULATED · causal decision") {
                Text(decision.thesis ?? decision.reason)
                Text("Reconsider: " + (decision.reconsideration ?? "Next market evidence"))
            }
            Section("System comparison") {
                LabeledContent("Trading agent", value: decision.decision)
                Text("Discovery / technical system: \(decision.direction ?? "Unknown") · \(decision.regime ?? "Unknown")")
                Text("These signals share the existing evaluator; they are not independent votes.").font(.caption)
                Text(decision.comparison_summary ?? "No fresh retained ML / Trade Intelligence comparison available.").font(.caption)
                if let c = completed {
                    LabeledContent("Actual simulated outcome", value: "\(c.outcome) · $\(labNumber(c.gross_pnl)) gross")
                    Text("Entry \(c.entry_quality) · Management \(c.management_quality) · Exit \(c.exit_quality)")
                    Text(c.lesson)
                }
            }
            Section("Causal timeline") {
                if failed { Text("Timeline could not be loaded.") }
                if let history {
                    ForEach(Array(history.timeline.enumerated()), id: \.offset) { _, e in
                        VStack(alignment: .leading) {
                            Text(e.action.replacingOccurrences(of: "_", with: " ")).font(.headline)
                            Text(e.reason).font(.caption)
                            Text(AdminNavigationPresentation.time(e.at)).font(.caption2)
                        }
                    }
                    if history.earlier_history_available { Text("Showing the latest 200 retained transitions; older evidence remains stored.") }
                }
            }
        }.navigationTitle(symbol + " simulation")
            .task {
                do {
                    let h = try await APIService.shared.tradingLabHistory(accessToken: accessToken, episode: episode)
                    guard h.simulated && !h.execution_authorized else { throw URLError(.cannotParseResponse) }
                    history = h
                } catch { failed = true }
            }
    }
}


private struct TradingLabRealmCard: View {
    let realm: TradingLabRealm
    let focus: String?
    var body: some View {
        Section("Crypto realm") {
            LabeledContent("Broad direction", value: realm.direction)
            Text(realm.breadth).font(.caption)
            LabeledContent("Leaders", value: realm.leaders.joined(separator: " · "))
            LabeledContent("Laggards", value: realm.laggards.joined(separator: " · "))
            LabeledContent("Confirming venues", value: realm.confirming.joined(separator: " · "))
            LabeledContent("Diverging venues", value: realm.diverging.joined(separator: " · "))
            LabeledContent("Chase focus", value: focus ?? "Collecting evidence")
            Text(realm.sampling).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
private struct TradingLabMarketBoard: View {
    let rows: [TradingLabMarket]
    @State private var search = ""
    private var filtered: [TradingLabMarket] { rows.filter { search.isEmpty || $0.symbol.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        Section("Market board") {
            TextField("Find a market", text: $search).textInputAutocapitalization(.characters)
            ForEach(filtered.filter { $0.attention != "NORMAL" }) { TradingLabMarketRow(row: $0) }
            DisclosureGroup("Normal markets (\(filtered.filter { $0.attention == "NORMAL" }.count))") {
                ForEach(filtered.filter { $0.attention == "NORMAL" }) { TradingLabMarketRow(row: $0) }
            }
        }
    }
}
private struct TradingLabMarketRow: View {
    let row: TradingLabMarket
    var body: some View {
        DisclosureGroup {
            Text(row.thesis ?? row.reason).font(.caption)
            ForEach(row.venues ?? []) { venue in
                VStack(alignment: .leading, spacing: 3) {
                    Text(venue.venue ?? venue.symbol).font(.caption.bold())
                    Text("Bid \(labNumber(venue.bid)) · Ask \(labNumber(venue.ask)) · Spread \(labNumber(venue.spread))").font(.caption2)
                    Text("\(venue.market_state ?? "UNKNOWN") · \(AdminNavigationPresentation.time(venue.observed_at))").font(.caption2)
                }
            }
            Text("Reference: \(row.reference_symbol ?? row.symbol). Venue quotes are never blended.").font(.caption2)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(row.symbol) · \(row.attention)").font(.subheadline.bold())
                Text("\(row.decision) · \(row.pressure ?? row.direction ?? "UNKNOWN") · \(labNumber(row.movement_percent))%").font(.caption)
                Text(row.venue_coverage ?? row.venue ?? "Aqua").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
