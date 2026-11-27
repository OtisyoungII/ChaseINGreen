import SwiftUI

/// Deeper section of the SAME expanded broker surface. No work begins at init.
struct BrokerTradingSurface: View {
    let accessToken: String
    let account: BrokerAccountResponse
    let positions: [LoggedTradeResponse]
    @ObservedObject private var session = AuthSessionCoordinator.shared
    @State private var visible = false
    @State private var prepared = false
    @State private var loading = false
    @State private var intent = BrokerWorkspaceIntent()
    @State private var instruments: [Instrument] = []
    @State private var status = "Scroll here to prepare this account’s instrument context."
    @State private var orders: [RHOrder]?
    @State private var selected: String?
    @State private var timeframe: String?
    @State private var candles: [MarketCandle] = []
    @State private var chartStatus = "Choose an instrument, then a timeframe."
    @State private var cache: [String: [MarketCandle]] = [:]
    private let frames = ["1m", "5m", "15m", "1h", "4h", "1d"]
    private var provider: String {
        let b = account.broker.lowercased()
        if b.contains("kraken") { return "kraken" }
        if b.contains("robinhood") { return "robinhood" }
        if b.contains("aqua") || b.contains("match") { return "matchtrader" }
        return b
    }
    private var manual: Bool { BrokerRoomEvidencePolicy.isManual(sourceMode: account.sourceMode, connectionMode: account.connectionMode) }
    private var chosen: Instrument? { instruments.first { $0.id == selected } }
    private var chartKey: String? {
        guard let selected, let timeframe else { return nil }
        return "\(account.id)|\(selected)|\(timeframe)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
            Label("Trading workspace", systemImage: "chart.xyaxis.line").font(.title3.bold())
            Text("\(account.accountTitle ?? account.accountName ?? account.accountId) · \(manual ? "Manual" : provider)").font(.caption)
            Text(status).font(.caption).foregroundStyle(.secondary)
            if loading { ProgressView("Preparing selected account…") }
            if !instruments.isEmpty {
                Picker("Instrument", selection: $selected) {
                    Text("Select an instrument").tag(String?.none)
                    ForEach(instruments) { instrument in Text(instrument.label).tag(Optional(instrument.id)) }
                }
            }
            if let chosen {
                Text(chosen.mechanics).font(.caption)
                Text("Provider/API capability: \(chosen.capability)").font(.caption)
                Text("Chase execution authority: not established by market-data availability.").font(.caption)
                Picker("Timeframe", selection: $timeframe) {
                    Text("Choose timeframe").tag(String?.none)
                    ForEach(frames, id: \.self) { Text($0.uppercased()).tag(Optional($0)) }
                }
                if !candles.isEmpty {
                    CandleChartView(candles: candles, currentPrice: nil, showAILevels: false, context: nil)
                        .frame(height: 270)
                    Text("Source: \(Set(candles.compactMap(\.provider)).sorted().joined(separator: ", ")) · retained for this visit")
                        .font(.caption)
                }
                Text(chartStatus).font(.caption).foregroundStyle(.secondary)
            }
            Label("Orders / activity", systemImage: "list.bullet.rectangle").font(.headline)
            if let orders {
                Text("\(orders.count) retained order-history records. This is not a current open-order count.").font(.caption)
                ForEach(Array(orders.prefix(20).enumerated()), id: \.offset) { _, order in
                    Text("\(order.identity.symbol ?? "Instrument unavailable") · \(order.side) · \(order.order_status ?? "Status unavailable")").font(.caption)
                }
                if orders.count > 20 { Text("Showing 20 of \(orders.count) retained records.").font(.caption) }
            } else { Text("Account-specific order/fill collections unavailable in this read contract.").font(.caption) }
            Text("Fill verification, protection and Replay eligibility remain separate. No customer-authorized account-scoped Replay contract is established here.").font(.caption).foregroundStyle(.secondary)
            if provider == "robinhood" && !manual {
                NavigationLink { RobinhoodConnectionView(accessToken: accessToken, initialConnectionID: account.brokerConnectionId) } label: {
                    Label("Robinhood Crypto connection / trade review", systemImage: "gearshape")
                }
            }
        }
        .onScrollVisibilityChange(threshold: 0.1) { value in if value { visible = true } }
        .task(id: visible) {
            guard visible, !prepared, BrokerRoomAccessPolicy.permits(session.capabilityProfile) else { return }
            _ = intent.entered(account: account.id.uuidString)
            guard intent.workspaceVisible() == .instruments else { return }
            await prepare()
        }
        .onChange(of: selected) { _, value in
            timeframe = nil; candles = []; chartStatus = "Choose a timeframe; no candle request has been made."
            if let value { _ = intent.selectInstrument(value) }
        }
        .onChange(of: timeframe) { _, value in if let value { _ = intent.selectTimeframe(value) } }
        .task(id: chartKey) { await loadChart() }
    }

    @MainActor private func prepare() async {
        loading = true
        defer { loading = false }
        let generation = session.sessionGeneration
        #if DEBUG
        print("[BrokerRoomIntent] layer=workspace work=instrument-preparation")
        #endif
        do {
            var result: [Instrument] = []
            var message: String
            var retainedOrders: [RHOrder]?
            if manual {
                message = "Manual records: no provider universe, live synchronization or API execution."
            } else if provider == "kraken" {
                let response = try await APIService.shared.fetchKrakenInstruments(accessToken: accessToken)
                guard response.success, response.provider.lowercased().contains("kraken") else { throw CancellationError() }
                result = response.instruments.map {
                    Instrument(id: $0.providerSymbol, label: $0.displaySymbol, symbol: $0.canonicalSymbol,
                        mechanics: "Crypto base/quote: \($0.base)/\($0.quote). Quantity precision: \($0.quantityDecimals.map(String.init) ?? "unavailable"); price precision: \($0.priceDecimals.map(String.init) ?? "unavailable").",
                        capability: "Venue metadata tradable=\($0.tradable); status=\($0.status). Account execution eligibility unproven.")
                }
                message = "Kraken venue products · \(response.freshness). Venue availability is not account permission."
            } else if provider == "matchtrader" {
                let response = try await APIService.shared.fetchMatchTraderInstruments(accountId: account.accountId, accessToken: accessToken)
                guard response.success != false, response.accountId == account.accountId else { throw CancellationError() }
                result = (response.instruments ?? []).map {
                    Instrument(id: $0.symbol, label: $0.displayName ?? $0.symbol, symbol: $0.symbol,
                        mechanics: "\($0.group ?? "Class unavailable") · minimum volume \($0.minimumVolume.map(String.init(describing:)) ?? "unavailable") · step \($0.volumeStep.map(String.init(describing:)) ?? "unavailable"). Volume must not be treated as futures contracts; contract economics require qualified metadata.",
                        capability: "Tradable: \($0.tradable.map(String.init) ?? "unknown"); session open: \($0.sessionOpen.map(String.init) ?? "unknown"). Snapshot metadata, not execution authority.")
                }
                message = "Account-specific Aqua catalog from existing adapter/cache. Catalog age is not supplied; current tradability requires fresh qualification."
            } else if provider == "robinhood", let cid = account.brokerConnectionId, UUID(uuidString: cid) != nil {
                let data = try await APIService.shared.sendRequest(path: "/crypto-brokers/robinhood/connections/\(cid)/truth", method: "GET", accessToken: accessToken, label: "BrokerRoom retained Robinhood truth")
                let response = try JSONDecoder().decode(RHTruth.self, from: data)
                guard response.connection.id.lowercased() == cid.lowercased(),
                      let truth = response.accounts.first(where: {
                          $0.snapshot.account.identity.canonical_account_id?.lowercased() == (account.canonicalAccountId ?? account.id.uuidString).lowercased()
                      }) else { throw CancellationError() }
                result = (truth.pairs ?? []).map {
                    Instrument(id: $0.symbol, label: $0.symbol, symbol: $0.symbol,
                        mechanics: "Crypto only · minimum \($0.min_order_size ?? "unavailable") · asset increment \($0.asset_increment ?? "unavailable"). Equities/futures not covered.",
                        capability: "API tradable: \($0.is_api_tradable.map(String.init) ?? "unknown"). Chase authorization remains separate.")
                }
                retainedOrders = truth.snapshot.orders
                message = "Retained Robinhood Crypto products/orders · \(truth.snapshot.account.freshness) · observed \(truth.snapshot.account.received_at). No provider refresh performed."
            } else {
                result = positions.map {
                    Instrument(id: $0.providerSymbol ?? $0.symbol, label: $0.symbol, symbol: $0.symbol,
                        mechanics: "Observed account instrument only. Quantity convention, increments and contract economics unavailable.",
                        capability: "Position visibility established by retained row; tradable universe/execution unproven.")
                }
                message = "Only instruments in this account’s retained positions are shown. No complete account instrument-discovery contract is available. IBKR remains information/monitoring only."
            }
            guard !Task.isCancelled, session.isCurrentSession(generation) else { return }
            var ids = Set<String>()
            instruments = result.filter { ids.insert($0.id).inserted }.sorted { $0.label < $1.label }
            orders = retainedOrders; status = message; prepared = true
        } catch {
            guard !Task.isCancelled, session.isCurrentSession(generation) else { return }
            status = "Instrument preparation unavailable for this exact account. No login/reconnect or fallback account was attempted."
            prepared = true
        }
    }

    @MainActor private func loadChart() async {
        guard let key = chartKey, let chosen, let timeframe,
              BrokerRoomAccessPolicy.permits(session.capabilityProfile) else { return }
        if let cached = cache[key] { candles = cached; chartStatus = "Retained selected-timeframe evidence; not an execution quote."; return }
        let generation = session.sessionGeneration
        let revision = intent.revision
        candles = []; chartStatus = "Loading selected timeframe…"
        #if DEBUG
        print("[BrokerRoomIntent] layer=timeframe work=one-candle-request")
        #endif
        do {
            let result = try await APIService.shared.fetchMarketCandles(for: chosen.symbol, timeframe: timeframe, provider: provider,
                accountId: account.accountId, connectionID: account.brokerConnectionId, instrumentID: chosen.id, accessToken: accessToken)
            guard !Task.isCancelled, session.isCurrentSession(generation), chartKey == key, intent.accepts(account: account.id.uuidString, revision: revision) else { return }
            if cache.count >= 8 { cache.removeAll(keepingCapacity: true) }
            cache[key] = result; candles = result
            chartStatus = result.isEmpty ? "Candle evidence unavailable; no synthetic candles." : "\(result.count) candles · \(timeframe.uppercased()) · last evidence \(result.last!.timestamp.formatted(date: .abbreviated, time: .shortened))."
        } catch {
            guard !Task.isCancelled, session.isCurrentSession(generation), chartKey == key, intent.accepts(account: account.id.uuidString, revision: revision) else { return }
            chartStatus = "Selected account/instrument/timeframe evidence unavailable. No cross-provider fallback is presented as broker truth."
        }
    }

    private struct Instrument: Identifiable {
        let id: String
        let label: String
        let symbol: String
        let mechanics: String
        let capability: String
    }
}
