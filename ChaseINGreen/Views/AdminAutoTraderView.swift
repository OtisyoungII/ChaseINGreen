import SwiftUI

struct AdminAutoTraderView: View {
    let accessToken: String
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    @State private var snapshot: AdminOperationsSnapshot?
    @State private var error: String?
    @State private var pendingCount: Int?
    @State private var recent: [BrokerOperationsEvent] = []
    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { timeline in
            List {
                Section("Auto Trader · Observe only") {
                    LabeledContent("Execution", value: "LOCKED")
                    LabeledContent("New Risk", value: "DISABLED")
                    if let s = snapshot {
                        if s.trading_enabled { Text("Safety conflict: server reports trading enabled. No execution controls are available here.").foregroundStyle(.red) }
                        let healthy = s.accounts.filter { ["LIVE", "OBSERVING", "FRESH"].contains(AdminNavigationPresentation.status($0, snapshot: s.generated_at, now: timeline.date)) }.count
                        LabeledContent("Account health", value: "\(healthy) current · \(s.accounts.count - healthy) attention")
                        LabeledContent("Positions", value: "\(s.accounts.flatMap { AdminNavigationPresentation.openHoldings($0) }.count)")
                        Text("Updated \(AdminNavigationPresentation.time(s.generated_at))").font(.caption)
                        if !OperationsPresentation.currentSnapshot(s.generated_at, now: timeline.date) { Text("Display stale — refresh required").foregroundStyle(.orange) }
                    }
                    NavigationLink("Safety details · Execution remains disabled") {
                        List {
                            Text("This console reads stored broker observations. It does not place orders or authorize new risk.")
                            Text("Unknown protection, stale evidence and unqualified market data remain limitations. Model evidence does not authorize trading.")
                        }.navigationTitle("Safety")
                    }
                }
                if let error { Section { Text(error).foregroundStyle(.orange) } }
                Section("Owner actions") { NavigationLink(pendingCount.map { "\($0) Pending Actions" } ?? "Pending Actions · Check status") { AdminPendingActionsView() } }
                if let s = snapshot {
                    Section("Broker accounts") {
                        ForEach(["ibkr", "kraken", "match_trader", "aqua", "aqua_funded"], id: \.self) { provider in
                            let rows = s.accounts.filter { $0.provider == provider }
                            if !rows.isEmpty {
                                NavigationLink { AdminAccountListView(accounts: rows, generated: s.generated_at, title: provider.uppercased()) } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(provider.uppercased()).font(.headline)
                                        Text("\(rows.count) accounts · \(rows.flatMap { AdminNavigationPresentation.openHoldings($0) }.count) positions").font(.caption)
                                    }
                                }
                            }
                        }
                        NavigationLink("All brokers & connection management") { AdminBrokerCenterView(accessToken: accessToken) }
                    }
                    Section("Watching now") {
                        let enabled = s.watch.filter(\.enabled)
                        let active = enabled.filter { ["LIVE", "FRESH", "SUCCESS", "OBSERVING"].contains(OperationsPresentation.permittedStatus($0.status, snapshotTime: s.generated_at, now: timeline.date)) }
                        LabeledContent("Active", value: "\(active.count)")
                        LabeledContent("Selected / awaiting evidence", value: "\(enabled.count - active.count)")
                        LabeledContent("Issues", value: "\(enabled.filter { $0.failure_category != nil }.count)")
                        LabeledContent("Disabled", value: "\(s.watch.count - enabled.count)")
                        if active.isEmpty { Text("No markets currently verified as being observed").font(.caption) }
                        NavigationLink("View all markets") { AdminMarketListView(snapshot: s) }
                    }
                }
                Section("Recent activity") {
                    ForEach(recent.prefix(3)) { e in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(snapshot?.accounts.first { $0.canonical_account == e.account || $0.native_account == e.account }.map(AdminNavigationPresentation.account) ?? e.broker.uppercased()).font(.subheadline.bold())
                            Text("\(e.event_type.replacingOccurrences(of: "_", with: " ").capitalized) · \(e.freshness)").font(.caption)
                            Text(AdminNavigationPresentation.time(e.observed_at)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink("Recent broker activity") { AdminBrokerActivityView(accessToken: accessToken) }
                    NavigationLink("Selected Trade Viewer") { ScrollView { AdminTraderCockpit(accessToken: accessToken).padding() }.navigationTitle("Trade Viewer") }
                    NavigationLink("Trade Intelligence") { TradeIntelligenceCenterView(accessToken: accessToken) }
                }
                Section("Advanced") { NavigationLink("Evidence, source coverage & watch preferences") { AdvancedAdminOperationsView(accessToken: accessToken) } }
            }.navigationTitle("Auto Trader").navigationBarTitleDisplayMode(.inline)
                .onAppear { visible = true }.onDisappear { visible = false }
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    await load()
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .seconds(30)) } catch { return }
                        if visible { await load() }
                    }
                }.refreshable { await load() }
        }
    }
    private func load() async {
        do {
            snapshot = try await APIService.shared.fetchAdminOperations(accessToken: accessToken)
            pendingCount = try? await APIService.shared.pendingIBKRClaims().requests.count
            recent = (try? await APIService.shared.fetchBrokerOperationsEvidence(accessToken: accessToken, cursor: nil).events) ?? []
            error = nil
        }
        catch { snapshot = nil; self.error = "Operations unavailable. No current state inferred." }
    }
}

