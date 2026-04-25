//
//  TradeCardView.swift
//  ChaseINGreen
//

import SwiftUI

struct TradeCardView: View {
    let trade: LoggedTradeResponse

    private var direction: String {
        trade.direction.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isLong: Bool {
        direction == "long"
    }

    private var isShort: Bool {
        direction == "short"
    }

    private var currentPrice: Double? {
        trade.currentPrice
    }

    private var pnl: Double? {
        guard let currentPrice, let quantity = trade.quantity else { return nil }

        if isLong {
            return (currentPrice - trade.entryPrice) * quantity
        }

        if isShort {
            return (trade.entryPrice - currentPrice) * quantity
        }

        return nil
    }

    private var pnlPercent: Double? {
        guard let pnl, let accountSize = trade.accountSize, accountSize != 0 else { return nil }
        return (pnl / accountSize) * 100
    }

    private var isWinning: Bool {
        guard let pnl else { return false }
        return pnl > 0
    }

    private var isLosing: Bool {
        guard let pnl else { return false }
        return pnl < 0
    }

    private var cardTint: Color {
        if isWinning { return .green }
        if isLosing { return .red }
        return .secondary
    }

    private var arrowIcon: String {
        if isLong && isWinning { return "arrow.up.circle.fill" }
        if isLong && isLosing { return "arrow.down.circle.fill" }

        // Short/put logic:
        // price going down = winning, price going up = losing
        if isShort && isWinning { return "arrow.down.circle.fill" }
        if isShort && isLosing { return "arrow.up.circle.fill" }

        return "minus.circle.fill"
    }

    private var positionStatus: String {
        if isWinning { return "Winning" }
        if isLosing { return "Losing" }
        return "Flat"
    }

    private var directionalBias: String {
        if isLong {
            return isWinning ? "Bullish trade is working" : isLosing ? "Bullish trade is failing" : "Bullish trade is flat"
        }

        if isShort {
            return isWinning ? "Bearish trade is working" : isLosing ? "Bearish trade is failing" : "Bearish trade is flat"
        }

        return "Trade direction unknown"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow

            pnlRow

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

            contextRow

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
        .background(cardTint.opacity(0.12))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(cardTint.opacity(0.35), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var headerRow: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Image(systemName: arrowIcon)
                    .foregroundStyle(cardTint)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(trade.symbol)
                        .font(.headline)

                    Text(positionStatus)
                        .font(.caption.bold())
                        .foregroundStyle(cardTint)
                }
            }

            Spacer()

            directionPill
        }
    }

    private var directionPill: some View {
        Text(trade.direction.capitalized)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(directionTint.opacity(0.15))
            .foregroundStyle(directionTint)
            .clipShape(Capsule())
    }

    private var pnlRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Open P/L")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(formatMoney(pnl))
                    .font(.title3.bold())
                    .foregroundStyle(cardTint)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Acct Impact")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(formatPercent(pnlPercent))
                    .font(.subheadline.bold())
                    .foregroundStyle(cardTint)
            }
        }
    }

    private var contextRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            coloredContextText(directionalBias)

            if let currentPrice {
                if isLong {
                    Text(currentPrice >= trade.entryPrice
                         ? "Price is above entry. Bulls are still paid."
                         : "Price is below entry. Bulls are under pressure.")
                        .font(.caption)
                        .foregroundStyle(currentPrice >= trade.entryPrice ? .green : .red)
                }

                if isShort {
                    Text(currentPrice <= trade.entryPrice
                         ? "Price is below entry. Bears are still paid."
                         : "Price is above entry. Bears are under pressure.")
                        .font(.caption)
                        .foregroundStyle(currentPrice <= trade.entryPrice ? .green : .red)
                }
            }
        }
    }

    private func coloredContextText(_ text: String) -> some View {
        Group {
            if text.lowercased().contains("bullish") {
                Text(text)
                    .font(.caption.bold())
                    .foregroundStyle(text.lowercased().contains("failing") ? .red : .green)
            } else if text.lowercased().contains("bearish") {
                Text(text)
                    .font(.caption.bold())
                    .foregroundStyle(text.lowercased().contains("working") ? .green : .red)
            } else {
                Text(text)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var directionTint: Color {
        if isLong { return .green }
        if isShort { return .red }
        return .secondary
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

    private func formatMoney(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%@%.2f", value >= 0 ? "+$" : "-$", abs(value))
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%+.2f%%", value)
    }
}

#Preview("Long Winning") {
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

#Preview("Short Winning") {
    TradeCardView(
        trade: LoggedTradeResponse(
            id: UUID(),
            userId: nil,
            symbol: "SOXS",
            direction: "short",
            entryPrice: 15.00,
            currentPrice: 13.50,
            stopLoss: 15.50,
            takeProfit: 12.90,
            quantity: 50,
            accountSize: 5000,
            platform: "Fidelity",
            openedAt: "2026-04-17T15:42:05.688923",
            isOpen: true,
            notes: "Short trade example",
            createdAt: "2026-04-17T15:42:07.045039"
        )
    )
}
