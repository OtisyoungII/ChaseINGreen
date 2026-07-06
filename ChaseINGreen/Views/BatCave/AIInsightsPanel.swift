//
//  AIInsightsPanel.swift
//  ChaseINGreen
//
//  By: Otis Young II
//

import SwiftUI

struct AIInsightsPanel: View {

    let traderOS: TraderOSResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(AppTheme.softGold)

                Text("Trader Brain")
                    .font(.title2.bold())

                Spacer()
            }

            if let traderOS {
                insightCard(
                    title: "Recommendation",
                    value: recommendationText(traderOS),
                    color: recommendationColor(recommendationText(traderOS))
                )

                HStack(spacing: 16) {
                    metric("Confidence", "\(confidenceValue(traderOS))%")
                    metric("Probability", "\(probabilityValue(traderOS))%")
                }

                HStack(spacing: 16) {
                    metric("Risk", "\(riskValue(traderOS))")
                    metric("Market", traderOS.marketState?.phase ?? traderOS.status ?? "Unknown")
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        traderOS.ai?.headline
                        ?? traderOS.decision?.title
                        ?? traderOS.headline
                        ?? "Trader Brain Ready",
                        systemImage: "lightbulb.fill"
                    )

                    Text(
                        traderOS.ai?.summary
                        ?? traderOS.decision?.explanation
                        ?? traderOS.summary
                        ?? "Run TraderOS to generate updated guidance."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

            } else {
                ContentUnavailableView(
                    "Trader Brain Offline",
                    systemImage: "brain",
                    description: Text("Run TraderOS to generate AI guidance.")
                )
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func recommendationText(_ os: TraderOSResponse) -> String {
        os.ai?.finalRecommendation
        ?? os.decision?.decision
        ?? os.executionPlan?.side
        ?? os.status
        ?? "WAIT"
    }

    private func confidenceValue(_ os: TraderOSResponse) -> Int {
        os.ai?.confidence
        ?? os.decision?.confidence
        ?? os.executionPlan?.confidence
        ?? os.probability?.bestProbability
        ?? os.quoteConfidence
        ?? 0
    }

    private func probabilityValue(_ os: TraderOSResponse) -> Int {
        os.probability?.bestProbability
        ?? os.ai?.confidence
        ?? os.decision?.confidence
        ?? 0
    }

    private func riskValue(_ os: TraderOSResponse) -> Int {
        os.ai?.riskScore
        ?? os.marketState?.riskScore
        ?? os.executionPlan?.riskScore
        ?? 0
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func insightCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func recommendationColor(_ value: String) -> Color {
        let clean = value.uppercased()

        if clean.contains("BUY") || clean.contains("LONG") || clean.contains("CALL") {
            return .green
        }

        if clean.contains("SELL") || clean.contains("SHORT") || clean.contains("PUT") {
            return .red
        }

        if clean.contains("WAIT") || clean.contains("AVOID") {
            return .orange
        }

        return AppTheme.softGold
    }
}
