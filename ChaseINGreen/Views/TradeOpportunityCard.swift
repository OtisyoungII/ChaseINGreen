import SwiftUI

struct TradeOpportunityCard: View {
    
    struct TradeOpportunityAPIResponse: Codable {
        let success: Bool
        let opportunity: TradeOpportunityResponse
    }
    
    let opportunity: TradeOpportunityResponse

    private var biasColor: Color {
        let value = opportunity.bias.lowercased()
        if value.contains("bull") || value.contains("long") || value.contains("call") { return .green }
        if value.contains("bear") || value.contains("short") || value.contains("put") { return .red }
        return AppTheme.gold
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trade Opportunity")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.secondaryText)

                    Text(opportunity.symbol)
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.primaryText)
                }

                Spacer()

                Text(opportunity.bias.uppercased())
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(biasColor.opacity(0.18))
                    .foregroundStyle(biasColor)
                    .clipShape(Capsule())
            }

            Text((opportunity.decision ?? opportunity.action).replacingOccurrences(of: "_", with: " ").uppercased())
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.softGold)

            HStack(spacing: 10) {
                miniMetric("Quality", opportunity.setupQuality.capitalized)
                miniMetric("Risk", opportunity.riskDisplay)
            }

            HStack(spacing: 10) {
                miniMetric("Probability", opportunity.probabilityPercent.map { "\($0)%" } ?? "Unavailable")
                miniMetric("Time", opportunity.timeDisplay)
            }

            Text(opportunity.runnerPotential ? "Runner potential active" : "No runner edge yet")
                .font(.caption.bold())
                .foregroundStyle(opportunity.runnerPotential ? .green : AppTheme.secondaryText)

            Text(opportunity.alertText)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            if !opportunity.reasoning.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reasoning")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.softGold)

                    ForEach(opportunity.reasoning, id: \.self) { item in
                        Text("• \(item)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.primaryText)
                    }
                }
            }

            if let needed = opportunity.dataNeeded, !needed.isEmpty {
                explanationBlock("Data Needed", needed, color: .orange)
            }
            if let waiting = opportunity.waitingFor, !waiting.isEmpty {
                explanationBlock("Waiting For", waiting, color: AppTheme.softGold)
            }
            if let passed = opportunity.passedGates, !passed.isEmpty {
                explanationBlock("Confirmed", passed, color: .green)
            }
            if let failed = opportunity.failedGates, !failed.isEmpty {
                explanationBlock("Blocking Entry", failed, color: .red)
            }
        }
        .padding()
        .background(AppTheme.cardBlack)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(biasColor.opacity(0.45), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func miniMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.secondaryText)

            Text(value)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.deepBlack.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func explanationBlock(_ title: String, _ values: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.bold()).foregroundStyle(color)
            ForEach(values, id: \.self) { value in
                Text("• \(value)").font(.caption).foregroundStyle(AppTheme.primaryText)
            }
        }
    }
}
