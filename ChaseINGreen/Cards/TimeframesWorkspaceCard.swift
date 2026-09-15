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
                if let m = mtf.mechanics, m.version == "market_mechanics_v1" {
                    ForEach(m.timeframes ?? [], id: \.timeframe) { frame in
                        timeframeRow(frame.timeframe.uppercased(), frame.direction)
                        if let reason = frame.mixed_reason { note("Evidence", readable(reason)) }
                        detailRow("Source / finality", "\(frame.source ?? "unknown") / \(frame.finality ?? "unknown")")
                    }
                    detailRow("Primary structure", readable(m.primary_directional_structure))
                    detailRow("Path pressure", readable(m.path_pressure))
                    detailRow("Entry safety", readable(m.entry_safety))
                    detailRow("Thesis health", readable(m.thesis_health))
                    detailRow("Propagation", readable(m.propagation?.status))
                    detailRow("Long permission", m.long_permission == true ? "Eligible" : "Blocked / unconfirmed")
                    detailRow("Short permission", m.short_permission == true ? "Eligible" : "Blocked / unconfirmed")
                    detailRow("Data quality", readable(m.confidence?.data_quality))
                    detailRow("Data confidence", m.confidence?.data_confidence.map { "\(Int($0))%" } ?? "Unavailable")
                    detailRow("Analysis confidence", "Not calibrated")
                    detailRow("Decision authority", readable(m.confidence?.decision_authority))
                    if let reasons = m.wait_reason_codes, !reasons.isEmpty {
                        note("Wait / block reasons", reasons.map { readable($0) }.joined(separator: "; "))
                    }
                } else {
                timeframeRow("4H", mtf.trend4h)
                timeframeRow("1H", mtf.trend1h)
                timeframeRow("15M", mtf.trend15m)
                timeframeRow("5M", mtf.trend5m)
                timeframeRow("1M", mtf.trend1m)

                Divider()

                detailRow("Bias", mtf.entryBias ?? "waiting")
                detailRow("Legacy alignment score", "\(mtf.alignmentDirection ?? "mixed") \(MarketScorePresentation.text(mtf.availableAlignmentScore))")
                detailRow("Long", mtf.longAllowed == true ? "YES" : "NO")
                detailRow("Short", mtf.shortAllowed == true ? "YES" : "NO")
                detailRow("Risk", percent(mtf.availableRiskScore))
                detailRow("Legacy analysis score", percent(mtf.availableConfidence))

                if let waitReason = mtf.waitReason, !waitReason.isEmpty {
                    note("Wait Reason", waitReason)
                }
                }
            } else {
                Text("Multi-timeframe data not loaded yet.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private func readable(_ value: String?) -> String {
        (value ?? "unknown").replacingOccurrences(of: "_", with: " ").capitalized
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
