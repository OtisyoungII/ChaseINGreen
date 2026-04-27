//
//  TradeActionPanel.swift
//  ChaseINGreen
//

import SwiftUI

struct TradeActionPanel: View {
    let trade: LoggedTradeResponse
    let currentQuotePrice: Double?
    let onAction: (TradeActionPrompt) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Manage Trade")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    actionButton("Broker Price", .brokerPrice(trade))
                    actionButton("Stop", .stopLoss(trade))
                    actionButton("Clear Stop", .clearStopLoss(trade))
                    actionButton("Target", .takeProfit(trade))
                    actionButton("Clear Target", .clearTakeProfit(trade))
                    actionButton("Qty", .quantity(trade))
                    actionButton("Reduce", .reduce(trade))
                    actionButton("Add", .add(trade))
                    actionButton("Stop Hit", .stopLossHit(trade), tint: .orange)
                    actionButton("Target Hit", .takeProfitHit(trade), tint: .green)
                    actionButton("Close", .close(trade), tint: .red, prominent: true)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func actionButton(
        _ title: String,
        _ prompt: TradeActionPrompt,
        tint: Color? = nil,
        prominent: Bool = false
    ) -> some View {
        if prominent {
            Button(title) {
                onAction(prompt)
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
        } else {
            Button(title) {
                onAction(prompt)
            }
            .buttonStyle(.bordered)
            .tint(tint)
        }
    }
}
