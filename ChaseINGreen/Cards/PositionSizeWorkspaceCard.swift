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

            detailRow("Current Size", formattedSize(size?.currentPositionSize))
            detailRow("Exposure", exposureLabel(size?.exposureStatus))
            detailRow("New Size", formattedSize(size?.recommendedSize))
            detailRow("Min Size", formattedSize(size?.minSize))
            detailRow("Max Size", formattedSize(size?.maxSize))
            detailRow("Risk %", percentDouble(size?.riskPercent))
            detailRow("Dollar Risk", money(size?.dollarRisk))
            detailRow("Profile", size?.sizeProfile ?? "--")
            detailRow("Instrument", size?.instrumentType ?? "--")
            detailRow("Trade Allowed", size?.tradeAllowed == true ? "YES" : "NO")
            detailRow("Confidence", percent(size?.confidence))
            detailRow("Risk Score", percent(size?.riskScore))

            if let exposureSummary = size?.exposureSummary {
                Text(exposureSummary)
                    .font(.caption2.bold())
                    .foregroundStyle(exposureColor(size?.exposureStatus))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let warnings = size?.warnings, !warnings.isEmpty {
                Divider()
                sectionList(title: "Warnings", prefix: "⚠️", rows: warnings)
            }

            if let actions = size?.actions, !actions.isEmpty {
                Divider()
                sectionList(title: "Actions", prefix: "•", rows: actions)
            }

            
        }
    }

    private func sectionList(title: String, prefix: String, rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)

            ForEach(rows.prefix(3), id: \.self) { row in
                Text("\(prefix) \(row)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
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

    private func exposureLabel(_ value: String?) -> String {
        switch value {
        case "oversized": return "TOO LARGE"
        case "below_current_cap": return "BELOW CAP"
        case "within_current_cap": return "IN RANGE"
        case "manage_only": return "MANAGE ONLY"
        default: return "NO LIVE POSITION"
        }
    }

    private func exposureColor(_ value: String?) -> Color {
        switch value {
        case "oversized": return .red
        case "within_current_cap": return .green
        case "below_current_cap": return .orange
        default: return AppTheme.secondaryText
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

    private func splitPipe(_ value: String?) -> [String]? {
        guard let value, !value.isEmpty else { return nil }

        return value
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
