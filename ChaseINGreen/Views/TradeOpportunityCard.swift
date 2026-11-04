import SwiftUI

struct TradeOpportunityCard: View {
    
    struct TradeOpportunityAPIResponse: Codable {
        let success: Bool
        let opportunity: TradeOpportunityResponse
    }
    
    let opportunity: TradeOpportunityResponse

    private var signal: TradeOpportunitySignalPresentation? {
        opportunity.signalPresentation
    }

    private var structuralThesis: String {
        CustomerPresentation.direction(signal?.structuralThesis ?? opportunity.bias)
    }

    private var readinessText: String {
        switch signal?.tradeReadiness.lowercased() {
        case "ready": return "READY"
        case "no_trade": return "NO TRADE"
        default: return "WAIT"
        }
    }

    private var readinessColor: Color {
        switch signal?.tradeReadiness.lowercased() {
        case "ready" where signal?.allowsAuthoritativeDirection == true: return .green
        case "no_trade": return .red
        default: return AppTheme.softGold
        }
    }

    private var biasColor: Color {
        guard signal?.allowsAuthoritativeDirection == true else { return AppTheme.secondaryText }
        let value = (signal?.structuralThesis ?? opportunity.bias).lowercased()
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

                Text("STRUCTURAL BIAS: \(structuralThesis.uppercased())")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(biasColor.opacity(0.18))
                    .foregroundStyle(biasColor)
                    .clipShape(Capsule())
            }

            Text(readinessText)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(readinessColor)

            Text(CustomerPresentation.tradeDecision(opportunity.decision ?? opportunity.action))
                .font(.caption.bold())
                .foregroundStyle(AppTheme.secondaryText)

            HStack(spacing: 10) {
                miniMetric("Current Pressure", pressureText)
                miniMetric("Thesis Condition", thesisConditionText)
            }

            HStack(spacing: 10) {
                miniMetric("Confirmation", confirmationText)
                miniMetric("Structural Bias", structuralThesis)
            }

            if let provenanceText {
                Text(provenanceText)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            HStack(spacing: 10) {
                miniMetric("Quality", opportunity.setupQuality.capitalized)
                miniMetric("Risk", opportunity.riskDisplay)
            }

            HStack(spacing: 10) {
                miniMetric("Confidence", opportunity.confidencePercent.map { "\($0)%" } ?? "Unavailable")
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

                    ForEach(Array(opportunity.reasoning.enumerated()), id: \.offset) { _, item in
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
                .stroke(readinessColor.opacity(0.55), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var pressureText: String {
        switch signal?.currentPressure.lowercased() {
        case "strong_selling": return "Strong Selling"
        case "selling": return "Selling"
        case "buying": return "Buying"
        case "strong_buying": return "Strong Buying"
        default: return "Balanced"
        }
    }

    private var thesisConditionText: String {
        switch signal?.thesisCondition.lowercased() {
        case "strengthening": return "Strengthening"
        case "under_pressure": return "Under Pressure"
        case "at_risk": return "At Risk"
        case "invalidated": return "Invalidated"
        default: return "Intact"
        }
    }

    private var confirmationText: String {
        switch signal?.evidenceConfirmation.lowercased() {
        case "confirmed": return "Confirmed"
        case "developing": return "Developing"
        case "stale_or_degraded": return "Stale / Degraded"
        default: return "Insufficient"
        }
    }

    private var provenanceText: String? {
        var parts: [String] = []
        if let provider = signal?.quoteProvider, !provider.isEmpty {
            parts.append("Quote: \(provider.capitalized)")
        }
        if let providers = signal?.candleProviders, !providers.isEmpty {
            parts.append("Candles: \(providers.map(\.capitalized).joined(separator: ", "))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
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
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Text("• \(value)").font(.caption).foregroundStyle(AppTheme.primaryText)
            }
        }
    }
}
