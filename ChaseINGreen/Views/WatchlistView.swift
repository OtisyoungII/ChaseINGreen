//
//  WatchlistView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 5/26/26.
//

import SwiftUI

struct WatchlistView: View {
    let accessToken: String
    let onSelectSymbol: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var deletingWatchlistIds: Set<UUID> = []

    @State private var watchlists: [WatchlistResponse] = []
    @State private var quotesBySymbol: [String: QuoteResponse] = [:]
    @State private var quoteSavedAtBySymbol: [String: Date] = [:]

    @State private var selectedWatchlistId: UUID?
    @State private var titleText = ""
    @State private var symbolText = ""

    @State private var isLoading = false
    @State private var isLoadingQuotes = false
    @State private var errorMessage: String?
    
    private var titleTextField: some View {
        let field = TextField("Title ex: Morning Movers", text: $titleText)
            .appTextField()

    #if os(iOS)
        return field
            .textInputAutocapitalization(.words)
    #else
        return field
    #endif
    }

    private var symbolTextField: some View {
        let field = TextField("Add symbols ex: Bitcoin, BTC, TQQQ, NVDA", text: $symbolText)
            .appTextField()

    #if os(iOS)
        return field
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
    #else
        return field
    #endif
    }

    private let quoteRefreshTimer = Timer.publish(every: 120, on: .main, in: .common).autoconnect()
    private let quoteCacheSeconds: TimeInterval = 90
    
    private var leadingToolbarPlacement: ToolbarItemPlacement {
    #if os(iOS)
        return .topBarLeading
    #else
        return .automatic
    #endif
    }

    private var trailingToolbarPlacement: ToolbarItemPlacement {
    #if os(iOS)
        return .topBarTrailing
    #else
        return .automatic
    #endif
    }

    private var selectedWatchlist: WatchlistResponse? {
        watchlists.first { $0.id == selectedWatchlistId }
    }

    private var canSaveNewList: Bool {
        !titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !parsedInputSymbols.isEmpty &&
        selectedWatchlistId == nil
    }

    private var parsedInputSymbols: [String] {
        parseSymbols(symbolText)
    }

    private var suggestions: [SmartSymbol] {
        let raw = symbolText
            .split(separator: ",")
            .last
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !raw.isEmpty else { return [] }
        return SmartSymbol.matches(raw)
    }

