//
//  TradeActionPanel.swift
//  ChaseINGreen
//

import SwiftUI

struct TradeActionPanel: View {
    let trade: LoggedTradeResponse
    let currentQuotePrice: Double?
    let onAction: (TradeActionPrompt) -> Void

    @State private var pressedTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Manage Trade", systemImage: "slider.horizontal.3")
                .font(AppTheme.captionFont.bold())
                .foregroundStyle(AppTheme.softGold)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    actionButton("Edit", .editTrade(trade), tint: .blue)
                    actionButton("Broker Price", .brokerPrice(trade), tint: AppTheme.gold)
                    actionButton("Stop", .stopLoss(trade), tint: .orange)
                    actionButton("Clear Stop", .clearStopLoss(trade), tint: .gray)
                    actionButton("Target", .takeProfit(trade), tint: .green)
                    actionButton("Clear Target", .clearTakeProfit(trade), tint: .gray)
                    actionButton("Qty", .quantity(trade), tint: .cyan)
                    actionButton("Reduce", .reduce(trade), tint: .orange)
                    actionButton("Add", .add(trade), tint: .green)
                    actionButton("Stop Hit", .stopLossHit(trade), tint: .orange)
                    actionButton("Target Hit", .takeProfitHit(trade), tint: .green)
                    actionButton("Close", .close(trade), tint: .red, prominent: true)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    .white.opacity(0.12),
                    .white.opacity(0.05),
                    AppTheme.gold.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.gold.opacity(0.25), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func actionButton(
        _ title: String,
        _ prompt: TradeActionPrompt,
        tint: Color,
        prominent: Bool = false
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                pressedTitle = title
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    pressedTitle = nil
                }

                onAction(prompt)
            }
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(tint.opacity(prominent ? 0.95 : 0.28))
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(prominent ? .white : tint)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: prominent
                    ? [tint.opacity(0.95), tint.opacity(0.65)]
                    : [.white.opacity(0.13), tint.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Capsule()
                    .stroke(tint.opacity(prominent ? 0.75 : 0.35), lineWidth: 1)
            }
            .clipShape(Capsule())
            .scaleEffect(pressedTitle == title ? 0.94 : 1.0)
            .shadow(color: tint.opacity(prominent ? 0.30 : 0.14), radius: prominent ? 10 : 5, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}
