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

    private var toneColor: Color {
        switch context.cardTone.lowercased() {
        case "green": return .green
        case "red": return .red
        default: return AppTheme.gold
        }
    }

    private var decisionText: String {
        context.canEnter ? "ENTRY WATCH" : "WAIT"
    }

    private var decisionColor: Color {
        context.canEnter ? .green : .orange
    }

    private var biasText: String {
        switch context.setupBias.lowercased() {
        case "long", "bullish", "call": return "Bull Bias"
        case "short", "bearish", "put": return "Bear Bias"
        default: return "Mixed Bias"
        }
    }

    private var biasIcon: String {
        switch context.directionSignal.lowercased() {
        case "up": return "arrow.up.circle.fill"
        case "down": return "arrow.down.circle.fill"
        default: return "arrow.left.and.right.circle.fill"
        }
    }

    private var gradeTint: Color {
        if context.entryGrade >= 75 { return .green }
        if context.entryGrade >= 55 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            decisionBlock

            Text(context.plainEnglishRead)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)

            HStack(spacing: 8) {
                pill("Grade \(context.entryGrade)/100", color: gradeTint)
                pill(biasText, color: .blue)
                pill(context.conviction.capitalized, color: toneColor)
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
                .shadow(color: toneColor.opacity(0.8), radius: 10)
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
                    .foregroundStyle(AppTheme.gold)
            }
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
