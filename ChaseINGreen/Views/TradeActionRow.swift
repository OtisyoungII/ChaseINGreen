//
//  TradeActionRow.swift
//  ChaseINGreen
//
//  Created by Otis Young on 4/27/26.
//

import SwiftUI

struct TradeActionRow: View {
    let trade: LoggedTradeResponse
    let currentQuotePrice: Double?
    let onActionTapped: (TradeActionPrompt) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Manage Trade")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    actionButton("Broker Price", prompt: .brokerPrice(trade))
                    actionButton("Set Stop", prompt: .stopLoss(trade))

                    if trade.stopLoss != nil {
                        actionButton("Remove Stop", prompt: .clearStopLoss(trade))
                        actionButton("Stop Hit", prompt: .stopLossHit(trade))
                    }

                    actionButton("Set Target", prompt: .takeProfit(trade))

                    if trade.takeProfit != nil {
                        actionButton("Remove Target", prompt: .clearTakeProfit(trade))
                        actionButton("Target Hit", prompt: .takeProfitHit(trade))
                    }

                    actionButton("Qty", prompt: .quantity(trade))
                    actionButton("Reduce", prompt: .reduce(trade))
                    actionButton("Add", prompt: .add(trade))

                    Button("Close") {
                        onActionTapped(.close(trade))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func actionButton(_ title: String, prompt: TradeActionPrompt) -> some View {
        Button(title) {
            onActionTapped(prompt)
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    TradeActionRow(
        trade: LoggedTradeResponse(
            id: UUID(),
            userId: nil,
            symbol: "BTCUSD",
            direction: "long",
            entryPrice: 78035.11,
            currentPrice: 78119.45,
            stopLoss: 78000,
            takeProfit: 78500,
            quantity: 0.1,
            accountSize: 25000,
            platform: "Aqua Funding",
            openedAt: "2026-04-26T11:29:27.456159",
            isOpen: true,
            notes: nil,
            createdAt: "2026-04-26T11:29:27.459498",
            closedAt: nil,
            exitPrice: nil,
            realizedPnl: nil,
            lastUpdatedAt: "2026-04-26T11:29:27.456159"
        ),
        currentQuotePrice: 78100
    ) { _ in }
}
