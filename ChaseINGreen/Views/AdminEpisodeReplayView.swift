import SwiftUI
import Charts

extension APIService {
    func replayEpisodes(accessToken: String) async throws -> ReplayEpisodeList {
        let data = try await sendRequest(path: "/admin/auto-trader/trading-lab/episodes", method: "GET", accessToken: accessToken, label: "replayEpisodesReadOnly")
        let result = try EpisodeReplay.decoder().decode(ReplayEpisodeList.self, from: data)
        guard !result.execution_authorized else { throw URLError(.cannotParseResponse) }
        return result
    }
    func episodeReplay(accessToken: String, episode: String) async throws -> EpisodeReplay {
        guard let id = UUID(uuidString: episode) else { throw URLError(.badURL) }
        let data = try await sendRequest(path: "/admin/auto-trader/trading-lab/\(id.uuidString)/replay", method: "GET", accessToken: accessToken, label: "episodeReplayReadOnly")
        let result = try EpisodeReplay.decoder().decode(EpisodeReplay.self, from: data)
        guard result.safeToDisplay && UUID(uuidString: result.episode_id) == id else { throw URLError(.cannotParseResponse) }
        return result
    }
}

struct AdminEpisodeHistoryView: View {
    let accessToken: String
    @ObservedObject private var auth = AuthSessionCoordinator.shared
    @State private var result: ReplayEpisodeList?
    @State private var failed = false
    var body: some View {
        List {
            if !EpisodeReplayAccess.permits(auth.capabilityProfile) {
                Label("Admin authorization required", systemImage: "lock.fill")
            } else {
                Section {
                    Label("Watch Chase's recorded decisions", systemImage: "play.rectangle.fill").font(.headline)
                    Text("Frozen evidence. Shadow results are simulated; replay never controls a broker.").font(.caption).foregroundStyle(.secondary)
                }
                if failed { Text("Episode history unavailable. No history has been reconstructed or substituted.").foregroundStyle(.orange) }
                if let result {
                    ForEach(result.episodes) { episode in
                        NavigationLink {
                            AdminEpisodeReplayView(accessToken: accessToken, episode: episode.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(episode.symbol + " · " + episode.side.uppercased()).font(.headline)
                                Text(episode.venue + " · Recorded shadow episode").font(.caption).foregroundStyle(.secondary)
                                Text(episode.at, format: .dateTime.month().day().hour().minute()).font(.caption)
                            }
                        }
                    }
                    if result.episodes.isEmpty { Text("No retained Trading Lab episodes.") }
                    if result.truncated { Text("Latest 100 episodes shown.").font(.caption) }
                } else if !failed { ProgressView("Loading recorded episodes") }
            }
        }
        .navigationTitle("Episode History")
        .scrollContentBackground(.hidden).background(AppTheme.deepBlack)
        .task(id: EpisodeReplayAccess.permits(auth.capabilityProfile)) {
            guard EpisodeReplayAccess.permits(auth.capabilityProfile) else { result = nil; return }
            do { result = try await APIService.shared.replayEpisodes(accessToken: accessToken); failed = false }
            catch { failed = true }
        }
    }
}

struct AdminEpisodeReplayView: View {
    let accessToken, episode: String
    @ObservedObject private var auth = AuthSessionCoordinator.shared
    @Environment(\.scenePhase) private var phase
    @State private var replay: EpisodeReplay?
    @State private var failed = false
    var body: some View {
        Group {
            if !EpisodeReplayAccess.permits(auth.capabilityProfile) {
                ContentUnavailableView("Admin authorization required", systemImage: "lock.fill")
            } else if let replay {
                ReplayPlayer(replay: replay)
            } else if failed {
                ContentUnavailableView("Replay unavailable", systemImage: "chart.xyaxis.line", description: Text("The read-only episode evidence could not be loaded. No candles or decisions were invented."))
            } else { ProgressView("Opening frozen episode") }
        }
        .navigationTitle("Episode Replay").navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.deepBlack)
        .task(id: EpisodeReplayAccess.permits(auth.capabilityProfile)) {
            guard EpisodeReplayAccess.permits(auth.capabilityProfile) else { replay = nil; return }
            do { replay = try await APIService.shared.episodeReplay(accessToken: accessToken, episode: episode); failed = false }
            catch { failed = true }
        }
    }
}

