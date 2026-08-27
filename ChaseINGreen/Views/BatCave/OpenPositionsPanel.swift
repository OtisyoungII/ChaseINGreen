//
//  OpenPositionsPanel.swift
//  ChaseINGreen
//
//  By: Otis Young II
// --------------------------------------------------------------
// ✅ Bat Cave open positions panel
// ✅ Shows symbol, direction, platform, account, quantity and P/L
// ✅ Works with existing LoggedTradeResponse model
// --------------------------------------------------------------

import SwiftUI

struct OpenPositionsPanel: View {

    let trades: [LoggedTradeResponse]
    var marks: [UUID: PortfolioMarkResponse] = [:]

    var openTrades: [LoggedTradeResponse] {
        trades.filter { $0.isOpen }
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 16) {

            HStack {

                Text("Open Positions")
                    .font(.title2.bold())

                Spacer()

                Text("\(openTrades.count)")
                    .font(.headline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }

            if openTrades.isEmpty {

                ContentUnavailableView(
                    "No Open Positions",
                    systemImage: "tray",
                    description: Text("Broker synced positions and manual trades will appear here.")
                )

            } else {

                LazyVStack(spacing: 12) {

                    ForEach(openTrades) { trade in

                        positionRow(trade)
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func positionRow(
        _ trade: LoggedTradeResponse
    ) -> some View {

        let costBasisUnavailable = trade.entryPrice <= 0 || trade.notes?.localizedCaseInsensitiveContains(
            "cost basis and P/L unavailable"
        ) == true
        let livePrice = marks[trade.id]?.currentPrice ?? trade.currentPrice
        let livePnl = marks[trade.id]?.netPnl ?? marks[trade.id]?.openPnl
            ?? trade.netPnl ?? trade.openPnl

        return VStack(alignment: .leading, spacing: 10) {

            HStack {

                VStack(alignment: .leading, spacing: 4) {

                    Text(
                        marks[trade.id]?.displaySymbol
                            ?? trade.marketDisplaySymbol
                    )
                        .font(.headline)

                    Text(trade.direction.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(directionColor(trade.direction))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {

                    if let pnl = costBasisUnavailable ? nil : livePnl {
                        Text(pnl.currency)
                            .font(.headline.bold())
                            .foregroundStyle(pnl >= 0 ? .green : .red)
                    } else {
                        Text("Unavailable")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }

                    Text("P/L")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {

                if !costBasisUnavailable {
                    miniStat(title: "Entry", value: trade.entryPrice.price)
                    Spacer()
                }

                if let currentPrice = livePrice, currentPrice > 0 {
                    miniStat(title: "Current", value: currentPrice.price)
                    Spacer()
                }

                if let quantity = trade.quantity {
                    miniStat(title: "Qty", value: String(format: "%.8g", quantity))
                }
            }

            if let quantity = trade.quantity, let currentPrice = livePrice, currentPrice > 0 {
                let marketValue = abs(quantity * currentPrice)
                HStack {
                    miniStat(title: "Market Value", value: marketValue.currency)
                    if !costBasisUnavailable, trade.entryPrice > 0,
                       let pnl = trade.openPnl {
                        Spacer()
                        miniStat(
                            title: "P/L %",
                            value: String(format: "%.2f%%", pnl / abs(quantity * trade.entryPrice) * 100)
                        )
                    }
                }
            }

            if costBasisUnavailable {
                Text("Cost basis and P/L unavailable from this broker history.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack {

                Label(
                    trade.platform ?? "Manual",
                    systemImage: "building.columns"
                )

                Spacer()

                Text(trade.brokerAccountName ?? trade.accountGroupKey ?? "No account")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func miniStat(
        title: String,
        value: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 2) {

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption.bold())
        }
    }

    private func directionColor(
        _ direction: String
    ) -> Color {

        let value = direction.lowercased()

        if value.contains("long") || value.contains("buy") {
            return .green
        }

        if value.contains("short") || value.contains("sell") {
            return .red
        }

        return .secondary
    }
}

private extension Double {

    var currency: String {
        formatted(.currency(code: "USD"))
    }

    var price: String {
        formatted(.number.precision(.fractionLength(2)))
    }
}
