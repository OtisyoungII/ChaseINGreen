//
//  MLInsightsCard.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import SwiftUI

struct MLInsightsCard: View {
    let memory: TraderMemoryResponse?
    let patterns: PatternDiscoveryResponse?
    let profile: TraderProfileResponse?
    let calendar: TradingCalendarReportResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            metricRow(
                leftTitle: "Discipline",
                leftValue: score(profile?.disciplineScore),
                rightTitle: "Consistency",
                rightValue: score(profile?.consistencyScore)
            )

            metricRow(
                leftTitle: "Confidence",
                leftValue: score(profile?.confidenceScore),
                rightTitle: "Trader Type",
                rightValue: profile?.traderType ?? "--"
            )

            metricRow(
                leftTitle: "Strongest Pattern",
                leftValue: patterns?.strongestPatternKey ?? "--",
                rightTitle: "Weakest Pattern",
                rightValue: patterns?.weakestPatternKey ?? "--"
            )

            metricRow(
                leftTitle: "Green Days",
                leftValue: "\(calendar?.greenDays ?? 0)",
                rightTitle: "Red Days",
                rightValue: "\(calendar?.redDays ?? 0)"
            )

            if let summary = profile?.summary ?? memory?.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(4)
            }

            if let direction = profile?.preferredDirection {
                insight("Direction", direction)
            }

            if let symbol = profile?.preferredSymbol {
                insight("Preferred Symbol", symbol)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var header: some View {
        HStack {
            Label("ML Insights", systemImage: "brain.head.profile")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.softGold)

            Spacer()

            Text("Personal AI")
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.gold)
        }
    }

    private func metricRow(
        leftTitle: String,
        leftValue: String,
        rightTitle: String,
        rightValue: String
    ) -> some View {
        HStack(spacing: 12) {
            metric(leftTitle, leftValue)
            metric(rightTitle, rightValue)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.secondaryText)

            Text(value)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func insight(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)

            Text(text)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private func score(_ value: Int?) -> String {
        guard let value else { return "--" }
        return "\(value)/100"
    }
}
