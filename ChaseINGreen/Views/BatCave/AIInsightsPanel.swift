//
//  AIInsightsPanel.swift
//  ChaseINGreen
//
//  By: Otis Young II
// --------------------------------------------------------------
// ✅ Trader Brain Panel
// ✅ Displays AI summary
// ✅ Market state
// ✅ Probability
// ✅ Risk
// ✅ Recommendation
// ✅ Confidence
// --------------------------------------------------------------

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
                    value: traderOS.recommendation,
                    color: recommendationColor(traderOS.recommendation)
                )

                HStack(spacing: 16) {

                    metric(
                        "Confidence",
                        "\(traderOS.confidence)%"
                    )

                    metric(
                        "Probability",
                        "\(traderOS.bestProbability)%"
                    )
                }

                HStack(spacing: 16) {

                    metric(
                        "Risk",
                        "\(traderOS.riskScore)"
                    )

                    metric(
                        "Market",
                        traderOS.marketState
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {

                    Label(traderOS.headline, systemImage: "lightbulb.fill")

                    Text(traderOS.summary)
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

    @ViewBuilder
    private func metric(
        _ title: String,
        _ value: String
    ) -> some View {

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

    @ViewBuilder
    private func insightCard(
        title: String,
        value: String,
        color: Color
    ) -> some View {

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

        switch value.uppercased() {

        case "BUY":
            return .green

        case "SELL":
            return .red

        case "WAIT":
            return .orange

        default:
            return AppTheme.softGold
        }
    }
}
