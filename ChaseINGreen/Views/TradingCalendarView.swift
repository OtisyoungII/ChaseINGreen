//
//  TradingCalendarView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import SwiftUI

struct TradingCalendarView: View {
    @StateObject private var viewModel = TradingCalendarViewModel()

    let accessToken: String

    private let columns = [
        GridItem(.adaptive(minimum: 48), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let summary = viewModel.summary {
                    summaryCard(summary)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.danger)
                }

                calendarGrid

                if let selected = viewModel.selectedDay {
                    selectedDayCard(selected)
                }
            }
            .padding()
        }
        .background(AppTheme.deepBlack.ignoresSafeArea())
        .task {
            await viewModel.refresh(accessToken: accessToken)
        }
        .refreshable {
            await viewModel.refresh(accessToken: accessToken)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Trading Calendar")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.softGold)

                Text("Daily P&L, trade count, win rate, and behavior review.")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            Button {
                Task {
                    await viewModel.refresh(accessToken: accessToken)
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.headline.bold())
                    .frame(width: 44, height: 44)
                    .foregroundStyle(AppTheme.gold)
            }
            .buttonStyle(.plain)
        }
    }

    private func summaryCard(_ summary: TradingCalendarSummaryResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.softGold)

            HStack {
                stat("Days", "\(summary.totalDays)")
                stat("Green", "\(summary.greenDays)")
                stat("Red", "\(summary.redDays)")
            }

            HStack {
                stat("Net P&L", money(summary.totalPnl))
                stat("Avg Day", money(summary.averageDailyPnl))
                stat("Win Rate", "\(Int(summary.winRate.rounded()))%")
            }
        }
        .padding()
        .background(AppTheme.cardBlack)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(viewModel.days) { day in
                Button {
                    Task {
                        await viewModel.loadDay(day.tradeDate, accessToken: accessToken)
                    }
                } label: {
                    VStack(spacing: 5) {
                        Text(shortDate(day.tradeDate))
                            .font(.caption2.bold())

                        Text(money(day.totalPnl))
                            .font(.caption.bold())
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                    .frame(height: 52)
                    .frame(maxWidth: .infinity)
                    .background(color(for: day).opacity(0.22))
                    .foregroundStyle(color(for: day))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func selectedDayCard(_ detail: TradingCalendarDayDetailResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(detail.day?.tradeDate ?? "Selected Day")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.softGold)

                Spacer()

                Button("Close") {
                    viewModel.clearSelection()
                }
                .font(.caption.bold())
                .foregroundStyle(AppTheme.gold)
            }

            if let day = detail.day {
                HStack {
                    stat("Trades", "\(day.totalTrades)")
                    stat("P&L", money(day.totalPnl))
                    stat("Win Rate", "\(Int(day.winRate.rounded()))%")
                }

                if let unconfirmed = day.unconfirmedPnlTrades,
                   unconfirmed > 0 {
                    Label(
                        "\(unconfirmed) closed trade\(unconfirmed == 1 ? "" : "s") waiting for broker-confirmed exit P/L",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                }

                Text(day.summary)
                    .font(.caption)
                    .foregroundStyle(AppTheme.primaryText)
            }

            if !detail.trades.isEmpty {
                Text("Broker-confirmed trade review")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.secondaryText)

                ForEach(detail.trades, id: \.calendarStableId) { trade in
                    tradeRow(trade)
                }
            }
        }
        .padding()
        .background(AppTheme.cardBlack)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func tradeRow(_ trade: LoggedTradeResponse) -> some View {
        let tradePnl: Double? = trade.isOpen
            ? trade.openPnl
            : (
                trade.exitPriceConfirmed
                    ? trade.netPnl ?? trade.realizedPnl
                    : nil
            )

        return DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                detailLine(
                    "Account",
                    trade.brokerAccountName
                        ?? trade.brokerAccountId
                        ?? "Not assigned"
                )
                detailLine(
                    "Broker",
                    trade.platform ?? "Manual"
                )
                detailLine(
                    "Direction / size",
                    "\(trade.direction.uppercased()) • "
                    + (trade.quantity.map {
                        String(format: "%.4g", $0)
                    } ?? "Unknown")
                )
                detailLine(
                    "Entry",
                    money(trade.entryPrice)
                )
                detailLine(
                    "Exit",
                    trade.exitPrice.map(money)
                        ?? "Waiting for broker"
                )
                detailLine(
                    "Close confirmation",
                    trade.exitPriceConfirmed
                        ? "Broker confirmed"
                        : "Unconfirmed"
                )

                if let source = trade.closeSource,
                   !source.isEmpty {
                    detailLine(
                        "Source",
                        source.replacingOccurrences(
                            of: "_",
                            with: " "
                        )
                    )
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(trade.symbol)
                        .font(.caption.bold())
                        .foregroundStyle(.white)

                    Text(
                        trade.brokerAccountName
                            ?? trade.brokerAccountId
                            ?? "Account unavailable"
                    )
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.softGold)

                    Text(
                        trade.isOpen
                            ? "Open • \(trade.platform ?? "Manual")"
                            : (
                                trade.exitPriceConfirmed
                                    ? "Closed • Confirmed"
                                    : "Closed • Exit unconfirmed"
                            )
                    )
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Text(tradePnl.map(money) ?? "Review")
                    .font(.caption.bold())
                    .foregroundStyle(
                        tradePnl.map {
                            $0 >= 0 ? Color.green : Color.red
                        }
                            ?? Color.orange
                    )
            }
        }
        .tint(AppTheme.gold)
        .padding(10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func detailLine(
        _ title: String,
        _ value: String
    ) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.secondaryText)

            Spacer()

            Text(value)
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.secondaryText)

            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func color(for day: TradingCalendarDayResponse) -> Color {
        switch day.calendarTone.lowercased() {
        case "green": return .green
        case "red": return .red
        default: return .orange
        }
    }

    private func money(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    private func shortDate(_ value: String) -> String {
        String(value.suffix(5))
    }
}

private extension LoggedTradeResponse {
    var calendarStableId: String {
        id.uuidString
    }
}