private struct ReplayPlayer: View {
    let replay: EpisodeReplay
    @Environment(\.scenePhase) private var phase
    @State private var clock: EpisodeReplayClock
    @State private var selected = "recorded"
    init(replay: EpisodeReplay) {
        self.replay = replay
        _clock = State(initialValue: EpisodeReplayClock(points: replay.timeline))
    }
    private var variant: ReplayVariant { replay.variants.first { $0.id == selected } ?? replay.variants[0] }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                ReplayPriceChart(candles: replay.visibleCandles(at: clock.cursor), variant: variant, cursor: clock.cursor, side: replay.side)
                    .frame(height: 290)
                controls
                if let frame = variant.frame(at: clock.cursor) {
                    ReplayDiagnosis(frame: frame, side: replay.side, cursor: clock.cursor)
                } else {
                    Label("Before the first recorded Chase decision", systemImage: "clock").foregroundStyle(.secondary)
                }
                if replay.variants.count > 1 { comparison }
                DisclosureGroup("Evidence & limitations") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(variant.method)
                        ForEach(replay.missing_evidence, id: \.self) { Text($0) }
                        Text("MFE/MAE are sampled gross observations, not tick extrema. No fees or fills are inferred.")
                        Text("Frozen evidence: " + replay.evidence_hash).font(.caption2).textSelection(.enabled)
                    }.font(.caption).padding(.top, 8)
                }
                materialEvents
                if clock.ended { ReplayScorecard(variant: variant) }
            }.padding()
        }
        .onDisappear { clock.pause() }
        .task(id: phase) {
            guard phase == .active else { clock.pause(); return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                clock.advance(seconds: 0.1)
            }
        }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(replay.symbol + " · " + replay.side.uppercased()).font(.title.bold())
            Text(replay.venue).foregroundStyle(.secondary)
            Text(variant.badge).font(.caption.bold()).foregroundStyle(variant.isCounterfactual ? .orange : .cyan)
            if replay.variants.count > 1 {
                Picker("Decision history", selection: $selected) {
                    ForEach(replay.variants) { Text($0.label).tag($0.id) }
                }.pickerStyle(.menu).onChange(of: selected) { _, _ in clock.pause() }
            } else {
                Text("Current-policy replay unavailable for this frozen evidence.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var controls: some View {
        VStack(spacing: 12) {
            Text(clock.cursor, format: .dateTime.year().month().day().hour().minute().second()).font(.caption.monospacedDigit())
            Slider(value: Binding(get: { clock.position }, set: { clock.seek($0) }), in: 0...Double(max(1,clock.points.count-1)), step: 1)
                .accessibilityLabel("Historical replay cursor")
            HStack(spacing: 22) {
                Button { clock.reset() } label: { Image(systemName: "backward.end") }.accessibilityLabel("Reset replay")
                Button { clock.step(-1) } label: { Image(systemName: "backward.frame") }.accessibilityLabel("Step back")
                Button { if clock.isPlaying { clock.pause() } else { clock.play() } } label: {
                    Image(systemName: clock.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.largeTitle)
                }.accessibilityLabel(clock.isPlaying ? "Pause replay" : "Play replay").disabled(clock.ended)
                Button { clock.step(1) } label: { Image(systemName: "forward.frame") }.accessibilityLabel("Step forward")
                Button { clock.step(10) } label: { Image(systemName: "forward.fill") }.accessibilityLabel("Fast forward ten evidence points")
            }.buttonStyle(.plain).foregroundStyle(.cyan)
            Picker("Replay speed", selection: Binding(get: { clock.speed }, set: { clock.setSpeed($0) })) {
                ForEach(EpisodeReplayClock.speeds, id: \.self) { Text("\($0, specifier: "%g")×").tag($0) }
            }.pickerStyle(.segmented)
            Text("1× reveals one evidence point per second. Historical timestamps may contain gaps.").font(.caption2).foregroundStyle(.secondary)
        }
    }
    private var comparison: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Same frozen evidence · different decisions").font(.headline)
            ForEach(replay.variants) { v in
                VStack(alignment: .leading) {
                    Text(v.badge).font(.caption.bold()).foregroundStyle(v.isCounterfactual ? .orange : .cyan)
                    Text(v.frame(at: clock.cursor)?.details["action"] ?? "No decision recorded yet")
                    Text(v.frame(at: clock.cursor)?.details["reason"] ?? "Unavailable").font(.caption)
                }
            }
        }
    }
    private var materialEvents: some View {
        DisclosureGroup("Recorded transitions reached (\(variant.markers(at: clock.cursor).count))") {
            ForEach(variant.markers(at: clock.cursor).suffix(30)) { marker in
                VStack(alignment: .leading, spacing: 4) {
                    Label(marker.action, systemImage: marker.icon).font(.subheadline.bold())
                    Text(marker.at, format: .dateTime.hour().minute().second()).font(.caption2)
                    Text(marker.reason).font(.caption)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5)
            }
        }
    }
}

