//
//  PreTradeContextCard.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/11/26.
//

import SwiftUI

struct PreTradeContextCard: View {
    let context: PreTradeContextResponse
    let isLoading: Bool
    let errorMessage: String?
    let showAdvancedLevels: Bool
    let showActions: Bool
    let onRefresh: () -> Void

    init(
        context: PreTradeContextResponse,
        isLoading: Bool,
        errorMessage: String?,
        showAdvancedLevels: Bool = false,
        showActions: Bool = false,
        onRefresh: @escaping () -> Void
    ) {
        self.context = context
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.showAdvancedLevels = showAdvancedLevels
        self.showActions = showActions
        self.onRefresh = onRefresh
    }

    private var presentation: MarketDecisionPresentationPolicy.Presentation {
        MarketDecisionPresentationPolicy.preTrade(context)
    }
    private var toneColor: Color { decisionColor }
    private var decisionText: String { presentation.action }
    private var decisionColor: Color { presentation.entryConfirmed ? .green : .orange }
    private var biasText: String { "Direction: " + presentation.direction.rawValue.capitalized }
    private var pressureText: String { "Entry: " + presentation.entryQuality }
    private var biasIcon: String {
        switch presentation.direction {
        case .bullish: return "arrow.up.circle.fill"
        case .bearish: return "arrow.down.circle.fill"
        default: return "arrow.left.and.right.circle.fill"
        }
    }
    private var gradeTint: Color {
        context.entryGrade >= 75 ? .green : (context.entryGrade >= 55 ? .orange : .red)
    }
    private var actionRead: String { presentation.action }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            decisionBlock

            Text(actionRead)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(decisionColor)

            Text(context.plainEnglishRead)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)

            pillWrap
            metric("Regime", presentation.regime)
            metric("Entry condition", presentation.entryCondition)
            metric("Evidence", presentation.evidenceStatus)
            if let through = presentation.confirmationThrough {
                metric("Closed evidence through", through)
            }

            if let scenario = context.scenario {
                metric("Scenario", scenario.replacingOccurrences(of: "_", with: " ").capitalized)
            }

            if let next = context.nextExpectedEvent {
                metric("Next", next)
            }

            if let confirmation = context.confirmation {
                metric("Confirm", confirmation)
            }

            if let invalidation = context.invalidation {
                metric("Invalidation", invalidation)
            }

            if showAdvancedLevels {
                levelsRow
            }

            if showActions, !context.actions.isEmpty {
                bulletSection("Actions", context.actions)
            }

            if !context.warnings.isEmpty {
                bulletSection("Warnings", context.warnings)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.danger)
            }

            Text(context.priceSource)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding()
        .background(toneColor.opacity(0.10))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(toneColor.opacity(0.75), lineWidth: 1.5)
                .shadow(color: toneColor.opacity(0.55), radius: 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pre-Trade Context")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.softGold)

                Text(context.displaySymbol ?? context.symbol)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            Image(systemName: biasIcon)
                .font(.title2)
                .foregroundStyle(toneColor)

            Button {
                onRefresh()
            } label: {
                Image(systemName: isLoading ? "hourglass" : "arrow.clockwise")
                    .font(.headline.bold())
                    .frame(width: 44, height: 44)
                    .foregroundStyle(AppTheme.gold)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
    }

    private var decisionBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Decision")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.secondaryText)

            Text(decisionText)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(decisionColor)
                .minimumScaleFactor(0.65)
                .lineLimit(2)
        }
    }

    private var pillWrap: some View {
        HStack(spacing: 8) {
            pill("Grade \(context.entryGrade)/100", color: gradeTint)
            pill(biasText, color: .blue)
            pill(pressureText, color: toneColor)
            pill(context.conviction.capitalized, color: toneColor)
        }
    }

    private var levelsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Chart Levels")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)

            HStack {
                metric("S2", format(context.support2))
                metric("S1", format(context.support1))
                metric("Mid", format(context.midpoint))
            }

            HStack {
                metric("R1", format(context.resistance1))
                metric("R2", format(context.resistance2))
                metric("Break ↑", format(context.breakoutAbove))
            }

            HStack {
                metric("Main Support", format(context.supportLevel))
                metric("Main Resist", format(context.resistanceLevel))
                metric("Break ↓", format(context.breakdownBelow))
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.secondaryText)

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bulletSection(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)

            ForEach(items, id: \.self) { item in
                Text("• \(item)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.primaryText)
            }
        }
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f", value)
    }
}
