//
//  TradingWorkspaceView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import SwiftUI

struct TradingWorkspaceView: View {
    @StateObject private var viewModel = TradingWorkspaceViewModel()
    
    let accessToken: String
    let symbol: String
    let direction: String?
    let broker: String?
    let accountKey: String?
    
    init(
        accessToken: String,
        symbol: String = "TQQQ",
        direction: String? = nil,
        broker: String? = nil,
        accountKey: String? = nil
    ) {
        self.accessToken = accessToken
        self.symbol = symbol.uppercased()
        self.direction = direction
        self.broker = broker
        self.accountKey = accountKey
    }
    
    private var selectedSymbol: String {
        viewModel.traderOS?.symbol?.uppercased() ?? symbol.uppercased()
    }
    
    private var selectedSymbolTrades: [LoggedTradeResponse] {
        viewModel.openTrades.filter {
            $0.symbol.uppercased() == selectedSymbol.uppercased()
        }
    }
    
    private var sortedOpenTrades: [LoggedTradeResponse] {
        selectedSymbolTrades + viewModel.openTrades.filter {
            $0.symbol.uppercased() != selectedSymbol.uppercased()
        }
    }
    
    private var selectedSymbolOpenPnl: Double {
        selectedSymbolTrades.compactMap { $0.netPnl ?? $0.openPnl }.reduce(0, +)
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        
                        if viewModel.isLoading {
                            ProgressView("Loading Trader Workspace...")
                                .frame(maxWidth: .infinity, minHeight: 180)
                        } else if let errorMessage = viewModel.errorMessage {
                            errorCard(errorMessage)
                        } else {
                            cardDeck(isWide: proxy.size.width >= 760)
                        }
                    }
                    .padding()
                    .frame(maxWidth: proxy.size.width >= 760 ? 1180 : .infinity)
                    .frame(maxWidth: .infinity)
                }
                
                if let zoomedCard = viewModel.zoomedCard {
                    zoomOverlay(card: zoomedCard)
                }
            }
        }
        .task {
            await viewModel.load(
                symbol: symbol,
                direction: direction,
                broker: broker,
                accountKey: accountKey,
                accessToken: accessToken
            )
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bat Cave")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.primaryText)
            
            HStack(spacing: 10) {
                Label(selectedSymbol, systemImage: "scope")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.softGold)
                
                if let direction {
                    pill(direction.uppercased(), tint: AppTheme.primaryText)
                }
                
                if let broker {
                    pill(broker, tint: AppTheme.secondaryText)
                }
            }
            
            Text(viewModel.workspace?.effectiveSummary ?? "Trader OS command center for AI, broker quote source, timeframes, open trades, accounts, calendar, ML insights, journal, and stats.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }
    
    private func cardDeck(isWide: Bool) -> some View {
        Group {
            if isWide {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(TradingWorkspaceCard.allCases) { card in
                            workspaceCard(card)
                                .frame(width: 340)
                                .frame(minHeight: 285)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                VStack(spacing: 14) {
                    ForEach(TradingWorkspaceCard.allCases) { card in
                        workspaceCard(card)
                    }
                }
            }
        }
    }
    
    private func workspaceCard(_ card: TradingWorkspaceCard) -> some View {
        Button {
            viewModel.zoom(card)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(card.title, systemImage: card.systemImage)
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.softGold)
                    
                    Spacer()
                    
                    Text(selectedSymbol)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.secondaryText)
                }
                
                Divider()
                
                cardContent(card)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                tapHint
            }
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var tapHint: some View {
        Text("Tap for details")
            .font(.caption2.bold())
            .foregroundStyle(AppTheme.softGold)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    @ViewBuilder
    private func cardContent(_ card: TradingWorkspaceCard) -> some View {
        switch card {
            
        case .traderOS:
            TraderOSWorkspaceCard(
                traderOS: viewModel.traderOS,
                selectedSymbol: selectedSymbol
            )
            
        case .quoteSource:
            if let quote = viewModel.traderOS?.quoteResolution {
                VStack(alignment: .leading, spacing: 8) {
                    Text(quote.symbol ?? selectedSymbol)
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.primaryText)
                    
                    detailGrid([
                        ("Price", formatPrice(quote.price)),
                        ("Provider", quote.provider ?? "unknown"),
                        ("Broker", quote.broker ?? "none"),
                        ("Freshness", quote.freshness ?? "unknown"),
                        ("Confidence", "\(quote.confidence ?? 0)%")
                    ])
                    
                    if let warning = quote.warning, !warning.isEmpty {
                        Text("⚠️ \(warning)")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.softGold)
                    }
                }
            } else {
                Text("\(selectedSymbol) quote source not loaded yet.")
            }
            
        case .timeframes:
            if let mtf = viewModel.traderOS?.multiTimeframe {
                VStack(alignment: .leading, spacing: 8) {
                    timeframeRow("4H", mtf.trend4h)
                    timeframeRow("1H", mtf.trend1h)
                    timeframeRow("15M", mtf.trend15m)
                    timeframeRow("5M", mtf.trend5m)
                    timeframeRow("1M", mtf.trend1m)
                    
                    detailGrid([
                        ("Bias", mtf.entryBias ?? "waiting"),
                        ("Long", mtf.longAllowed == true ? "YES" : "NO"),
                        ("Short", mtf.shortAllowed == true ? "YES" : "NO")
                    ])
                    
                    if let waitReason = mtf.waitReason {
                        Text("Wait: \(waitReason)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            } else {
                Text("\(selectedSymbol) multi-timeframe data not loaded yet.")
            }
            
        case .liveMonitor:
            VStack(alignment: .leading, spacing: 8) {
                Text("Trade Doctor")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.primaryText)
                
                if selectedSymbolTrades.isEmpty {
                    Text("No tracked open trade for \(selectedSymbol).")
                    Text("Pre-trade context only until broker sync confirms a live position.")
                } else {
                    detailGrid([
                        ("Symbol Trades", "\(selectedSymbolTrades.count)"),
                        ("Symbol P/L", formatMoney(selectedSymbolOpenPnl)),
                        ("All Open", "\(viewModel.openTrades.count)")
                    ])
                    
                    ForEach(Array(selectedSymbolTrades.prefix(4)), id: \.id) { trade in
                        tradeRow(trade)
                    }
                }
            }
            
        case .openTrades:
            VStack(alignment: .leading, spacing: 8) {
                detailGrid([
                    ("Tracked Open", "\(viewModel.openTrades.count)"),
                    ("\(selectedSymbol)", "\(selectedSymbolTrades.count)"),
                    ("Symbol P/L", formatMoney(selectedSymbolOpenPnl))
                ])
                
                if selectedSymbolTrades.isEmpty {
                    Text("No open \(selectedSymbol) trade found.")
                        .foregroundStyle(AppTheme.softGold)
                }
                
                ForEach(Array(sortedOpenTrades.prefix(6)), id: \.id) { trade in
                    tradeRow(trade)
                }
            }
            
        case .calendar:
            if let calendar = viewModel.calendar {
                detailGrid([
                    ("Days", "\(calendar.summary.totalDays)"),
                    ("Green", "\(calendar.summary.greenDays)"),
                    ("Red", "\(calendar.summary.redDays)"),
                    ("Win Rate", "\(Int(calendar.summary.winRate.rounded()))%")
                ])
            } else {
                Text("Calendar not loaded yet.")
            }
            
        case .brokerAccounts:
            VStack(alignment: .leading, spacing: 8) {
                detailGrid([
                    ("Accounts", "\(viewModel.brokerAccounts.count)"),
                    ("Prop/Broker/Crypto", "Separated"),
                    ("Sync", "Manual now")
                ])
                
                ForEach(Array(viewModel.brokerAccounts.prefix(4)), id: \.id) { account in
                    accountRow(account)
                }
            }
            
        case .stats:
            if let stats = viewModel.tradeStats {
                let netPnl = stats.totalNetPnl ?? stats.totalRealizedPnl
                
                detailGrid([
                    ("Closed", "\(stats.totalClosedTrades)"),
                    ("Win Rate", formatPercent(stats.winRate)),
                    ("Net P/L", formatMoney(netPnl)),
                    ("Open P/L", formatMoney(stats.totalOpenPnl))
                ])
            } else {
                Text("Stats not loaded yet.")
            }
            
        case .journal:
            VStack(alignment: .leading, spacing: 8) {
                Text("Journal intelligence feeds Trader OS, calendar, memory, profile, coaching, and ML insights.")
                    .lineLimit(4)
                
                detailGrid([
                    ("Behavior", "Tracked"),
                    ("Coaching", "Connected"),
                    ("Memory", "Learning")
                ])
            }
            
        case .mlInsights:
            MLInsightsCard(
                memory: viewModel.mlInsights?.memory,
                patterns: viewModel.mlInsights?.patterns,
                profile: viewModel.mlInsights?.profile,
                calendar: viewModel.mlInsights?.calendar
            )
        }
    }
    private func tradeRow(_ trade: LoggedTradeResponse) -> some View {
        VStack(alignment: .leading, spacing: 6) {

            HStack {
                Text(trade.symbol.uppercased())
                    .font(.headline.bold())
                    .foregroundStyle(
                        trade.symbol.uppercased() == selectedSymbol
                        ? AppTheme.softGold
                        : AppTheme.primaryText
                    )

                Spacer()

                if let pnl = trade.netPnl ?? trade.openPnl {
                    Text(formatMoney(pnl))
                        .font(.caption.bold())
                        .foregroundStyle(pnl >= 0 ? .green : .red)
                }
            }

            HStack(spacing: 14) {

                detailMini(
                    title: "Entry",
                    value: formatPrice(trade.entryPrice)
                )

                detailMini(
                    title: "Current",
                    value: formatPrice(trade.currentPrice)
                )

                detailMini(
                    title: "Qty",
                    value: trade.quantity == nil
                        ? "--"
                        : String(format: "%.2f", trade.quantity!)
                )
            }

            if let broker = trade.platform {
                Text("Broker: \(broker)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Text("Future: tap trade → manage, partial close, notes, screenshots, AI review.")
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.vertical,4)
    }

    private func accountRow(_ account: BrokerAccountResponse) -> some View {

        VStack(alignment: .leading, spacing: 6) {

            HStack {

                Text(account.accountName ?? account.accountId)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                Text(
                    BrokerPreset.from(account.broker)?.displayName
                    ?? account.broker
                )
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)
            }

            HStack(spacing:16) {

                detailMini(
                    title: "Equity",
                    value: formatMoney(account.equity ?? account.balance)
                )

                detailMini(
                    title: "Daily DD",
                    value: formatMoney(account.dailyDrawdownRemaining)
                )

                detailMini(
                    title: "Max DD",
                    value: formatMoney(account.maxDrawdownRemaining)
                )
            }
        }
        .padding(.vertical,4)
    }

    private func detailGrid(_ rows:[(String,String)]) -> some View {

        VStack(alignment:.leading, spacing:8) {

            ForEach(rows.indices,id:\.self) { index in

                HStack {

                    Text(rows[index].0)
                        .foregroundStyle(AppTheme.secondaryText)

                    Spacer()

                    Text(rows[index].1)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
        }
    }

    private func detailMini(title:String,value:String) -> some View {

        VStack(alignment:.leading,spacing:2){

            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)

            Text(value)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.primaryText)
        }
    }

    private func pill(_ text:String,tint:Color)->some View {

        Text(text)
            .font(.caption.bold())
            .foregroundStyle(tint)
            .padding(.horizontal,10)
            .padding(.vertical,5)
            .background(AppTheme.cardBackground)
            .clipShape(Capsule())
    }

    private func timeframeRow(_ label: String, _ value: String?) -> some View {

        HStack {

            Text(label)
                .fontWeight(.bold)
                .frame(width:45,alignment:.leading)

            Text(timeframeIcon(value))

            Text(value ?? "Unknown")
                .foregroundStyle(AppTheme.primaryText)

            Spacer()
        }
    }

    private func timeframeIcon(_ value:String?) -> String {

        let clean = (value ?? "").lowercased()

        if clean.contains("bull") ||
            clean.contains("up") ||
            clean.contains("long") {

            return "🟢"
        }

        if clean.contains("bear") ||
            clean.contains("down") ||
            clean.contains("short") {

            return "🔴"
        }

        if clean.contains("wait") ||
            clean.contains("mixed") ||
            clean.contains("chop") {

            return "🟡"
        }

        return "⚪️"
    }

    private func zoomOverlay(card: TradingWorkspaceCard) -> some View {

        ZStack {

            Color.black.opacity(0.60)
                .ignoresSafeArea()

            VStack(alignment:.leading,spacing:18){

                HStack{

                    Label(card.title,
                          systemImage: card.systemImage)
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.softGold)

                    Spacer()

                    Button {

                        viewModel.closeZoom()

                    } label: {

                        Image(systemName:"xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.gold)
                    }
                }

                Text("Workspace Details")
                    .font(.headline)
                    .foregroundStyle(AppTheme.primaryText)

                Text("""
This screen is becoming the central Bat Cave for every trading decision.

Eventually every card will open its own screen:

• Trader OS
• Broker Accounts
• Calendar
• Journal
• Statistics
• Open Trades
• Live Trade Monitor
• ML Insights
• Quote Source
• Timeframes

Everything will drill into deeper analytics instead of static cards.
""")
                .foregroundStyle(AppTheme.secondaryText)

                Divider()

                ScrollView{

                    cardContent(card)
                        .frame(maxWidth:.infinity,
                               alignment:.leading)
                }
            }
            .padding()
            .frame(maxWidth:760,
                   maxHeight:700)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius:24))
            .padding()
        }
    }

    private func errorCard(_ message:String)->some View{

        VStack(alignment:.leading,spacing:8){

            Text("Workspace Error")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.softGold)

            Text(message)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius:18))
    }

    private func formatPrice(_ value:Double?)->String{

        guard let value else { return "--" }

        return String(format:"%.2f",value)
    }

    private func formatPercent(_ value:Double?)->String{

        guard let value else { return "--" }

        return String(format:"%.1f%%",value)
    }

    private func formatMoney(_ value:Double?)->String{

        guard let value else { return "--" }

        return String(
            format:"%@%.2f",
            value >= 0 ? "+$" : "-$",
            abs(value)
        )
    }
}
