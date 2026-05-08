//
//  TradeCardView.swift
//  ChaseINGreen
//

import SwiftUI

private struct TradeMathProfile {
    let displayName: String
    let quantityLabel: String
    let pnlMultiplier: Double

    static func forSymbol(_ symbol: String) -> TradeMathProfile {
        let cleaned = symbol
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        switch cleaned {
        case "XAUUSD", "GC=F", "GOLD":
            return TradeMathProfile(displayName: "Gold", quantityLabel: "lots", pnlMultiplier: 100)
        case "XAGUSD", "SI=F", "SILVER":
            return TradeMathProfile(displayName: "Silver", quantityLabel: "lots", pnlMultiplier: 5000)
        case "BTCUSD", "BTC-USD", "BITCOIN":
            return TradeMathProfile(displayName: "Bitcoin", quantityLabel: "coins/lots", pnlMultiplier: 1)
        case "NQ", "NQ=F":
            return TradeMathProfile(displayName: "Nasdaq Futures", quantityLabel: "contracts", pnlMultiplier: 20)
        case "ES", "ES=F":
            return TradeMathProfile(displayName: "S&P Futures", quantityLabel: "contracts", pnlMultiplier: 50)
        case "WTI", "CL=F":
            return TradeMathProfile(displayName: "WTI Oil", quantityLabel: "contracts/lots", pnlMultiplier: 1000)
        default:
            return TradeMathProfile(displayName: cleaned, quantityLabel: "shares", pnlMultiplier: 1)
        }
    }
}

struct TradeCardView: View {
    let trade: LoggedTradeResponse

    private var mathProfile: TradeMathProfile {
        TradeMathProfile.forSymbol(trade.symbol)
    }

