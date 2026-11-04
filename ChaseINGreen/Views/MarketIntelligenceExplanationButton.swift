import SwiftUI

struct MarketIntelligenceExplanationButton: View {
    let identifier: String
    let context: MarketIntelligenceEducation.Context?
    @State private var isPresented = false

    var body: some View {
        if let explanation = MarketIntelligenceEducation.explanation(for: identifier) {
            Button { isPresented = true } label: {
                Image(systemName: "info.circle")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.softGold)
            .accessibilityLabel("About \(explanation.displayName)")
            .accessibilityHint("Shows an educational explanation of this market observation")
            .sheet(isPresented: $isPresented) {
                explanationSheet(explanation)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func explanationSheet(_ explanation: MarketIntelligenceEducation) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("What it is", explanation.definition)
                    section("What it usually represents", explanation.typicalInterpretation)
                    if let why = context?.whyItMattersHere { section("Why it matters here", why) }
                    if let confirmation = explanation.confirmation { section("What would confirm it", confirmation) }
                    if let invalidation = explanation.invalidation { section("What would weaken it", invalidation) }
                    section("Important", explanation.caution)
                }
                .padding()
            }
            .background(AppTheme.deepBlack)
            .navigationTitle(explanation.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { isPresented = false } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.caption.bold()).foregroundStyle(AppTheme.softGold)
            Text(text).font(.body).foregroundStyle(AppTheme.primaryText).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
