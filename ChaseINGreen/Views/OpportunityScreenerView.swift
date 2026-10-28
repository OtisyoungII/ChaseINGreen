import SwiftUI

struct OpportunityScreenerView: View {
    let accessToken: String
    @Environment(\.scenePhase) private var scenePhase
    @State private var generation: ScreenerGeneration?
    @State private var asset = "ALL"
    @State private var direction = "BOTH"
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
                Section {
                    ForEach(generation.filtered(asset: asset, direction: direction)) { candidate in
                        if candidate.instrument.supportedNavigation {
                            NavigationLink {
                                MarketDetailView(requestSymbol: candidate.instrument.navigationSymbol,
                                    displayName: candidate.instrument.name,
                                    tradeSymbol: candidate.instrument.navigationSymbol,
                                    accessToken: accessToken, broker: candidate.instrument.provider,
                                    instrumentID: candidate.instrument.providerSymbol)
                            } label: {
                                TimelineView(.periodic(from: .now, by: 30)) { context in
                                    candidateRow(candidate, stale: failed || generation.isExpired(at: context.date))
                                }
                            }
                        }
                    }
                    if generation.filtered(asset: asset, direction: direction).isEmpty {
                        Text("No candidates match these filters.").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("\(generation.rankedCount) ranked · \(generation.universeCount) instruments")
                } footer: {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        Text(failed || generation.isExpired(at: context.date)
                             ? "Previous generation · stale. Pull to check for a completed update."
                             : "Bounded discovery universe · partial evidence coverage. Scores are not win probabilities.")
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
        .task { if generation == nil { await load() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await load() } }
        }
    }

    private func candidateRow(_ candidate: ScreenerCandidate, stale: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(stale || candidate.freshness != "fresh" ? "—" : candidate.score.map { String(format: "%.0f", $0) } ?? "—")
                    .font(.title2.monospacedDigit()).frame(minWidth: 42, alignment: .leading)
                Text(candidate.instrument.symbol).font(.headline)
            }
            Text("\(candidate.direction) · \(stale ? "WATCH · STALE" : candidate.state)")
                .font(.subheadline.weight(.semibold))
            Text(candidate.instrument.name).font(.caption).foregroundStyle(.secondary)
            ForEach(candidate.displayReasons(stale: stale), id: \.self) { reason in
                Text(reason).font(.caption).foregroundStyle(.secondary)
            }
            if let note = candidate.instrument.identityNote {
                Text(note).font(.caption2).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 5)
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
