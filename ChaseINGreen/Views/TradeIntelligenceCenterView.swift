import SwiftUI

struct TradeIntelligenceCenterView: View {
    let accessToken: String

    @State private var intelligence: TradeIntelligenceResponse?
    @State private var isLoading = false
    @State private var isDemo = false
    @State private var errorMessage: String?
    @State private var selectedDimension = "utc_hour"

    private let dimensions = [
        "utc_hour", "session", "day_of_week", "symbol", "direction",
        "recommendation_type", "timeframe", "market_regime", "broker_category",
        "volume_state",
    ]

    var body: some View {
        AppBackground {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    header
                    if let intelligence {
                        learningStatus(intelligence)
                        outcomeSection(intelligence)
                        movementSection(intelligence)
                        contextSection(intelligence)
                        failureSection(intelligence)
                        readinessSection(intelligence)
                    } else if isLoading {
                        ProgressView("Loading aggregate intelligence…")
                            .tint(AppTheme.gold)
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        infoCard("No intelligence data is available yet. Real recommendations will appear here as follow-up observations accumulate.")
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Trade Intelligence")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await load() }
        .refreshable { await load() }
        .onChange(of: isDemo) { _, _ in Task { await load() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trade Intelligence Center")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.primaryText)
            Text("Internal aggregate evidence for understanding recommendations and their observed outcomes. Nothing here changes live trading guidance.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            Toggle("Use clearly labeled demo data", isOn: $isDemo)
                .tint(AppTheme.gold)
                .foregroundStyle(AppTheme.primaryText)
            if isDemo {
                Text("Demo Data — Not Real Trading Results")
                    .font(.headline.bold())
                    .foregroundStyle(.black)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }
        }
    }

    private func learningStatus(_ data: TradeIntelligenceResponse) -> some View {
        let status = data.learningStatus
        return section("Learning Status") {
            metricGrid([
                ("Recommendations Recorded", status.recommendationsRecorded),
                ("Price Observations", status.priceObservations),
                ("Evaluated Recommendations", status.evaluatedRecommendations),
                ("Awaiting Follow-Up", status.awaitingFollowUp),
                ("Sufficient Follow-Up", status.sufficientFollowUp),
                ("Insufficient Data", status.insufficientData),
                ("Actionable Recommendations", status.actionableRecommendations),
                ("Recorded Response Fields", status.userResponsesCaptured),
                ("Closed Outcomes", status.closedOutcomes),
            ])
            Text("Recorded response fields are ledger metadata. They do not by themselves prove that a person opened an alert, submitted a trade, or received a broker fill.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            ratioRow("Observation Coverage", status.observationCoverage)
            dateRow("First Intelligence Event", status.firstIntelligenceEvent)
            dateRow("Latest Intelligence Event", status.latestIntelligenceEvent)
        }
    }

    private func outcomeSection(_ data: TradeIntelligenceResponse) -> some View {
        section("Recommendation Outcomes") {
            Text("Every rate includes its observed sample size. These are not presented as prediction accuracy.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            ForEach(["helped", "hurt", "mixed", "ambiguous", "insufficient_data", "not_actionable"], id: \.self) { key in
                if let result = data.recommendationPerformance.results[key] {
                    resultRow(label(key), result)
                }
            }
        }
    }

    private func movementSection(_ data: TradeIntelligenceResponse) -> some View {
        let movement = data.postRecommendationMovement
        return section("Price Behavior") {
            valueRow("Best Move After Recommendation", movement.bestMoveAfterRecommendation.averageProfitReached, prefix: "$")
            timeRow("Average Time to Best Move", movement.bestMoveAfterRecommendation.averageTimeSeconds)
            valueRow("Worst Pullback After Recommendation", movement.worstMoveAfterRecommendation.averagePullbackPnl, prefix: "$")
            timeRow("Average Time to Worst Move", movement.worstMoveAfterRecommendation.averageTimeSeconds)
            ratioRow("Recovery Rate", movement.recovery)
            ratioRow("Continuation Rate", movement.continuation)
            ratioRow("Entry-Loss Recovery Rate", movement.entryLossRecovery)
            ratioRow("Profit-Loss Recovery Rate", movement.profitLossRecovery)
            ratioRow("New Favorable Extreme Rate", movement.newFavorableExtreme)
        }
    }

    private func contextSection(_ data: TradeIntelligenceResponse) -> some View {
        section("Market Context") {
            Picker("Breakdown", selection: $selectedDimension) {
                ForEach(dimensions, id: \.self) { Text(label($0)).tag($0) }
            }
            .pickerStyle(.menu)
            if let groups = data.grouped[selectedDimension], !groups.isEmpty {
                ForEach(groups.keys.sorted(), id: \.self) { key in
                    if let group = groups[key] {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(key).font(.headline).foregroundStyle(AppTheme.primaryText)
                            Text("Recommendations: \(group.sampleSize) · Helped: \(group.results["helped"]?.count ?? 0) · Hurt: \(group.results["hurt"]?.count ?? 0) · Mixed: \(group.results["mixed"]?.count ?? 0)")
                            Text("Observed Help Rate: \(percent(group.observedHelpRate)) · Recovery Rate: \(percent(group.movement.recovery.percentage))")
                        }
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.vertical, 5)
                    }
                }
            } else {
                Text("Insufficient observations for this breakdown.")
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private func failureSection(_ data: TradeIntelligenceResponse) -> some View {
        section("Failure & Weakness Evidence") {
            if data.failureReasons.isEmpty {
                Text("No supported failure reason can be assigned yet.")
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                ForEach(data.failureReasons.keys.sorted(), id: \.self) { key in
                    if let ratio = data.failureReasons[key] { ratioRow(label(key), ratio) }
                }
            }
        }
    }

    private func readinessSection(_ data: TradeIntelligenceResponse) -> some View {
        let readiness = data.mlReadiness
        return section("Dataset Readiness") {
            Text(readiness.state)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.softGold)
            Text("Observational only · Production ML disabled")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.secondaryText)
            metricGrid([
                ("Evaluable Events", readiness.dataset.evaluableEvents),
                ("Distinct Symbols", readiness.dataset.distinctSymbols),
                ("Directions", readiness.dataset.distinctDirections),
                ("Recommendation Types", readiness.dataset.distinctRecommendationTypes),
                ("Market Regimes", readiness.dataset.distinctMarketRegimes),
                ("Sessions", readiness.dataset.distinctSessions),
            ])
            ForEach(readiness.dataset.horizonCompleteness.keys.sorted(), id: \.self) { horizon in
                if let ratio = readiness.dataset.horizonCompleteness[horizon] {
                    ratioRow("Complete \(horizon) Outcomes", ratio)
                }
            }
            ForEach(readiness.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title2.bold()).foregroundStyle(AppTheme.softGold)
            content()
        }
        .padding()
        .background(AppTheme.cardBlack)
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(AppTheme.cardStroke) }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func metricGrid(_ values: [(String, Int)]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.0).font(.caption).foregroundStyle(AppTheme.secondaryText)
                    Text("\(item.1)").font(.title3.bold()).foregroundStyle(AppTheme.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func ratioRow(_ title: String, _ ratio: IntelligenceRatio) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(percent(ratio.percentage)) · n = \(ratio.denominator)")
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .foregroundStyle(AppTheme.primaryText)
    }

    private func resultRow(_ title: String, _ result: IntelligenceResult) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(percent(result.percentage)) · n = \(result.count)")
        }
        .foregroundStyle(AppTheme.primaryText)
    }

    private func valueRow(_ title: String, _ value: Double?, prefix: String = "") -> some View {
        HStack { Text(title); Spacer(); Text(value.map { "\(prefix)\(String(format: "%.2f", $0))" } ?? "Unavailable") }
            .foregroundStyle(AppTheme.primaryText)
    }

    private func timeRow(_ title: String, _ seconds: Double?) -> some View {
        HStack { Text(title); Spacer(); Text(seconds.map { "\(Int($0 / 60)) min" } ?? "Unavailable") }
            .foregroundStyle(AppTheme.primaryText)
    }

    private func dateRow(_ title: String, _ value: String?) -> some View {
        HStack { Text(title); Spacer(); Text(value.map { String($0.prefix(10)) } ?? "Not available") }
            .font(.caption).foregroundStyle(AppTheme.secondaryText)
    }

    private func infoCard(_ text: String) -> some View {
        Text(text).foregroundStyle(AppTheme.secondaryText).padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBlack).clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func percent(_ value: Double?) -> String {
        value.map { String(format: "%.1f%%", $0) } ?? "Unavailable"
    }

    private func label(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ").map { $0.capitalized }.joined(separator: " ")
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            errorMessage = nil
            intelligence = try await APIService.shared.fetchTradeIntelligence(
                accessToken: accessToken,
                demo: isDemo
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
