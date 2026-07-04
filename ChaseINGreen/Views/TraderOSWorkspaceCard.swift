//
//  TraderOSWorkspaceCard.swift
//  ChaseINGreen
//
//  Created by Otis Young on 7/2/26.
//

import SwiftUI

struct TraderOSWorkspaceCard: View {
    let traderOS: TraderOSResponse?
    let selectedSymbol: String

    private var ai: TraderOSAIBlock? {
        traderOS?.ai
    }

    private var decision: TraderOSDecisionBlock? {
        traderOS?.decision
    }

    private var executionPlan: TraderOSExecutionPlanBlock? {
        traderOS?.executionPlan
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(traderOS?.headline ?? "\(selectedSymbol) Trader OS waiting for signal.")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text(traderOS?.summary ?? "No AI summary loaded yet.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(4)

            Divider()

            detailRow("Decision", ai?.finalRecommendation ?? decision?.decision ?? "waiting")
            detailRow("Confidence", percent(ai?.confidence ?? decision?.confidence))
            detailRow("Risk", percent(ai?.riskScore ?? executionPlan?.riskScore))
            detailRow("Reward", percent(ai?.rewardScore))
            detailRow("Urgency", ai?.waitUrgency ?? decision?.urgency ?? executionPlan?.priority ?? "normal")

            if let executionPlan {
                Divider()

                detailRow("Should Trade", executionPlan.shouldTrade == true ? "YES" : "NO")
                detailRow("Side", executionPlan.side ?? "--")
                detailRow("Style", executionPlan.executionStyle ?? "--")
                detailRow("Size", executionPlan.sizeProfile ?? "--")

                if let entry = executionPlan.entryCondition {
                    note("Entry", entry)
                }

                if let target = executionPlan.targetPlan {
                    note("Target", target)
                }

                if let stop = executionPlan.stopPlan {
                    note("Stop", stop)
                }

                executionLevelsBlock(executionPlan)
            }

            warningsBlock
            actionsBlock
        }
    }

    @ViewBuilder
    private func executionLevelsBlock(_ plan: TraderOSExecutionPlanBlock) -> some View {
        Divider()

        VStack(alignment: .leading, spacing: 6) {
            Text("Execution Levels")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)

            detailRow(plan.beginnerSupportLabel ?? "Support Zone", priceRange(plan.supportZoneLow, plan.supportZoneHigh))
            detailRow(plan.beginnerResistanceLabel ?? "Resistance Zone", priceRange(plan.resistanceZoneLow, plan.resistanceZoneHigh))
            detailRow(plan.beginnerBreakoutLabel ?? "Breakout Above", money(plan.breakoutAbove))
            detailRow(plan.beginnerBreakdownLabel ?? "Breakdown Below", money(plan.breakdownBelow))

            detailRow("Long Stop Idea", money(plan.longStopIdea))
            detailRow("Short Stop Idea", money(plan.shortStopIdea))
            detailRow("Long Targets", targetPair(plan.longProfitTarget1, plan.longProfitTarget2))
            detailRow("Short Targets", targetPair(plan.shortProfitTarget1, plan.shortProfitTarget2))

            if let noteText = plan.executionNote {
                note("Level Note", noteText)
            }
        }
    }

    @ViewBuilder
    private var warningsBlock: some View {
        if let warnings = executionPlan?.warnings ?? traderOS?.warnings, !warnings.isEmpty {
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
        if let actions = executionPlan?.actions ?? traderOS?.actions, !actions.isEmpty {
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

    private func note(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)

            Text(value)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(3)
        }
    }

    private func percent(_ value: Int?) -> String {
        guard let value else { return "--" }
        return "\(value)%"
    }

    private func money(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "$%.2f", value)
    }

    private func priceRange(_ low: Double?, _ high: Double?) -> String {
        guard let low, let high else { return "--" }
        return "\(money(low)) - \(money(high))"
    }

    private func targetPair(_ first: Double?, _ second: Double?) -> String {
        guard first != nil || second != nil else { return "--" }
        return "\(money(first)) / \(money(second))"
    }
}
