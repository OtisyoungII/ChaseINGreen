//
//  TradeAlertCard.swift
//  ChaseINGreen
//

import SwiftUI

struct TradeAlertCard: View {
    let alert: TradeAlertResponse
    let onSelectOption: (String) -> Void

    @State private var pulse = false

    private var shouldFlash: Bool {
        alert.flashAlert == true ||
        alert.alertType == "source_conflict" ||
        alert.alertType == "get_out" ||
        alert.alertType == "account_danger"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if shouldFlash {
                emergencyBanner
            }

            headerSection
            claritySection
            sourceSection
            pillRow

            if !alert.warnings.isEmpty {
                bulletSection(title: "Warnings", items: alert.warnings)
            }

            if !alert.actions.isEmpty {
                bulletSection(title: "Actions", items: alert.actions)
            }

            if alert.needsUserResponse {
                responseButtons
            }
        }
        .padding()
        .background(cardGradient)
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(borderGradient, lineWidth: shouldFlash ? 2 : 1.2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: alertTint.opacity(shouldFlash ? 0.32 : 0.14), radius: shouldFlash && pulse ? 16 : 10, x: 0, y: 8)
        .scaleEffect(shouldFlash && pulse ? 1.012 : 1.0)
        .animation(
            shouldFlash ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default,
            value: pulse
        )
        .onAppear { pulse = shouldFlash }
        .onChange(of: shouldFlash) { _, newValue in
            pulse = newValue
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(alert.title)
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .foregroundStyle(shouldFlash ? .white : AppTheme.softGold)

                Text(alert.message)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(alert.confidence)%")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(alertTint)

                Text(confidenceCaption)
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private var claritySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(alert.probabilityLabel ?? "Signal Confidence")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(AppTheme.softGold)

            Text(alert.probabilityDetail ?? fallbackProbabilityDetail)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)

            if let recoveryChance = alert.recoveryChance {
                Text("Recovery chance: \(formatPercent(recoveryChance))")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }

            if let failureRate = alert.failureRate {
                Text("Failure risk: \(formatPercent(failureRate))")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }

            if let sessionContext = alert.sessionContext {
                Text(sessionContext)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.secondaryText)
            }

            HStack(spacing: 8) {
                if let swept = alert.sessionHighSwept {
                    pill(swept ? "Session high swept" : "High not swept", color: swept ? .orange : .green)
                }

                if let swept = alert.sessionLowSwept {
                    pill(swept ? "Session low swept" : "Low not swept", color: swept ? .orange : .green)
                }
            }
        }
        .padding(12)
        .background(.black.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Price Source")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)

            Text(alert.priceSource ?? "Market price uses Yahoo Finance snapshot data when broker price is not provided. Broker/platform price should be used for execution decisions.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var pillRow: some View {
        HStack(spacing: 8) {
            pill(alert.severity.uppercased(), color: alertTint)

            if let marketPhase = alert.marketPhase {
                pill(marketPhase.replacingOccurrences(of: "_", with: " "), color: .secondary)
            }

            if let seconds = alert.responseRequiredWithinSeconds {
                pill("Respond \(seconds)s", color: .orange)
            }
        }
    }

    private var responseButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(alert.responseOptions, id: \.self) { option in
                    Button {
                        onSelectOption(option)
                    } label: {
                        Text(option)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.14),
                                        alertTint.opacity(0.24)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(alertTint.opacity(0.45), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emergencyBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")

            Text(emergencyText)
                .font(.caption.bold())
                .textCase(.uppercase)

            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(alertTint.opacity(pulse ? 1.0 : 0.70))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func bulletSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)

            ForEach(items, id: \.self) { item in
                Text("• \(item)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
            }
        }
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .black))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(color.opacity(0.18)))
            .overlay {
                Capsule().stroke(color.opacity(0.45), lineWidth: 1)
            }
            .foregroundStyle(color)
    }

    private var confidenceCaption: String {
        alert.probabilityLabel == nil ? "confidence" : "context"
    }

    private var fallbackProbabilityDetail: String {
        "This percentage is signal confidence, not guaranteed profit. Use it as trade context with broker price confirmation."
    }

    private var emergencyText: String {
        switch alert.alertType {
        case "source_conflict": return "Price source conflict — use broker price"
        case "get_out": return "Get out / protect capital"
        case "account_danger": return "Account danger"
        case "trend_weakening": return "Trend weakening — protect trade"
        case "liquidity_hunt": return "Liquidity hunt — verify structure"
        default: return "Urgent trade alert"
        }
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.black.opacity(0.55),
                AppTheme.cardBlack.opacity(0.94),
                alertTint.opacity(shouldFlash ? 0.20 : 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(0.24),
                alertTint.opacity(shouldFlash ? 0.95 : 0.42),
                AppTheme.gold.opacity(0.26)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var alertTint: Color {
        switch alert.severity.lowercased() {
        case "critical": return .red
        case "warning": return .orange
        case "info": return .green
        default: return AppTheme.gold
        }
    }

    private func formatPercent(_ value: Double) -> String {
        if value <= 1 {
            return String(format: "%.0f%%", value * 100)
        }

        return String(format: "%.0f%%", value)
    }
}
