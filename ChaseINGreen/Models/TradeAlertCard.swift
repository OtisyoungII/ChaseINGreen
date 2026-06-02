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
        alert.severity.lowercased() == "critical" ||
        alert.alertType.lowercased() == "danger" ||
        alert.alertType.lowercased() == "exit" ||
        alert.alertType.lowercased() == "account_protection"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if shouldFlash {
                emergencyBanner
            }

            headerSection
            claritySection
            aiGuidanceSection
            recoverySection
            sourceSection
            pillRow

            if !alert.reasons.isEmpty {
                bulletSection(title: "Context", items: alert.reasons)
            }

            if !alert.warnings.isEmpty {
                bulletSection(title: "Watchouts", items: alert.warnings)
            }

            if !alert.actions.isEmpty {
                bulletSection(title: "Next Moves", items: alert.actions)
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
        .shadow(
            color: alertTint.opacity(shouldFlash ? 0.32 : 0.14),
            radius: shouldFlash && pulse ? 16 : 10,
            x: 0,
            y: 8
        )
        .scaleEffect(shouldFlash && pulse ? 1.012 : 1.0)
        .animation(
            shouldFlash ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default,
            value: pulse
        )
        .onAppear {
            pulse = shouldFlash
        }
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

                Text(cleanMessage)
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
            Text(alert.probabilityLabel ?? "Trade Context")
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
                    pill(swept ? "High swept" : "High holding", color: swept ? .orange : .green)
                }

                if let swept = alert.sessionLowSwept {
                    pill(swept ? "Low swept" : "Low holding", color: swept ? .orange : .green)
                }
            }
        }
        .padding(12)
        .background(.black.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var aiGuidanceSection: some View {
        if alert.setupBias != nil ||
            alert.setupQuality != nil ||
            alert.tradeTiming != nil ||
            alert.plainEnglishRead != nil {

            VStack(alignment: .leading, spacing: 10) {
                Text("AI Trade Read")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(AppTheme.softGold)

                HStack(spacing: 8) {
                    if let bias = alert.setupBias {
                        pill("Bias: \(displayPhase(bias))", color: biasColor(bias))
                    }

                    if let quality = alert.setupQuality {
                        pill(displayPhase(quality), color: qualityColor(quality))
                    }

                    if let timing = alert.tradeTiming {
                        pill(displayPhase(timing), color: .blue)
                    }
                }

                if let read = alert.plainEnglishRead {
                    Text(read)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
            .padding(12)
            .background(.black.opacity(0.28))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    @ViewBuilder
    private var preTradeContextSection: some View {
        if alert.scenario != nil ||
            alert.scenarioConfidence != nil ||
            alert.entryGrade != nil ||
            alert.canEnter != nil ||
            alert.nextExpectedEvent != nil {

            VStack(alignment: .leading, spacing: 10) {
                Text("Pre-Trade Context")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(AppTheme.softGold)

                HStack(spacing: 8) {
                    if let scenario = alert.scenario {
                        pill(displayPhase(scenario), color: .purple)
                    }

                    if let canEnter = alert.canEnter {
                        pill(canEnter ? "Entry Allowed" : "Wait", color: canEnter ? .green : .orange)
                    }

                    if let grade = alert.entryGrade {
                        pill("Grade \(grade)/100", color: grade >= 75 ? .green : grade >= 55 ? .orange : .red)
                    }
                }

                if let confidence = alert.scenarioConfidence {
                    Text("Scenario confidence: \(confidence)%")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.secondaryText)
                }

                if let next = alert.nextExpectedEvent {
                    Text("Next expected event: \(next)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
            .padding(12)
            .background(.black.opacity(0.28))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private var recoverySection: some View {
        if alert.recoveryModeActive == true {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundStyle(.orange)

                    Text("Recovery Mode Active")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.orange)

                    Spacer()
                }

                if let risk = alert.remainingDailyRisk {
                    Text("Remaining daily risk: \(formatMoney(risk))")
                }

                if let target = alert.recoveryTarget {
                    Text("Recovery target: \(formatMoney(target))")
                }

                if let size = alert.recommendedMaxSize {
                    Text("Suggested max size: \(formatSize(size))")
                }

                if alert.stopTradingToday == true {
                    Text("Stop trading today. Protect the account first.")
                        .font(.headline.bold())
                        .foregroundStyle(.red)
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppTheme.primaryText)
            .padding(12)
            .background(.red.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Price Source")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)

            Text(alert.priceSource ?? defaultPriceSourceText)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var pillRow: some View {
        HStack(spacing: 8) {
            pill(displaySeverity, color: alertTint)

            if let marketPhase = alert.marketPhase {
                pill(displayPhase(marketPhase), color: .secondary)
            }

            if let tradeState = alert.tradeState {
                pill(displayPhase(tradeState), color: .secondary)
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

    private var cleanMessage: String {
        if alert.message.lowercased() == "monitoring trade." {
            return "Reading the trade structure, account risk, broker price, and market context."
        }

        return alert.message
    }

    private var confidenceCaption: String {
        alert.probabilityLabel == nil ? "context score" : "context"
    }

    private var fallbackProbabilityDetail: String {
        "This is trade context, not a profit promise. Use it with broker price, account rules, and your trade plan."
    }

    private var defaultPriceSourceText: String {
        "Broker/platform price is execution truth. App quotes help with structure, context, and alerts."
    }

    private var displaySeverity: String {
        switch alert.severity.lowercased() {
        case "critical": return "CRITICAL"
        case "high": return "HIGH"
        case "medium": return "MEDIUM"
        case "low": return "LOW"
        default: return alert.severity.uppercased()
        }
    }

    private func displayPhase(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func biasColor(_ value: String) -> Color {
        switch value.lowercased() {
        case "long":
            return .green
        case "short":
            return .red
        default:
            return .orange
        }
    }

    private func qualityColor(_ value: String) -> Color {
        switch value.lowercased() {
        case "excellent", "good":
            return .green
        case "neutral", "fair":
            return .yellow
        default:
            return .orange
        }
    }

    private var emergencyText: String {
        switch alert.alertType.lowercased() {
        case "exit":
            return "Exit / protect capital"
        case "danger":
            return "Danger — protect account"
        case "account_protection":
            return "Account protection"
        case "warning":
            return "Warning — manage trade"
        default:
            return "Urgent trade alert"
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
        case "critical":
            return .red
        case "high":
            return .orange
        case "medium":
            return .yellow
        case "low":
            return .green
        default:
            switch alert.alertType.lowercased() {
            case "danger", "exit":
                return .red
            case "warning", "account_protection":
                return .orange
            case "info", "entry":
                return .green
            default:
                return AppTheme.gold
            }
        }
    }

    private func formatPercent(_ value: Double) -> String {
        if value <= 1 {
            return String(format: "%.0f%%", value * 100)
        }

        return String(format: "%.0f%%", value)
    }

    private func formatMoney(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    private func formatSize(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        }

        return String(format: "%.2f", value)
    }
}