    private var allSymbols: [String] {
        var seen = Set<String>()
        var output: [String] = []

        for watchlist in watchlists {
            for symbol in watchlist.symbols {
                let cleaned = normalizeSymbol(symbol)
                guard !cleaned.isEmpty, !seen.contains(cleaned) else { continue }

                seen.insert(cleaned)
                output.append(cleaned)
            }
        }

        return output
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        editorSection
                        listSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Watchlists")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: leadingToolbarPlacement) {
                    Button {
                        Task {
                            await loadAll(forceQuotes: true)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .foregroundStyle(AppTheme.gold)
                }

                ToolbarItem(placement: trailingToolbarPlacement) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.gold)
                }
            }
            .task {
                await loadAll(forceQuotes: false)
            }
            .refreshable {
                await loadAll(forceQuotes: true)
            }
            .onReceive(quoteRefreshTimer) { _ in
                Task { await loadQuotes(force: false) }
            }
        }
    }

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedWatchlistId == nil ? "Create Watchlist" : "Edit Watchlist")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.softGold)

            if !watchlists.isEmpty {
                Picker("List", selection: Binding(
                    get: { selectedWatchlistId },
                    set: { newValue in
                        selectedWatchlistId = newValue
                        loadSelectedListIntoEditor()
                    }
                )) {
                    Text("New List").tag(UUID?.none)

                    ForEach(watchlists) { watchlist in
                        Text(watchlist.title).tag(UUID?.some(watchlist.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.gold)
            }

            titleTextField

            symbolTextField

            if !suggestions.isEmpty {
                suggestionStrip
            }

            if selectedWatchlistId == nil {
                Button {
                    Task { await createWatchlist() }
                } label: {
                    Text("Save Watchlist")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.deepBlack)
                .background(AppTheme.gold)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .disabled(!canSaveNewList)
                .opacity(canSaveNewList ? 1 : 0.45)
            } else {
                Button {
                    Task { await addSymbolsToSelectedList() }
                } label: {
                    Text("Add To Selected List")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.deepBlack)
                .background(AppTheme.gold)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .disabled(parsedInputSymbols.isEmpty)
                .opacity(parsedInputSymbols.isEmpty ? 0.45 : 1)
            }
        }
        .padding()
        .background(AppTheme.cardBlack)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var suggestionStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Possible matches")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.secondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions) { item in
                        Button {
                            applySuggestion(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.caption.bold())

                                Text(item.symbol)
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(AppTheme.gold)
                            .background(AppTheme.gold.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Watchlists")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.softGold)

                Spacer()

                if isLoadingQuotes {
                    ProgressView()
                        .tint(AppTheme.gold)
                }
            }

            if isLoading {
                ProgressView()
                    .tint(AppTheme.gold)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }

            if watchlists.isEmpty && !isLoading {
                Text("No watchlists yet. Create one above.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            ForEach(watchlists) { watchlist in
                watchlistCard(watchlist)
            }
        }
    }

    private func watchlistCard(_ watchlist: WatchlistResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    selectedWatchlistId = watchlist.id
                    loadSelectedListIntoEditor()
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(watchlist.title)
                            .font(.headline.bold())
                            .foregroundStyle(AppTheme.primaryText)

                        Text("\(watchlist.symbols.count) symbols • Tap to edit")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                if watchlist.isDefault {
                    Text("Default")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.gold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.gold.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            if watchlist.symbols.isEmpty {
                Text("No symbols saved.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(watchlist.symbols.map { normalizeSymbol($0) }, id: \.self) { symbol in
                        symbolQuoteRow(symbol, watchlist: watchlist)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.cardBlack)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(selectedWatchlistId == watchlist.id ? AppTheme.gold : AppTheme.cardStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func symbolQuoteRow(_ symbol: String, watchlist: WatchlistResponse) -> some View {
        let cleaned = normalizeSymbol(symbol)
        let quote = quotesBySymbol[cleaned]
        let tint = quoteTint(quote)

        return HStack(spacing: 12) {
            Button {
                onSelectSymbol(cleaned)
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: iconName(for: cleaned))
                        .font(.title3)
                        .foregroundStyle(tint)
                        .frame(width: 36, height: 36)
                        .background(tint.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(displayName(for: cleaned, quote: quote))
                            .font(.headline.bold())
                            .foregroundStyle(AppTheme.primaryText)

                        Text(quote?.instrumentName ?? "Loading quote...")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(formatPrice(quote?.price))
                            .font(.headline.bold())
                            .foregroundStyle(AppTheme.primaryText)

                        Text(formatPercentChange(quote?.percentChange))
                            .font(.caption.bold())
                            .foregroundStyle(tint)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                guard !deletingWatchlistIds.contains(watchlist.id) else { return }

                Task {
                    await removeSymbol(cleaned, from: watchlist)
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .disabled(deletingWatchlistIds.contains(watchlist.id))
            .opacity(deletingWatchlistIds.contains(watchlist.id) ? 0.4 : 1)
        }
        .padding()
        .background(AppTheme.deepBlack.opacity(0.45))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func loadAll(forceQuotes: Bool = false) async {
        await loadWatchlists()
        await loadQuotes(force: forceQuotes)
    }

    private func loadWatchlists() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            errorMessage = nil
            watchlists = try await APIService.shared.fetchWatchlists(accessToken: accessToken)

            if selectedWatchlistId == nil, let first = watchlists.first {
                selectedWatchlistId = first.id
                loadSelectedListIntoEditor()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadQuotes(force: Bool = false) async {
        guard !isLoadingQuotes else { return }

        let symbols = allSymbols

        guard !symbols.isEmpty else {
            quotesBySymbol = [:]
            quoteSavedAtBySymbol = [:]
            return
        }

        let symbolsNeedingRefresh = symbols.filter { symbol in
            if force { return true }

            guard let savedAt = quoteSavedAtBySymbol[symbol] else {
                return true
            }

            return Date().timeIntervalSince(savedAt) >= quoteCacheSeconds
        }

        guard !symbolsNeedingRefresh.isEmpty else {
            print("📦 Watchlist quotes using local cache.")
            return
        }

        isLoadingQuotes = true
        defer { isLoadingQuotes = false }

        for symbol in symbolsNeedingRefresh {
            do {
                let quote = try await APIService.shared.fetchQuote(
                    for: symbol,
                    accessToken: accessToken,
                    forceRefresh: force
                )

                quotesBySymbol[symbol] = quote
                quoteSavedAtBySymbol[symbol] = Date()
            } catch {
                print("⚠️ Failed to load watchlist quote for \(symbol): \(error.localizedDescription)")
            }
        }
    }

    private func createWatchlist() async {
        let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let symbols = parsedInputSymbols

        guard !title.isEmpty, !symbols.isEmpty else {
            errorMessage = "Add a title and at least one symbol."
            return
        }

        do {
            errorMessage = nil

            let created = try await APIService.shared.createWatchlist(
                WatchlistCreateRequest(
                    title: title,
                    symbols: symbols,
                    isDefault: watchlists.isEmpty
                ),
                accessToken: accessToken
            )

            selectedWatchlistId = created.id
            titleText = created.title
            symbolText = ""

            await loadWatchlists()
            await loadQuotes(force: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addSymbolsToSelectedList() async {
        guard let selectedWatchlist else { return }

        let existing = selectedWatchlist.symbols.map { normalizeSymbol($0) }
        let merged = mergeSymbols(existing + parsedInputSymbols)

        await updateWatchlist(
            selectedWatchlist,
            title: selectedWatchlist.title,
            symbols: merged,
            isDefault: selectedWatchlist.isDefault
        )

        symbolText = ""
    }

    private func removeSymbol(_ symbol: String, from watchlist: WatchlistResponse) async {
        guard !deletingWatchlistIds.contains(watchlist.id) else { return }

        let updatedSymbols = watchlist.symbols
            .map { normalizeSymbol($0) }
            .filter { $0 != symbol }

        do {
            errorMessage = nil

            if updatedSymbols.isEmpty {
                deletingWatchlistIds.insert(watchlist.id)

                try await APIService.shared.deleteWatchlist(
                    watchlistId: watchlist.id,
                    accessToken: accessToken
                )

                await loadWatchlists()

                deletingWatchlistIds.remove(watchlist.id)
                return
            }

            await updateWatchlist(
                watchlist,
                title: watchlist.title,
                symbols: updatedSymbols,
                isDefault: watchlist.isDefault
            )
        } catch {
            deletingWatchlistIds.remove(watchlist.id)
            errorMessage = error.localizedDescription
        }
    }

    private func updateWatchlist(
        _ watchlist: WatchlistResponse,
        title: String,
        symbols: [String],
        isDefault: Bool
    ) async {
        do {
            errorMessage = nil

            _ = try await APIService.shared.updateWatchlist(
                watchlistId: watchlist.id,
                payload: WatchlistUpdateRequest(
                    title: title,
                    symbols: symbols,
                    isDefault: isDefault
                ),
                accessToken: accessToken
            )

            await loadWatchlists()
            await loadQuotes(force: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadSelectedListIntoEditor() {
        guard let selectedWatchlist else {
            titleText = ""
            symbolText = ""
            return
        }

        titleText = selectedWatchlist.title
        symbolText = ""
    }

    private func applySuggestion(_ item: SmartSymbol) {
        var parts = symbolText
            .split(separator: ",", omittingEmptySubsequences: false)
            .map(String.init)

        if parts.isEmpty {
            symbolText = item.symbol
            return
        }

        parts[parts.count - 1] = item.symbol
        symbolText = parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        if !symbolText.hasSuffix(", ") {
            symbolText += ", "
        }
    }

    private func parseSymbols(_ value: String) -> [String] {
        mergeSymbols(
            value
                .split(separator: ",")
                .map { normalizeSymbol(String($0)) }
        )
    }

    private func mergeSymbols(_ symbols: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []

        for symbol in symbols {
            let cleaned = normalizeSymbol(symbol)

            guard !cleaned.isEmpty, !seen.contains(cleaned) else { continue }

            seen.insert(cleaned)
            output.append(cleaned)
        }

        return output
    }

    private func normalizeSymbol(_ value: String) -> String {
        SmartSymbol.normalized(value)
    }

    private func displayName(for symbol: String, quote: QuoteResponse?) -> String {
        if let match = SmartSymbol.known.first(where: { $0.symbol == symbol }) {
            return match.title
        }

        return quote?.displaySymbol ?? symbol
    }

    private func iconName(for symbol: String) -> String {
        if symbol.contains("BTC") {
            return "bitcoinsign.circle.fill"
        }

        if symbol.contains("ETH") {
            return "e.circle.fill"
        }

        if symbol.contains("GC") || symbol.contains("XAU") {
            return "medal.fill"
        }

        if symbol.contains("SI") || symbol.contains("XAG") {
            return "medal.fill"
        }

        if symbol.contains("CL") || symbol.contains("WTI") {
            return "drop.fill"
        }

        if symbol.contains("JPY") || symbol.contains("GBP") || symbol.contains("EUR") {
            return "dollarsign.arrow.circlepath"
        }
        if symbol.contains("DOGE") ||
           symbol.contains("HBAR") ||
           symbol.contains("SOL") ||
           symbol.contains("XRP") ||
           symbol.contains("ADA") ||
           symbol.contains("AVAX") ||
           symbol.contains("LINK") ||
           symbol.contains("LTC") {
            return "bitcoinsign.circle.fill"
        }

        if symbol.contains("NG") {
            return "flame.fill"
        }

        if symbol.contains("BZ") {
            return "drop.fill"
        }

        return "chart.line.uptrend.xyaxis"
    }

    private func formatPrice(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "$%.2f", value)
    }

    private func formatPercentChange(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%+.2f%%", value)
    }

    private func quoteTint(_ quote: QuoteResponse?) -> Color {
        guard let percentChange = quote?.percentChange else {
            return AppTheme.secondaryText
        }

        if percentChange > 0 { return .green }
        if percentChange < 0 { return .red }

        return AppTheme.secondaryText
    }
}

private struct SmartSymbol: Identifiable, Hashable {
    let title: String
    let symbol: String
    let aliases: [String]

    var id: String { symbol }

    static let known: [SmartSymbol] = [
        .init(title: "Bitcoin", symbol: "BTC-USD", aliases: ["BTC", "BTCUSD", "BITCOIN", "BTC-USD"]),
        .init(title: "Ethereum", symbol: "ETH-USD", aliases: ["ETH", "ETHUSD", "ETHERIUM", "ETHEREUM", "ETH-USD"]),
        .init(title: "Gold", symbol: "GC=F", aliases: ["GOLD", "XAU", "XAUUSD", "GC", "GC=F"]),
        .init(title: "Silver", symbol: "SI=F", aliases: ["SILVER", "XAG", "XAGUSD", "SI", "SI=F"]),
        .init(title: "WTI Oil", symbol: "CL=F", aliases: ["OIL", "WTI", "USOIL", "CL", "CL=F"]),
        .init(title: "Nasdaq Futures", symbol: "NQ=F", aliases: ["NQ", "MNQ", "NAS100", "NASDAQ", "NQ=F"]),
        .init(title: "S&P Futures", symbol: "ES=F", aliases: ["ES", "MES", "SP500", "S&P", "ES=F"]),
        .init(title: "US30", symbol: "^DJI", aliases: ["US30", "DOW", "DJI", "^DJI"]),
        .init(title: "GBP/USD", symbol: "GBPUSD=X", aliases: ["GBPUSD", "GBP/USD"]),
        .init(title: "GBP/JPY", symbol: "GBPJPY=X", aliases: ["GBPJPY", "GBP/JPY"]),
        .init(title: "USD/JPY", symbol: "USDJPY=X", aliases: ["USDJPY", "USD/JPY"]),
        .init(title: "EUR/USD", symbol: "EURUSD=X", aliases: ["EURUSD", "EUR/USD"]),
        .init(title: "TQQQ", symbol: "TQQQ", aliases: ["TQQQ"]),
        .init(title: "QQQ", symbol: "QQQ", aliases: ["QQQ"]),
        .init(title: "SPY", symbol: "SPY", aliases: ["SPY"]),
        .init(title: "NVIDIA", symbol: "NVDA", aliases: ["NVDA", "NVIDIA"]),
        .init(title: "AMD", symbol: "AMD", aliases: ["AMD"]),
        .init(title: "Tesla", symbol: "TSLA", aliases: ["TSLA", "TESLA"]),
        .init(title: "Meta", symbol: "META", aliases: ["META", "FACEBOOK"]),
        .init(title: "Apple", symbol: "AAPL", aliases: ["AAPL", "APPLE"]),
        .init(title: "Microsoft", symbol: "MSFT", aliases: ["MSFT", "MICROSOFT"]),
        .init(title: "Amazon", symbol: "AMZN", aliases: ["AMZN", "AMAZON"]),
        .init(title: "SOXL", symbol: "SOXL", aliases: ["SOXL"]),
        .init(title: "SOXS", symbol: "SOXS", aliases: ["SOXS"]),
        .init(title: "Palantir", symbol: "PLTR", aliases: ["PLTR", "PALANTIR"]),
        .init(title: "Oklo", symbol: "OKLO", aliases: ["OKLO"]),
        .init(title: "Rigetti", symbol: "RGTI", aliases: ["RGTI"]),
        .init(title: "Archer Aviation", symbol: "ACHR", aliases: ["ACHR"]),
        .init(title: "AIOS", symbol: "AIOS", aliases: ["AIOS"]),
        .init(title: "SEGG", symbol: "SEGG", aliases: ["SEGG"]),
        .init(title: "EVTV", symbol: "EVTV", aliases: ["EVTV"]),
        
        .init(title: "Dogecoin", symbol: "DOGE-USD",
              aliases: ["DOGE", "DOGEUSD", "DOGECOIN"]),

        .init(title: "Hedera", symbol: "HBAR-USD",
              aliases: ["HBAR", "HBARUSD", "HEDERA"]),

        .init(title: "Solana", symbol: "SOL-USD",
              aliases: ["SOL", "SOLUSD", "SOLANA"]),

        .init(title: "XRP", symbol: "XRP-USD",
              aliases: ["XRP", "XRPUSD", "RIPPLE"]),

        .init(title: "Cardano", symbol: "ADA-USD",
              aliases: ["ADA", "ADAUSD", "CARDANO"]),

        .init(title: "Avalanche", symbol: "AVAX-USD",
              aliases: ["AVAX", "AVAXUSD"]),

        .init(title: "Chainlink", symbol: "LINK-USD",
              aliases: ["LINK", "LINKUSD"]),

        .init(title: "Litecoin", symbol: "LTC-USD", aliases: ["LTC", "LTCUSD", "LITECOIN", "LTC-USD"]),

        .init(title: "Natural Gas", symbol: "NG=F",
              aliases: ["NG", "NATGAS", "NATURALGAS"]),

        .init(title: "Brent Oil", symbol: "BZ=F",
              aliases: ["BRENT", "UKOIL", "BRENTOIL"]),

        .init(title: "Russell Futures", symbol: "RTY=F",
              aliases: ["RTY", "RUSSELL", "RUT"]),

        .init(title: "Bitcoin Futures", symbol: "BTC=F",
              aliases: ["BTCFUT", "BTCFUTURES"]),
        
        .init(title: "Cronos", symbol: "CRO-USD", aliases: ["CRO", "CROUSD", "CRONOS", "CRO-USD"])
    ]

    static func normalized(_ value: String) -> String {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !cleaned.isEmpty else { return "" }

        if let match = known.first(where: {
            $0.symbol.uppercased() == cleaned ||
            $0.aliases.contains(cleaned)
        }) {
            return match.symbol
        }

        return cleaned
    }

    static func matches(_ value: String) -> [SmartSymbol] {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !cleaned.isEmpty else { return [] }

        return known.filter { item in
            item.title.uppercased().contains(cleaned) ||
            item.symbol.uppercased().contains(cleaned) ||
            item.aliases.contains(where: { $0.contains(cleaned) })
        }
    }
}
