//
//  TimeframesWorkspaceCard.swift
//  ChaseINGreen
//
//  Created by Otis Young on 7/3/26.
//

import SwiftUI

struct TimeframesWorkspaceCard: View {
    let multiTimeframe: TraderOSMultiTimeframeBlock?
    let selectedSymbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(selectedSymbol) Timeframes")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.primaryText)

            if let mtf = multiTimeframe {
                timeframeRow("4H", mtf.trend4h)
                timeframeRow("1H", mtf.trend1h)
                timeframeRow("15M", mtf.trend15m)
                timeframeRow("5M", mtf.trend5m)
                timeframeRow("1M", mtf.trend1m)

                Divider()

                detailRow("Bias", mtf.entryBias ?? "waiting")
                detailRow("Alignment", "\(mtf.alignmentDirection ?? "mixed") \(mtf.alignmentScore ?? 0)%")
                detailRow("Long", mtf.longAllowed == true ? "YES" : "NO")
                detailRow("Short", mtf.shortAllowed == true ? "YES" : "NO")
                detailRow("Risk", percent(mtf.riskScore))
                detailRow("Confidence", percent(mtf.confidence))

                if let waitReason = mtf.waitReason, !waitReason.isEmpty {
                    note("Wait Reason", waitReason)
                }
            } else {
                Text("Multi-timeframe data not loaded yet.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private func timeframeRow(_ label: String, _ value: String?) -> some View {
        HStack {
            Text(label)
                .font(.caption.bold())
                .frame(width: 45, alignment: .leading)
                .foregroundStyle(AppTheme.secondaryText)

            Text(timeframeIcon(value))

            Text(value ?? "Unknown")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.primaryText)

            Spacer()
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

    private func note(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)

            Text(value)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(4)
        }
    }

    private func percent(_ value: Int?) -> String {
        guard let value else { return "--" }
        return "\(value)%"
    }

    private func timeframeIcon(_ value: String?) -> String {
        let clean = (value ?? "").lowercased()

        if clean.contains("bull") || clean.contains("up") || clean.contains("long") {
            return "🟢"
        }

        if clean.contains("bear") || clean.contains("down") || clean.contains("short") {
            return "🔴"
        }

        if clean.contains("wait") || clean.contains("mixed") || clean.contains("chop") {
            return "🟡"
        }

        return "⚪️"
    }
}
