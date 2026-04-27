//
//  TradeAlertCard.swift
//  ChaseINGreen
//
//  Created by Otis Young on 4/27/26.
//


import SwiftUI

struct TradeAlertCard: View {
    let alert: TradeAlertResponse
    let onSelectOption: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.title)
                        .font(.headline)

                    Text(alert.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(alert.confidence)%")
                    .font(.headline.bold())
                    .foregroundStyle(alertTint)
            }

            if let flavor = alert.flavor {
                Text(flavor)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                pill(alert.severity.uppercased(), color: alertTint)

                if let marketPhase = alert.marketPhase {
                    pill(
                        marketPhase.replacingOccurrences(of: "_", with: " "),
                        color: .secondary
                    )
                }

                if let seconds = alert.responseRequiredWithinSeconds {
                    pill("Respond \(seconds)s", color: .orange)
                }
            }

            if !alert.warnings.isEmpty {
                bulletSection(title: "Warnings", items: alert.warnings)
            }

            if !alert.actions.isEmpty {
                bulletSection(title: "Actions", items: alert.actions)
            }

            if alert.needsUserResponse {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(alert.responseOptions, id: \.self) { option in
                            Button(option) {
                                onSelectOption(option)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .padding()
        .background(alertTint.opacity(0.12))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(alertTint.opacity(0.35), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var alertTint: Color {
        switch alert.severity.lowercased() {
        case "critical":
            return .red
        case "warning":
            return .orange
        case "info":
            return .green
        default:
            return .gray
        }
    }

    private func bulletSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(items, id: \.self) { item in
                Text("• \(item)")
                    .font(.caption)
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
}