struct AdminBrokerCenterView: View {
    let accessToken: String
    @State private var snapshot: AdminOperationsSnapshot?
    @State private var error: String?
    var body: some View {
        List {
            Section { NavigationLink("Pending Actions · Review enrollments") { AdminPendingActionsView() } }
            if let error { Text(error).foregroundStyle(.orange) }
            Section("Connections") {
                if let s = snapshot {
                    ForEach(["personal", "business"], id: \.self) { ownership in
                        let accounts = s.accounts.filter { $0.provider == "ibkr" && $0.ownership.lowercased() == ownership }
                        NavigationLink { AdminAccountListView(accounts: accounts, generated: s.generated_at, title: "IBKR " + ownership.capitalized) } label: {
                            VStack(alignment: .leading) {
                                Text("IBKR " + ownership.capitalized).font(.headline)
                                Text(accounts.isEmpty ? "No qualified observation" : accounts.map { "…\(($0.native_account ?? "Unknown").suffix(4)) · \(AdminNavigationPresentation.status($0, snapshot: s.generated_at))" }.joined(separator: " / ")).font(.caption)
                            }
                        }
                    }
                    NavigationLink("Kraken") { AdminAccountListView(accounts: s.accounts.filter { $0.provider == "kraken" }, generated: s.generated_at, title: "Kraken") }
                    NavigationLink("Aqua / Match-Trader") {
                        List {
                            ForEach(s.accounts.filter { ["aqua", "match_trader", "aqua_funded"].contains($0.provider) }) { a in
                                NavigationLink { AdminAccountDetailView(account: a, generated: s.generated_at) } label: { AdminAccountRow(account: a, generated: s.generated_at) }
                            }
                            NavigationLink("Official API connection · Manage securely") { AquaAPIIntakeView() }
                            Text("No listed account means current observation is not established. API intake and live observation are separate.").font(.caption)
                        }.navigationTitle("Aqua / Match-Trader")
                    }
                } else { Text("Broker status unavailable") }
            }
        }.navigationTitle("Brokers").task { await load() }.refreshable { await load() }
    }
    private func load() async {
        do { snapshot = try await APIService.shared.fetchAdminOperations(accessToken: accessToken); error = nil }
        catch { snapshot = nil; self.error = "Broker summaries unavailable or access denied." }
    }
}

struct AdminAccountListView: View {
    let accounts: [OperationsAccount]
    let generated: String
    let title: String
    var body: some View {
        List {
            if accounts.isEmpty { Text("No qualified account observation available") }
            ForEach(accounts) { a in
                NavigationLink { AdminAccountDetailView(account: a, generated: generated) } label: { AdminAccountRow(account: a, generated: generated) }
            }
        }.navigationTitle(title)
    }
}

struct AdminAccountRow: View {
    let account: OperationsAccount
    let generated: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(AdminNavigationPresentation.account(account)).font(.headline)
            Text("\(AdminNavigationPresentation.status(account, snapshot: generated)) · \(AdminNavigationPresentation.openHoldings(account).count) positions").font(.caption)
            Text("Equity \(AdminNavigationPresentation.money(account.metrics.first { ["equity", "net_liquidation"].contains($0.name.lowercased()) }?.value, currency: account.currency))").font(.subheadline)
            Text(AdminNavigationPresentation.time(account.observed_at ?? account.last_sync)).font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }
}

