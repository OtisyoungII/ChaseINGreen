import SwiftUI

struct MLLearningLabView: View {
    let accessToken: String

    @State private var lab: MLLearningLabResponse?
    @State private var isLoading = false
    @State private var isTraining = false
    @State private var isDemo = false
    @State private var errorMessage: String?
    @State private var trainingMessage: String?

    var body: some View {
        AppBackground {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Text("ML Learning Lab").font(.largeTitle.bold()).foregroundStyle(AppTheme.primaryText)
                    Text("Audit-only shadow learning. Learned opinions never change live recommendations, sizing, stops, or execution.")
                        .foregroundStyle(AppTheme.secondaryText)
                    Toggle("Use isolated demo data", isOn: $isDemo).tint(AppTheme.gold)
                    if isDemo { warning("Demo Data — Not Real Trading Results") }
                    if let errorMessage { warning(errorMessage) }
                    if let trainingMessage { Text(trainingMessage).font(.caption.bold()).foregroundStyle(AppTheme.softGold) }
                    if let lab {
                        summary(lab)
                        models(lab.models)
                        experience(lab.experience)
                        patterns(lab.patterns)
                        if !isDemo {
                            Button { Task { await train() } } label: {
                                Label(isTraining ? "Training…" : "Run Explicit Shadow Training", systemImage: "brain.filled.head.profile")
                                    .frame(maxWidth: .infinity).padding(12)
                            }
                            .buttonStyle(.borderedProminent).tint(AppTheme.gold).disabled(isTraining)
                        }
                    } else if isLoading {
                        ProgressView("Loading ML audit data…").tint(AppTheme.gold).frame(maxWidth: .infinity).padding(40)
                    }
                }.padding()
            }
        }
        .navigationTitle("ML Learning Lab")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await load() }
        .refreshable { await load() }
        .onChange(of: isDemo) { _, _ in Task { await load() } }
    }

    private func summary(_ data: MLLearningLabResponse) -> some View {
        card("Shadow Learning Status") {
            metric("Training Runs", data.summary.trainingRuns)
            metric("Shadow Models", data.summary.shadowModels)
            metric("Predictions Recorded", data.summary.shadowPredictions)
            metric("Predictions Evaluated", data.summary.evaluatedPredictions)
            if let run = data.latestRun {
                Divider().overlay(AppTheme.cardStroke)
                Text("Latest: \(run.status) · \(run.modelsProduced) models · \(run.evaluableSamples) evaluable samples")
                    .font(.caption).foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private func models(_ values: [MLLabModel]) -> some View {
        card("Model Registry") {
            if values.isEmpty { Text("No model has passed conservative sample guards.").foregroundStyle(AppTheme.secondaryText) }
            ForEach(values, id: \.stableID) { model in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(model.target) · \(model.horizon)").font(.headline).foregroundStyle(AppTheme.primaryText)
                    Text("\(model.modelType) · \(model.status) · n = \(model.sampleSize)")
                    Text("Balanced accuracy \(percent(model.balancedAccuracy)) · Macro F1 \(percent(model.macroF1)) · Brier \(number(model.brierScore))")
                }.font(.caption).foregroundStyle(AppTheme.secondaryText).padding(.vertical, 4)
            }
        }
    }

    private func experience(_ values: [String: Int]) -> some View {
        card("Historical Experience") {
            ForEach(["high", "moderate", "low", "novel"], id: \.self) { key in metric(key.capitalized, values[key] ?? 0) }
            Text("Experience measures historical similarity; it is intentionally separate from model confidence.")
                .font(.caption).foregroundStyle(AppTheme.secondaryText)
        }
    }

    private func patterns(_ values: [MLLabPattern]) -> some View {
        card("Learned Patterns") {
            if values.isEmpty { Text("No pattern has enough trustworthy observations yet.").foregroundStyle(AppTheme.secondaryText) }
            ForEach(values.prefix(20)) { pattern in
                Text("\(pattern.status.capitalized): \(pattern.target) · \(pattern.horizon) · n = \(pattern.sampleSize) · \(percent(pattern.confidence))")
                    .font(.caption).foregroundStyle(AppTheme.primaryText)
            }
        }
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) { Text(title).font(.title2.bold()).foregroundStyle(AppTheme.softGold); content() }
            .padding().frame(maxWidth: .infinity, alignment: .leading).background(AppTheme.cardBlack)
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(AppTheme.cardStroke) }.clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func metric(_ title: String, _ value: Int) -> some View {
        HStack { Text(title); Spacer(); Text("\(value)").fontWeight(.bold) }.foregroundStyle(AppTheme.primaryText)
    }

    private func warning(_ text: String) -> some View {
        Text(text).font(.caption.bold()).foregroundStyle(.orange).padding(10).frame(maxWidth: .infinity).background(Color.orange.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func percent(_ value: Double?) -> String { value.map { String(format: "%.1f%%", $0 * 100) } ?? "Unavailable" }
    private func number(_ value: Double?) -> String { value.map { String(format: "%.3f", $0) } ?? "Unavailable" }

    @MainActor private func load() async {
        isLoading = true; defer { isLoading = false }
        do { errorMessage = nil; lab = try await APIService.shared.fetchMLLearningLab(accessToken: accessToken, demo: isDemo) }
        catch { errorMessage = error.localizedDescription }
    }

    @MainActor private func train() async {
        isTraining = true; defer { isTraining = false }
        do {
            let result = try await APIService.shared.startMLTraining(accessToken: accessToken)
            trainingMessage = "\(result.status): \(result.modelsProduced) shadow models produced; production guidance unchanged."
            await load()
        } catch { errorMessage = error.localizedDescription }
    }
}
