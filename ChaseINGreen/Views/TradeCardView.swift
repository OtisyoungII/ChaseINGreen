//
//  TradeCardView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 4/17/26.
//

import SwiftUI

struct TradeCardView: View {
    let trade: LoggedTradeResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(trade.symbol)
                    .font(.headline)

                Spacer()

                Text(trade.direction.capitalized)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
            }

            HStack {
                metric("Entry", format(trade.entryPrice))
                metric("Now", format(trade.currentPrice))
                metric("Qty", format(trade.quantity))
            }

            HStack {
                metric("Stop", format(trade.stopLoss))
                metric("Target", format(trade.takeProfit))
                metric("Acct", format(trade.accountSize))
            }

            if let platform = trade.platform, !platform.isEmpty {
                Text("Platform: \(platform)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let notes = trade.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.bold())
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f", value)
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

#Preview {
    TradeCardView(
        trade: LoggedTradeResponse(
            id: UUID(),
            userId: nil,
            symbol: "TQQQ",
            direction: "long",
            entryPrice: 51.77,
            currentPrice: 52.10,
            stopLoss: 51.20,
            takeProfit: 53.40,
            quantity: 25,
            accountSize: 5000,
            platform: "Trade The Pool",
            openedAt: "2026-04-17T15:42:05.688923",
            isOpen: true,
            notes: "Test trade",
            createdAt: "2026-04-17T15:42:07.045039"
        )
    )
}
