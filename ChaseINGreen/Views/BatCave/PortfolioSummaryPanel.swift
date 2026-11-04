//
//  PortfolioSummaryPanel.swift
//  ChaseINGreen
//
//  By: Otis Young II
//

import SwiftUI

struct PortfolioSummaryPanel: View {

    let portfolio: UnifiedPortfolioResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Portfolio Summary")
                .font(.title2.bold())

            if let portfolio {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 16
                ) {
                    statCard(
                        title: "Last-reported Equity",
                        value: portfolio.canonicalTruth?.display("equity") ?? "Unavailable",
                        icon: "dollarsign.circle.fill",
                        color: .green
                    )

                    statCard(
                        title: "Last-reported Buying Power",
                        value: portfolio.canonicalTruth?.display("buying_power") ?? "Unavailable",
                        icon: "creditcard.fill",
                        color: .blue
                    )

                    statCard(
                        title: "Last-reported P/L",
                        value: portfolio.canonicalTruth?.display("total_pnl") ?? "Unavailable",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .primary
                    )

                    statCard(
                        title: "Accounts",
                        value: "\(portfolio.accounts.count)",
                        icon: "person.3.fill",
                        color: .orange
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        "\(portfolio.accounts.count) Connected Accounts",
                        systemImage: "briefcase.fill"
                    )

                    Label(
                        portfolio.headline,
                        systemImage: "link.circle.fill"
                    )

                    Label(
                        "Cached portfolio",
                        systemImage: "clock.fill"
                    )
                }
                .font(.subheadline)

            } else {
                ContentUnavailableView(
                    "No Portfolio Loaded",
                    systemImage: "chart.bar.doc.horizontal",
                    description: Text("Connect a broker or select an account.")
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func statCard(
        title: String,
        value: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private extension Double {
    var currency: String {
        formatted(.currency(code: "USD"))
    }
}
