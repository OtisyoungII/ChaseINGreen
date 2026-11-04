import SwiftUI

struct OpportunityScreenerView: View {
    let accessToken: String
    @Environment(\.scenePhase) private var scenePhase
    @State private var generation: ScreenerGeneration?
    @State private var asset = "ALL"
    @State private var direction = "BOTH"
    @State private var foregroundRefresh: Task<Void, Never>?
    @State private var loading = false
    @State private var failed = false
    @State private var availability: String?
    @State private var endpointUnavailable = false
    private let assets = [("ALL", "All"), ("STOCK", "Stocks"), ("FUTURE", "Futures"),
                          ("INDEX", "Indices"), ("CRYPTO", "Crypto"), ("COMMODITY", "Commodities")]

    var body: some View {
        List {
            Section {
                Picker("Asset class", selection: $asset) {
                    ForEach(assets, id: \.0) { Text($0.1).tag($0.0) }
                }
                Picker("Direction", selection: $direction) {
                    Text("Long").tag("LONG")
                    Text("Short").tag("SHORT")
                    Text("Both").tag("BOTH")
                }.pickerStyle(.segmented)
                Text("Research ranking, not an entry signal. Open a chart for detailed analysis.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let generation {
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    let stale = failed || generation.isExpired(at: context.date)
                    let filtered = generation.filtered(asset: asset, direction: direction)
                    let ranked = filtered.filter { $0.isRanked(at: context.date, generationStale: stale) }
                    let diagnostics = filtered.filter { !$0.isRanked(at: context.date, generationStale: stale) }
                    Section {
                        ForEach(ranked) { candidate in
                            VStack(alignment: .leading, spacing: 12) {
                                if candidate.instrument.supportedNavigation {
                                    NavigationLink {
                                        MarketDetailView(requestSymbol: candidate.instrument.navigationSymbol,
                                            displayName: candidate.instrument.name,
                                            tradeSymbol: candidate.instrument.navigationSymbol,
                                            accessToken: accessToken, broker: candidate.instrument.provider,
                                            instrumentID: candidate.instrument.providerSymbol,
                                            discoverSnapshot: DiscoverSnapshot(generation: generation, candidate: candidate))
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(candidate.instrument.symbol).font(.title3.bold())
                                            Text("\(candidate.direction) · \(candidate.state)").font(.subheadline.bold())
                                            Text(candidate.instrument.name).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                DiscoverEvidenceCard(candidate: candidate, historical: false)
                            }.padding(.vertical, 8)
                        }
                        if ranked.isEmpty {
                            Text(stale ? "Previous evidence expired. Pull to refresh." : "No ranked opportunities match these filters.")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("\(ranked.count) ranked · \(generation.scannedCount ?? generation.universeCount) scanned")
                    } footer: {
                        Text("\(filtered.count) records match filters · \(ranked.count) displayed. Bounded curated universe; not a whole-market scan. Scores are not probabilities or entry instructions.")
                    }
                    Section {
                        DisclosureGroup("\(diagnostics.count) not ranked in this view") {
                            ForEach(diagnostics) { candidate in
                                VStack(alignment: .leading) {
                                    Text(candidate.instrument.symbol).font(.headline)
                                    Text(stale || candidate.freshness == "stale" ? "Stale evidence" : candidate.qualificationLabel.capitalized)
                                    ForEach(candidate.displayReasons(stale: stale), id: \.self) { Text($0).font(.caption) }
                                }
                            }
                        }
                        Text("Scan coverage: \(generation.observedCount) observed · \(generation.evaluatedCount.map(String.init) ?? "unknown") evaluated · \(generation.unavailableCount.map(String.init) ?? "unknown") provider unavailable")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("Evaluated \(generation.evaluatedAt)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            } else if loading {
                ProgressView("Loading discovery")
            } else {
                ContentUnavailableView("Discovery unavailable", systemImage: "binoculars",
                    description: Text(unavailableMessage))
            }
        }
        .navigationTitle("Discover")
        .refreshable { await load() }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            if generation == nil { await load() }
        }
        .onDisappear { foregroundRefresh?.cancel() }
        .onChange(of: scenePhase) { _, phase in
            foregroundRefresh?.cancel()
            foregroundRefresh = phase == .active ? Task { await load() } : nil
        }
    }

    private var unavailableMessage: String {
        if endpointUnavailable { return "Discovery is not available on this server yet." }
        if failed { return "Could not read discovery. Pull to retry." }
        if availability == "disabled" { return "Discovery collection is currently disabled." }
        return "No completed generation is available yet. Pull to check again."
    }

    @MainActor private func load() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let response = try await APIService.shared.fetchOpportunityScreener(accessToken: accessToken)
            try Task.checkCancellation()
            availability = response.availability
            endpointUnavailable = false
            if let completed = response.generation { generation = completed }
            failed = response.status == "stale" || (response.generation == nil && generation != nil)
        } catch is CancellationError {
            // Keep the completed generation when leaving this screen.
        } catch {
            failed = true
            let failure = error as NSError
            endpointUnavailable = failure.domain == "APIService" && failure.code == 404
        }
    }
}

// Shared with chart provenance. Historical text is explicitly labelled and never
// substitutes for the chart's independently fetched current analysis.
struct DiscoverEvidenceCard: View {
    let candidate: ScreenerCandidate
    let historical: Bool
    private func number(_ value: Double) -> String { String(format: "%.2f", value) }
    private func item(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            Text(text).font(.subheadline)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if historical {
                Text("Historical snapshot · \(candidate.direction) · \(candidate.state)").font(.headline)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(historical ? "Snapshot research strength" : "Research strength").font(.subheadline)
                Spacer()
                Text(candidate.score.map { number($0) + " / 100" } ?? "Unavailable").font(.headline.monospacedDigit())
            }
            if let observation = candidate.observation {
                item("OBSERVED PRICE", "\(observation.price.formatted(.number.precision(.significantDigits(2...8)))) \(candidate.instrument.currency) · \(observation.observedAt ?? "time unavailable")")
            }
            if let thesis = candidate.thesis {
                item("WHY THIS", thesis.whyThis)
                item("WHY NOW", thesis.whyNow)
                item("CONFIRMATION", thesis.confirmation)
                item("INVALIDATION", thesis.invalidation)
                item("TIMING / RISK", thesis.timingRisk)
            } else {
                item("THESIS", "Unavailable in this generation. No confirmation or invalidation level inferred.")
            }
            DisclosureGroup("What caused this score?") {
                ForEach(["technical_structure", "momentum", "directional_movement"], id: \.self) { key in
                    if let component = candidate.scoreComponents?[key] {
                        let label = key == "technical_structure" ? "Range structure" : key == "momentum" ? "EMA momentum" : "Price movement"
                        item(label, "\(number(component.contribution)) / \(Int(component.maximum)) · measured \(number(component.measuredValue)) \(component.unit.replacingOccurrences(of: "_", with: " "))")
                    }
                }
                Text("Structure × 40; capped |momentum| / 2 × 35; capped |movement %| / 3 × 25. Total rounded to two decimals.").font(.caption)
                if candidate.scoreComponents == nil { Text("Component evidence unavailable.") }
            }.font(.subheadline)
            DisclosureGroup("Supporting evidence & timestamps") {
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    supporting(at: context.date)
                }
                Text("Closed 15m evidence: \(candidate.candleObservedAt ?? "unavailable")").font(.caption)
                if let note = candidate.instrument.identityNote { Text(note).font(.caption) }
                Text("Provider: \(candidate.instrument.provider) · \(candidate.instrument.providerSymbol)").font(.caption)
            }.font(.subheadline)
        }
    }
    @ViewBuilder private func supporting(at date: Date) -> some View {
        if let relative = candidate.relativePerformance,
           relative.status == "AVAILABLE", let expiry = screenerDate(relative.expiresAt), historical || date < expiry,
           let own = relative.instrumentReturnPct, let benchmark = relative.benchmarkReturnPct,
           let difference = relative.relativeReturnPercentagePoints, let window = relative.instrumentWindow {
            item("RELATIVE PERFORMANCE", "\(number(own))% vs \(relative.benchmark?.symbol ?? "benchmark") \(number(benchmark))% = \(number(difference))pp. Window \(window.startAt) → \(window.endAt) (\(window.sessionPolicy)). Observed \(window.observedAt).")
        } else { Text("Relative performance unavailable or expired.").font(.caption) }
        if let activity = candidate.activity,
           activity.status == "AVAILABLE", let expiry = screenerDate(activity.expiresAt), historical || date < expiry,
           let ratio = activity.rvol, let current = activity.currentCumulativeVolume,
           let median = activity.historicalMedianCumulativeVolume {
            item("RELATIVE VOLUME", "\(number(ratio))× same-cutoff median. Current \(number(current)); median \(number(median)) \(activity.volumeUnit ?? "provider units"). \(activity.sampleCount) samples. Cutoff \(activity.cutoffAt ?? "unknown"); observed \(activity.observedAt ?? "unknown"). \(activity.participation ?? "Unclassified") (elevated ≥1.5×; low <0.75×).")
        } else { Text("Relative volume unavailable or expired.").font(.caption) }
        if let recovery = candidate.recovery, let expiry = screenerDate(recovery.expiresAt), historical || date < expiry {
            if let warning = recovery.warning(stale: false) { item("RECOVERY RISK", warning) }
            if let reason = recovery.reasonLabel(stale: false) { item("RECOVERY", reason + " · " + (recovery.observedAt ?? "time unavailable")) }
        }
    }
}