struct AdminAccountDetailView: View {
    let account: OperationsAccount
    let generated: String
    var body: some View {
        List {
            Section("Account summary") {
                Text(AdminNavigationPresentation.status(account, snapshot: generated)).font(.headline)
                ForEach(account.metrics) { metric in
                    LabeledContent(metric.name.replacingOccurrences(of: "_", with: " ").capitalized, value: AdminNavigationPresentation.money(metric.value, currency: account.currency))
                }
                Text("Protection: \(account.protection)").foregroundStyle(.orange)
                Text("Observation: \(AdminNavigationPresentation.time(account.observed_at ?? account.last_sync))").font(.caption)
            }
            Section("Positions") {
                ForEach(AdminNavigationPresentation.openHoldings(account)) { h in
                    NavigationLink {
                        List {
                            Text("Protection: \(h.protection)")
                            LabeledContent("Quantity", value: AdminNavigationPresentation.quantity(h.quantity))
                            LabeledContent("Average entry", value: AdminNavigationPresentation.money(h.average_cost, currency: h.currency ?? account.currency))
                            LabeledContent("Observed mark", value: AdminNavigationPresentation.money(h.provider_mark, currency: h.currency ?? account.currency))
                            DisclosureGroup("Advanced evidence") {
                                Text("Contract: \(h.conid ?? "UNKNOWN")")
                                Text("Native account: \(h.native_account ?? "UNKNOWN")")
                                Text("Provider time: \(h.provider_at ?? "UNKNOWN")")
                                Text("Receipt: \(h.received_at ?? "UNKNOWN")")
                                Text("Evidence: \(h.state)")
                            }
                        }.navigationTitle(h.symbol)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(h.symbol) · \(AdminNavigationPresentation.quantity(h.quantity)) \(h.side ?? "")").font(.headline)
                            Text("Open P/L \(AdminNavigationPresentation.money(h.unrealized_pnl, currency: h.currency ?? account.currency))").font(.subheadline)
                            Text("Protection: \(h.protection)").font(.caption).foregroundStyle(.orange)
                        }
                    }
                }
            }
            Section("Advanced evidence") {
                DisclosureGroup("Identity, freshness & limitations") {
                    Text("\(account.label) · \(account.ownership)")
                    Text("Native: \(account.native_account ?? "UNKNOWN")")
                    Text("Canonical: \(account.canonical_account ?? "UNKNOWN")")
                    Text("Connection suffix: \(account.connection_suffix)")
                    Text("Provider: \(account.provider_at ?? "UNKNOWN") · Receipt: \(account.received_at ?? "UNKNOWN")")
                    Text("Orders: \(account.orders_status) · Executions: \(account.executions_status ?? "UNKNOWN")")
                    Text("Market data: \(account.qualification ?? "UNKNOWN")")
                    Text(account.reason)
                    ForEach(account.asset_balances + account.risk) { m in Text("\(m.name): \(m.formatted) · \(m.state)") }
                }
            }
        }.navigationTitle(AdminNavigationPresentation.account(account)).navigationBarTitleDisplayMode(.inline)
    }
}

private struct AdminMarketListView: View {
    let snapshot: AdminOperationsSnapshot
    @State private var filter = "Active"
    var rows: [OperationsWatch] {
        snapshot.watch.filter { row in
            if filter == "All" { return true }
            let current = OperationsPresentation.permittedStatus(row.status, snapshotTime: snapshot.generated_at)
            let active = row.enabled && ["LIVE", "FRESH", "SUCCESS", "OBSERVING"].contains(current)
            return filter == "Active" ? active : row.enabled && !active
        }
    }
    var body: some View {
        List {
            Picker("Markets", selection: $filter) { ForEach(["Active", "Attention", "All"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
            if rows.isEmpty { Text("No markets in this category") }
            ForEach(rows) { row in
                DisclosureGroup(row.label) {
                    Text(row.enabled ? OperationsPresentation.permittedStatus(row.status, snapshotTime: snapshot.generated_at) : "Disabled")
                    Text(AdminNavigationPresentation.time(row.observed_at))
                    Text(row.reason).font(.caption)
                }
            }
        }.navigationTitle("Markets")
    }
}
