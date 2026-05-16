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
    
    @State private var pulse = false
    
    private var shouldFlash: Bool {
        alert.flashAlert == true ||
        alert.alertType == "source_conflict" ||
        alert.alertType == "get_out" ||
        alert.alertType == "account_danger"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if shouldFlash {
                emergencyBanner
            }
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.title)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(
                            shouldFlash
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: [.white, AppTheme.softGold],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        )
                    
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
                                                alertTint.opacity(0.18)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(alertTint.opacity(0.35), lineWidth: 1)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [
                    .white.opacity(0.14),
                    .white.opacity(0.05),
                    alertTint.opacity(shouldFlash ? 0.22 : 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.30),
                            alertTint.opacity(shouldFlash ? 0.95 : 0.45),
                            AppTheme.gold.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: shouldFlash ? 2 : 1.2
                )
        }
        .scaleEffect(shouldFlash && pulse ? 1.015 : 1.0)
        .shadow(
            color: shouldFlash ? alertTint.opacity(0.35) : .clear,
            radius: shouldFlash && pulse ? 14 : 4
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .animation(
            shouldFlash
            ? .easeInOut(duration: 0.65).repeatForever(autoreverses: true)
            : .default,
            value: pulse
        )
        .onAppear {
            pulse = shouldFlash
        }
        .onChange(of: shouldFlash) { _, newValue in
            pulse = newValue
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
        .background(alertTint.opacity(pulse ? 1.0 : 0.65))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
    
    private var emergencyText: String {
        switch alert.alertType {
        case "source_conflict":
            return "Price source conflict — use broker price"
        case "get_out":
            return "Get out / protect capital"
        case "account_danger":
            return "Account danger"
        case "trend_weakening":
            return "Trend weakening — protect trade"
        case "liquidity_hunt":
            return "Liquidity hunt — verify structure"
        default:
            return "Urgent trade alert"
        }
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
            .font(.system(size: 12, weight: .black))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(color.opacity(0.16))
            )
            .overlay {
                Capsule()
                    .stroke(color.opacity(0.35), lineWidth: 1)
            }
            .foregroundStyle(color)
    }
}