private struct ReplayPriceChart: View {
    let candles: [ReplayCandle]
    let variant: ReplayVariant
    let cursor: Date
    let side: String
    var body: some View {
        VStack(alignment: .leading) {
            if candles.isEmpty {
                Label("Candle history unavailable at this cursor", systemImage: "chart.bar.xaxis").font(.caption).foregroundStyle(.secondary)
            }
            Chart {
                ForEach(candles.suffix(120)) { bar in
                    RuleMark(x: .value("Time", bar.end), yStart: .value("Low",bar.low), yEnd: .value("High",bar.high))
                        .foregroundStyle(bar.close >= bar.open ? Color.green : Color.red)
                    BarMark(x: .value("Time",bar.end), yStart: .value("Open",bar.open), yEnd: .value("Close",bar.close), width: .fixed(5))
                        .foregroundStyle(bar.close >= bar.open ? Color.green : Color.red)
                }
                if candles.isEmpty {
                    ForEach(Array(variant.frames.filter { $0.at <= cursor }.suffix(120).enumerated()), id: \.offset) { _, frame in
                        if let price = frame.numbers["mark"] {
                            PointMark(x: .value("Observation",frame.at), y: .value("Recorded mark",price)).foregroundStyle(.cyan)
                        }
                    }
                }
                ForEach(variant.markers(at: cursor).suffix(50)) { marker in
                    if let price = marker.price {
                        PointMark(x: .value("Decision",marker.at), y: .value("Price",price))
                            .symbol(marker.action == "ENTRY" ? .triangle : .diamond)
                            .foregroundStyle(variant.isCounterfactual ? Color.orange : Color.yellow)
                            .annotation(position: .top) { Text(marker.action == "ENTRY" ? side.uppercased()+" ENTRY" : marker.action).font(.system(size: 8).bold()) }
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
            .accessibilityLabel("Revealed historical evidence only")
            Text(candles.isEmpty ? "Points are recorded marks, not reconstructed candles." : "Historical candles · last 120 revealed bars · no future bars displayed.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private func replayValue(_ value: Double?, suffix: String = "") -> String {
    guard let value, value.isFinite else { return "Unavailable" }
    return String(format: "%.4f",value)+suffix
}
private struct ReplayDiagnosis: View {
    let frame: ReplayFrame
    let side: String
    let cursor: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(frame.details["action"] ?? frame.details["status"] ?? "Recorded state").font(.title2.bold())
            Text(frame.details["reason"] ?? "Decision reason unavailable")
            Text("State recorded \(frame.at.formatted(date: .omitted, time: .standard)). Values are not interpolated.").font(.caption2).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible())], alignment: .leading, spacing: 12) {
                metric("Historical mark","mark"); metric("Open gross P/L","unrealized_pnl")
                metric("Stop","stop"); metric("Target","target")
                metric("Sampled MFE · gross","mfe"); metric("Sampled MAE · gross","mae")
                metric("Profit give-back · gross","giveback"); metric("Peak gross retained %","mfe_retained_percent")
            }
            Text("Thesis: " + (frame.details["thesis"] ?? "Unavailable")).font(.subheadline)
            DisclosureGroup("Trade diagnosis & evidence") {
                VStack(spacing: 8) {
                    ForEach(["entry","quantity","realized_pnl","time_in_trade"],id: \.self) { key in
                        LabeledContent(key.replacingOccurrences(of: "_",with: " ").capitalized,value: replayValue(frame.numbers[key]))
                    }
                    ForEach(["higher_timeframe_bias","pressure","structure","momentum","volatility","remaining_reward","current_risk","confidence","policy_version"],id: \.self) { key in
                        LabeledContent(key.replacingOccurrences(of: "_",with: " ").capitalized,value: frame.details[key] ?? "Unavailable")
                    }
                }.font(.caption).padding(.top,8)
            }
        }.padding().background(.white.opacity(0.05),in: RoundedRectangle(cornerRadius:16))
    }
    private func metric(_ title: String,_ key: String) -> some View {
        VStack(alignment: .leading) { Text(title).font(.caption).foregroundStyle(.secondary); Text(replayValue(frame.numbers[key])).font(.subheadline.monospacedDigit().bold()) }
    }
}
private struct ReplayScorecard: View {
    let variant: ReplayVariant
    var body: some View {
        VStack(alignment: .leading,spacing:10) {
            Text("Episode scorecard").font(.title2.bold())
            Text(variant.badge).font(.caption).foregroundStyle(.secondary)
            ForEach(["outcome","gross_pnl","mfe","mae","mfe_captured_percent","giveback","entry_quality","direction_quality","timing_quality","management_quality","exit_quality","risk_quality","decision_quality","system_alignment"],id: \.self) { key in
                LabeledContent(key.replacingOccurrences(of:"_",with:" ").capitalized,value:variant.scorecard[key] ?? "Unavailable")
            }
            Text(variant.scorecard["lesson"] ?? "No compact lesson retained.")
            Text("Financial outcome is separate from decision quality.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
