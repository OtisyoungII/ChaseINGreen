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

    private var size: PositionSizeBlock? {
        positionSize?.positionSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(size?.headline ?? "\(selectedSymbol) Position Size")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text(size?.summary ?? "Position size recommendation will appear after Trader OS and account context load.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(4)

            Divider()

            detailRow("Recommended", formattedSize(size?.recommendedSize))
            detailRow("Min Size", formattedSize(size?.minSize))
            detailRow("Max Size", formattedSize(size?.maxSize))
            detailRow("Risk %", percentDouble(size?.riskPercent))
            detailRow("Dollar Risk", money(size?.dollarRisk))
            detailRow("Profile", size?.sizeProfile ?? "--")
            detailRow("Instrument", size?.instrumentType ?? "--")
            detailRow("Trade Allowed", size?.tradeAllowed == true ? "YES" : "NO")
            detailRow("Confidence", percent(size?.confidence))
            detailRow("Risk Score", percent(size?.riskScore))

            warningsBlock
            actionsBlock
        }
    }

    @ViewBuilder
    private var warningsBlock: some View {
        if let warnings = size?.warnings, !warnings.isEmpty {
            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Warnings")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.softGold)

                ForEach(warnings.prefix(3), id: \.self) { warning in
                    Text("⚠️ \(warning)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
    }

    @ViewBuilder
    private var actionsBlock: some View {
        if let actions = size?.actions, !actions.isEmpty {
            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Actions")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.softGold)

                ForEach(actions.prefix(3), id: \.self) { action in
                    Text("• \(action)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
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
