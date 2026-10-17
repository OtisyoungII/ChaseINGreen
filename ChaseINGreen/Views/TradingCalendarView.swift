//
//  TradingCalendarView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import SwiftUI

struct TradingCalendarView: View {
    @StateObject private var viewModel = TradingCalendarViewModel()
    @State private var scope: TradingCalendarViewModel.Scope = .month
    @State private var visibleMonth = Date()
    @State private var exitReview: LoggedTradeResponse?

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

                calendarControls

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
            }
            .padding()
        }
        .background(AppTheme.deepBlack.ignoresSafeArea())
        .sheet(isPresented: Binding(
            get: { viewModel.selectedDate != nil },
            set: { if !$0 { viewModel.clearSelection() } }
        )) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if viewModel.isLoadingDay { ProgressView("Loading day…") }
                        if let error = viewModel.dayErrorMessage {
                            Text(error).foregroundStyle(.red)
                        }
                        if let detail = viewModel.selectedDay {
                            selectedDayCard(detail)
                        }
                    }
                    .padding()
                }
                .background(AppTheme.deepBlack.ignoresSafeArea())
                .sheet(item: $exitReview) { trade in
                    ManualExitConfirmationSheet(trade: trade, accessToken: accessToken) {
                        await loadCalendar(force: true)
                    }
                }
                .navigationTitle(viewModel.selectedDate ?? "Trading day")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { viewModel.clearSelection() }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ledgerTruthDidChange)) { _ in
            Task { await loadCalendar(force: true) }
        }
        .task {
            await loadCalendar()
        }
        .refreshable {
            await loadCalendar(force: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            viewModel.clearSelection()
            Task { await loadCalendar(force: true) }
        }
        .onChange(of: scope) {
            viewModel.clearSelection()
            Task {
                await loadCalendar()
            }
        }
        .onChange(of: visibleMonth) {
            guard scope == .month else {
                return
            }
            viewModel.clearSelection()
            Task {
                await loadCalendar()
            }
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
                    await loadCalendar(force: true)
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

    private var calendarControls: some View {
        VStack(spacing: 12) {
            Picker("Calendar range", selection: $scope) {
                ForEach(TradingCalendarViewModel.Scope.allCases) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)

            if scope == .month {
                HStack {
                    Button {
                        shiftMonth(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }

                    Spacer()

                    Text(monthTitle(visibleMonth))
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.softGold)

                    Spacer()

                    Button {
                        shiftMonth(1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(isCurrentMonth)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.gold)
            } else {
                Text(
                    "All history is grouped by month. Closed historical days are reused from the local cache."
                )
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private func summaryCard(_ summary: TradingCalendarSummaryResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.softGold)

            HStack {
                stat("Days", "\(summary.totalDays)")
                stat("Green", summary.monetaryTotalsComparable == false ? "--" : "\(summary.greenDays)")
                stat("Red", summary.monetaryTotalsComparable == false ? "--" : "\(summary.redDays)")
            }

            HStack {
                stat("Known realized P&L", summary.monetaryTotalsComparable == false ? "Currency unavailable" : LaunchAccountingPolicy.monetaryText(summary.totalPnl, currency: summary.currency))
                stat("Avg Day", summary.monetaryTotalsComparable == false ? "Unavailable" : LaunchAccountingPolicy.monetaryText(summary.averageDailyPnl, currency: summary.currency))
                stat("Known-outcome Win Rate", "\(Int(summary.winRate.rounded()))%")
            }

            if let unresolved = summary.unconfirmedPnlCount,
               unresolved > 0 {
                Text(
                    "Incomplete statistics: \(unresolved) closed trade\(unresolved == 1 ? "" : "s") have unknown exit P/L. Enter the historical execution price to complete them."
                )
                .font(.caption.bold())
                .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(AppTheme.cardBlack)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var calendarGrid: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(monthSections) { section in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text(section.title)
                            .font(.headline.bold())
                            .foregroundStyle(AppTheme.softGold)

                        Rectangle()
                            .fill(AppTheme.gold.opacity(0.35))
                            .frame(height: 1)
                    }

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(section.days) { day in
                            dayButton(day)
                        }
                    }
                }
            }
        }
    }

    private func dayButton(
        _ day: TradingCalendarDayResponse
    ) -> some View {
        Button {
            Task {
                await viewModel.loadDay(
                    day.tradeDate,
                    accessToken: accessToken
                )
            }
        } label: {
            VStack(spacing: 5) {
                Text(dayNumber(day.tradeDate))
                    .font(.caption2.bold())

                Text(day.monetaryTotalsComparable == false ? "Unavailable" : LaunchAccountingPolicy.monetaryText(day.totalPnl, currency: day.currency))
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

    private func selectedDayCard(_ detail: TradingCalendarDayDetailResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(viewModel.selectedDate ?? detail.day?.tradeDate ?? "Selected Day")
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
                    if let fills = day.brokerExecutionCount, fills > 0 {
                        stat("Broker fills", "\(fills)")
                    }
                    stat("P&L", day.monetaryTotalsComparable == false ? "Unavailable" : LaunchAccountingPolicy.monetaryText(day.totalPnl, currency: day.currency))
                    stat("Win Rate", "\(Int(day.winRate.rounded()))%")
                }


                if let unconfirmed = day.unconfirmedPnlTrades,
                   unconfirmed > 0 {
                    Label(
                        "\(unconfirmed) closed trade\(unconfirmed == 1 ? "" : "s") with unknown exit P/L — review to confirm",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                }

                Text(day.summary)
                    .font(.caption)
                    .foregroundStyle(
                        day.monetaryTotalsComparable != false && day.totalPnl < 0
                            ? Color.red
                            : color(for: day)
                    )
            }

            if !detail.confirmedFills.isEmpty {
                Text("Broker-confirmed fills • separate from trade P&L")
                    .font(.caption.bold())
                ForEach(detail.confirmedFills) { fill in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(fill.side) \(fill.symbol) • \(String(format: "%.4g", fill.quantity)) @ \(String(format: "%.6g", fill.price)) \(fill.currency ?? "")")
                        Text(fill.executedAt).foregroundStyle(AppTheme.secondaryText)
                        if let pnl = fill.realizedPnl {
                            Text("Broker-reported realized P&L: \(String(format: "%.2f", pnl)) \(fill.currency ?? "")")
                        }
                    }
                    .font(.caption)
                }
            }

            if detail.trades.isEmpty && detail.confirmedFills.isEmpty {
                Text("No trades or confirmed fills for this day.")
                    .foregroundStyle(AppTheme.secondaryText)
            }

            if !detail.trades.isEmpty {
                Text("Recorded trades • manual and broker records")
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
                    trade.knownEntryPrice.map(money) ?? "Unavailable"
                )
                detailLine(
                    "Exit",
                    trade.exitPrice.map(money)
                        ?? "Exit price not supplied"
                )
                detailLine(
                    "Close confirmation",
                    trade.exitPriceConfirmed
                        ? (trade.sourceMode == "manual" ? "Manually confirmed" : "Confirmed execution")
                        : "Unconfirmed"
                )

                if !trade.isOpen && !trade.exitPriceConfirmed && trade.sourceMode == "manual" {
                    Button("Confirm exit price") { exitReview = trade }
                }
                if let notes = trade.notes, !notes.isEmpty {
                    detailLine("Notes", notes)
                }

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
                    Text(trade.marketDisplaySymbol)
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

    private var monthSections: [CalendarMonthSection] {
        let grouped = Dictionary(grouping: viewModel.days) {
            String($0.tradeDate.prefix(7))
        }

        return grouped.keys.sorted(by: >).map { key in
            CalendarMonthSection(
                id: key,
                title: monthTitle(key),
                days: (grouped[key] ?? []).sorted {
                    $0.tradeDate < $1.tradeDate
                }
            )
        }
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(
            visibleMonth,
            equalTo: Date(),
            toGranularity: .month
        )
    }

    private func loadCalendar(
        force: Bool = false
    ) async {
        await viewModel.refresh(
            accessToken: accessToken,
            scope: scope,
            month: visibleMonth,
            force: force
        )
    }

    private func shiftMonth(_ amount: Int) {
        if let next = Calendar.current.date(
            byAdding: .month,
            value: amount,
            to: visibleMonth
        ) {
            visibleMonth = min(next, Date())
        }
    }

    private func monthTitle(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    private func monthTitle(_ key: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"

        guard let date = formatter.date(from: key) else {
            return key
        }

        return monthTitle(date)
    }

    private func dayNumber(_ value: String) -> String {
        String(value.suffix(2))
    }
}

private struct CalendarMonthSection: Identifiable {
    let id: String
    let title: String
    let days: [TradingCalendarDayResponse]
}

private extension LoggedTradeResponse {
    var calendarStableId: String {
        id.uuidString
    }
}