    private var direction: String {
        trade.direction.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isLong: Bool { direction == "long" }
    private var isShort: Bool { direction == "short" }

    private var activePrice: Double? {
        trade.isOpen ? trade.currentPrice : trade.exitPrice ?? trade.currentPrice
    }

    private var pnl: Double? {
        if !trade.isOpen, let realizedPnl = trade.realizedPnl {
            return realizedPnl
        }

        if let backendOpenPnl = trade.openPnl {
            return backendOpenPnl
        }

        guard let activePrice, let quantity = trade.quantity else { return nil }

        if isLong {
            return (activePrice - trade.entryPrice) * quantity * mathProfile.pnlMultiplier
        }

        if isShort {
            return (trade.entryPrice - activePrice) * quantity * mathProfile.pnlMultiplier
        }

        return nil
    }

    private var pnlPercent: Double? {
        guard let pnl, let accountSize = trade.accountSize, accountSize != 0 else { return nil }
        return (pnl / accountSize) * 100
    }

    private var bestPnl: Double? {
        guard let bestPrice = trade.bestPrice,
              let quantity = trade.quantity else { return nil }

        if isLong {
            return (bestPrice - trade.entryPrice) * quantity * mathProfile.pnlMultiplier
        }

        if isShort {
            return (trade.entryPrice - bestPrice) * quantity * mathProfile.pnlMultiplier
        }

        return nil
    }

    private var givebackAmount: Double? {
        guard let bestPnl, let pnl, bestPnl > 0 else { return nil }
        return max(0, bestPnl - pnl)
    }

    private var givebackPercent: Double? {
        guard let bestPnl, bestPnl > 0, let givebackAmount else { return nil }
        return (givebackAmount / bestPnl) * 100
    }

    private var givebackWarning: String? {
        guard let givebackPercent else { return nil }

        if givebackPercent >= 70 { return "Major giveback — most profits slipped." }
        if givebackPercent >= 40 { return "Profits slipping — consider protecting cash." }
        if givebackPercent >= 20 { return "Small giveback starting." }

        return nil
    }

    private var isWinning: Bool { (pnl ?? 0) > 0 }
    private var isLosing: Bool { (pnl ?? 0) < 0 }

    private var cardTint: Color {
        if isWinning { return .green }
        if isLosing { return .red }
        return .secondary
    }

    private var directionTint: Color {
        if isLong { return .green }
        if isShort { return .red }
        return .secondary
    }

    private var arrowIcon: String {
        if isLong && isWinning { return "arrow.up.circle.fill" }
        if isLong && isLosing { return "arrow.down.circle.fill" }
        if isShort && isWinning { return "arrow.down.circle.fill" }
        if isShort && isLosing { return "arrow.up.circle.fill" }
        return "minus.circle.fill"
    }

    private var positionStatus: String {
        if !trade.isOpen { return isWinning ? "Closed Green" : isLosing ? "Closed Red" : "Closed Flat" }
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
            accountIdentityRow
            pnlRow
            givebackRow
            riskRow

            HStack {
                metric("Entry", format(trade.entryPrice))
                metric(trade.isOpen ? "Now" : "Exit", format(activePrice))
                metric("Qty", format(trade.quantity))
            }

            HStack {
                metric("Best", format(trade.bestPrice))
                metric("Worst", format(trade.worstPrice))
                metric("Acct", format(trade.accountSize))
            }

            HStack {
                metric("Stop", format(trade.stopLoss))
                metric("Target", format(trade.takeProfit))
                metric("Impact", formatPercent(pnlPercent))
            }

            Text("P/L math: \(mathProfile.displayName) • \(mathProfile.quantityLabel) × \(formatMultiplier(mathProfile.pnlMultiplier))")
                .font(.caption2)
                .foregroundStyle(.secondary)

            contextRow

            if let closedAt = trade.closedAt, !trade.isOpen {
                Text("Closed: \(closedAt)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let notes = trade.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
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
        HStack {
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

            HStack(spacing: 6) {
                if !trade.isOpen {
                    pill("Closed", color: .secondary)
                }

                pill(trade.direction.capitalized, color: directionTint)
            }
        }
    }

    @ViewBuilder
    private var accountIdentityRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let platform = trade.platform, !platform.isEmpty {
                Text("Broker: \(platform)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let accountName = trade.brokerAccountName, !accountName.isEmpty {
                Text("Account: \(accountName)")
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }

            if let last4 = trade.brokerAccountNumberLast4, !last4.isEmpty {
                Text("Last 4: \(last4)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let groupKey = trade.accountGroupKey, !groupKey.isEmpty {
                Text("Group: \(groupKey)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var pnlRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(trade.isOpen ? "Open P/L" : "Realized P/L")
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

    @ViewBuilder
    private var givebackRow: some View {
        if let bestPnl, bestPnl > 0 {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    metric("Best P/L", formatMoney(bestPnl))
                    metric("Giveback", formatMoney(givebackAmount))
                    metric("Gave Back", formatPercent(givebackPercent))
                }

                if let givebackWarning {
                    Text(givebackWarning)
                        .font(.caption.bold())
                        .foregroundStyle((givebackPercent ?? 0) >= 40 ? .red : .orange)
                }
            }
        }
    }

    @ViewBuilder
    private var riskRow: some View {
        if trade.maxLoss != nil || trade.riskPercent != nil || trade.maxDailyLossAllowed != nil || trade.maxTotalLossAllowed != nil || trade.payoutTarget != nil {
            HStack {
                metric("Max Loss", formatMoney(trade.maxLoss))
                metric("Risk %", formatPercent(trade.riskPercent))
                metric("Payout", formatMoney(trade.payoutTarget))
            }

            HStack {
                metric("Daily Max", formatMoney(trade.maxDailyLossAllowed))
                metric("Total Max", formatMoney(trade.maxTotalLossAllowed))
                metric("Open P/L", formatMoney(trade.openPnl))
            }
        }
    }

    private var contextRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            coloredContextText(directionalBias)

            if let activePrice {
                if isLong {
                    Text(activePrice >= trade.entryPrice ? "Price is above entry. Bulls are still paid." : "Price is below entry. Bulls are under pressure.")
                        .font(.caption)
                        .foregroundStyle(activePrice >= trade.entryPrice ? .green : .red)
                }

                if isShort {
                    Text(activePrice <= trade.entryPrice ? "Price is below entry. Bears are still paid." : "Price is above entry. Bears are under pressure.")
                        .font(.caption)
                        .foregroundStyle(activePrice <= trade.entryPrice ? .green : .red)
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

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func formatMultiplier(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }

        return String(format: "%.2f", value)
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

#Preview("Gold Lot Loss") {
    TradeCardView(
        trade: LoggedTradeResponse(
            id: UUID(),
            userId: nil,
            symbol: "XAUUSD",
            direction: "long",
            entryPrice: 4567.66,
            currentPrice: 4547.32,
            bestPrice: 4578.00,
            worstPrice: 4547.32,
            stopLoss: nil,
            takeProfit: nil,
            quantity: 0.01,
            accountSize: 100000,
            platform: "Aqua Funding",
            brokerAccountId: "aqua-100k-1",
            brokerAccountName: "Aqua 100K #1",
            brokerAccountNumberLast4: "8891",
            accountGroupKey: "aqua-100k-1",
            parentTradeGroupId: nil,
            openPnl: nil,
            realizedPnl: nil,
            exitPriceConfirmed: false,
            closeSource: nil,
            closeConfidence: nil,
            maxLoss: 6000,
            riskPercent: 0.02,
            maxDailyLossAllowed: 3000,
            maxTotalLossAllowed: 6000,
            payoutTarget: 8000,
            openedAt: "2026-04-30T04:59:29.265823",
            isOpen: true,
            notes: "Gold lot math example",
            createdAt: "2026-04-30T04:59:29.268544",
            closedAt: nil,
            exitPrice: nil,
            lastUpdatedAt: "2026-04-30T05:00:57.413868"
        )
    )
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
            bestPrice: 52.50,
            worstPrice: 51.50,
            stopLoss: 51.20,
            takeProfit: 53.40,
            quantity: 25,
            accountSize: 5000,
            platform: "Trade The Pool",
            brokerAccountId: "ttp-5k-1",
            brokerAccountName: "Trade The Pool 5K #1",
            brokerAccountNumberLast4: nil,
            accountGroupKey: "ttp-5k-1",
            parentTradeGroupId: nil,
            openPnl: nil,
            realizedPnl: nil,
            exitPriceConfirmed: false,
            closeSource: nil,
            closeConfidence: nil,
            maxLoss: 250,
            riskPercent: 0.42,
            maxDailyLossAllowed: 150,
            maxTotalLossAllowed: 250,
            payoutTarget: 500,
            openedAt: "2026-04-17T15:42:05.688923",
            isOpen: true,
            notes: "Test trade",
            createdAt: "2026-04-17T15:42:07.045039",
            closedAt: nil,
            exitPrice: nil,
            lastUpdatedAt: "2026-04-25T20:30:20.318873"
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
            bestPrice: 13.00,
            worstPrice: 15.25,
            stopLoss: 15.50,
            takeProfit: 12.90,
            quantity: 50,
            accountSize: 5000,
            platform: "Fidelity",
            brokerAccountId: "fidelity-cash-1",
            brokerAccountName: "Fidelity Cash",
            brokerAccountNumberLast4: "0421",
            accountGroupKey: "fidelity-cash-1",
            parentTradeGroupId: nil,
            openPnl: nil,
            realizedPnl: nil,
            exitPriceConfirmed: false,
            closeSource: nil,
            closeConfidence: nil,
            maxLoss: nil,
            riskPercent: nil,
            maxDailyLossAllowed: nil,
            maxTotalLossAllowed: nil,
            payoutTarget: nil,
            openedAt: "2026-04-17T15:42:05.688923",
            isOpen: true,
            notes: "Short trade example",
            createdAt: "2026-04-17T15:42:07.045039",
            closedAt: nil,
            exitPrice: nil,
            lastUpdatedAt: "2026-04-25T20:30:20.318873"
        )
    )
}
