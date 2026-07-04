//
//  PositionSizeWorkspaceCard.swift
//  ChaseINGreen
//
//  Created by Otis Young on 7/4/26.
//

import SwiftUI

struct PositionSizeWorkspaceCard: View {
    let positionSize: PositionSizeResponse?
    let selectedSymbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(selectedSymbol) Position Size")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text(positionSize?.summary ?? "Position size recommendation will appear after Trader OS and account context load.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(4)

            Divider()

            detailRow("Recommended", formattedSize(positionSize?.recommendedSize))
            detailRow("Min Size", formattedSize(positionSize?.minSize))
            detailRow("Max Size", formattedSize(positionSize?.maxSize))
            detailRow("Risk %", percentDouble(positionSize?.riskPercent))
            detailRow("Dollar Risk", money(positionSize?.dollarRisk))
            detailRow("Profile", positionSize?.sizeProfile ?? "--")
            detailRow("Instrument", positionSize?.instrumentType ?? "--")
            detailRow("Trade Allowed", positionSize?.tradeAllowed == true ? "YES" : "NO")
            detailRow("Confidence", percent(positionSize?.confidence))
            detailRow("Risk Score", percent(positionSize?.riskScore))
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

    private func formattedSize(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.4f", value)
    }

    private func percent(_ value: Int?) -> String {
        guard let value else { return "--" }
        return "\(value)%"
    }

    private func percentDouble(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f%%", value)
    }

    private func money(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "$%.2f", value)
    }
}
