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
    let onRefresh: () -> Void

    private var toneColor: Color {
        switch context.cardTone.lowercased() {
        case "green": return .green
        case "red": return .red
        default: return AppTheme.gold
        }
    }

    private var directionIcon: String {
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

            Text(context.plainEnglishRead)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)

            HStack(spacing: 8) {
                pill(context.canEnter ? "Entry Allowed" : "Wait", color: context.canEnter ? .green : .orange)
                pill("Grade \(context.entryGrade)/100", color: gradeTint)
                pill(context.setupBias.capitalized, color: .blue)
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

            levelsRow

            if !context.actions.isEmpty {
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

            Image(systemName: directionIcon)
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

    private var levelsRow: some View {
        HStack {
            metric("Support", format(context.supportLevel))
            metric("Resistance", format(context.resistanceLevel))
            metric("Target", format(context.target1))
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
