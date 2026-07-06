//
//  PortfolioSummaryPanel.swift
//  ChaseINGreen
//
//  By: Otis Young II
// --------------------------------------------------------------
// ✅ Unified Portfolio Summary
// ✅ Bat Cave dashboard overview
// ✅ Shows equity, buying power, P/L and connected accounts
// ✅ Used for All Accounts and individual accounts
// --------------------------------------------------------------

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
                        title: "Total Equity",
                        value: portfolio.totalEquity.currency,
                        icon: "dollarsign.circle.fill",
                        color: .green
                    )

                    statCard(
                        title: "Buying Power",
                        value: portfolio.buyingPower.currency,
                        icon: "creditcard.fill",
                        color: .blue
                    )

                    statCard(
                        title: "Open P/L",
                        value: portfolio.openPnL.currency,
                        icon: "chart.line.uptrend.xyaxis",
                        color: portfolio.openPnL >= 0 ? .green : .red
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
                        "\(portfolio.positions.count) Open Positions",
                        systemImage: "briefcase.fill"
                    )

                    Label(
                        "\(portfolio.accounts.count) Connected Brokers",
                        systemImage: "link.circle.fill"
                    )

                    Label(
                        portfolio.lastUpdated,
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

    @ViewBuilder
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
        formatted(
            .currency(code: "USD")
        )
    }
}
