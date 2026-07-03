//
//  QuoteSourceWorkspaceCard.swift
//  ChaseINGreen
//
//  Created by Otis Young on 7/3/26.
//

import SwiftUI

struct QuoteSourceWorkspaceCard: View {
    let quote: TraderOSQuoteResolutionBlock?
    let selectedSymbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(quote?.symbol ?? selectedSymbol)
                .font(.headline.bold())
                .foregroundStyle(AppTheme.primaryText)

            detailRow("Price", formatPrice(quote?.price))
            detailRow("Bid", formatPrice(quote?.bid))
            detailRow("Ask", formatPrice(quote?.ask))
            detailRow("Provider", quote?.provider ?? "unknown")
            detailRow("Broker", quote?.broker ?? "none")
            detailRow("Freshness", quote?.freshness ?? "unknown")
            detailRow("Confidence", percent(quote?.confidence))

            if let warning = quote?.warning, !warning.isEmpty {
                Divider()

                Text("⚠️ \(warning)")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.softGold)
            }
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            Spacer()

            Text(value)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.primaryText)
        }
    }

    private func formatPrice(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f", value)
    }

    private func percent(_ value: Int?) -> String {
        guard let value else { return "--" }
        return "\(value)%"
    }
}
