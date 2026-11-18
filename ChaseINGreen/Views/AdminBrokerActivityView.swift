import SwiftUI

struct AdminBrokerActivityView: View {
    let accessToken: String
    var raw = false
    @State private var accounts: [OperationsAccount] = []
    @State private var events: [BrokerOperationsEvent] = []
    @State private var cursor: [String]?
    @State private var more = false
    @State private var busy = false
    @State private var error: String?
    @State private var search = ""
    @State private var broker = "All"
    @State private var account = "All"
    @State private var kind = "All"
    @State private var status = "All"
    @State private var range = "Recent"
    private var filtered: [BrokerOperationsEvent] {
        events.filter { e in
            let date = OperationsPresentation.date(e.observed_at)
            let cutoff = range == "Recent" ? 86400.0 : range == "7 days" ? 604800.0 : Double.infinity
            return (broker == "All" || e.broker == broker) && (account == "All" || e.account == account)
                && (kind == "All" || e.event_type == kind) && (status == "All" || e.freshness == status)
                && (search.isEmpty || e.symbol.localizedCaseInsensitiveContains(search))
                && (range == "All loaded" || date.map { Date().timeIntervalSince($0) <= cutoff } == true)
        }
    }
    private var groups: [[BrokerOperationsEvent]] {
        let grouped = Dictionary(grouping: filtered) { e in "\(e.broker)|\(e.account)|\(e.event_type)|\(e.observed_at ?? e.received_at ?? e.id)|\(e.freshness)" }
        return grouped.values.sorted { ($0.first?.observed_at ?? "") > ($1.first?.observed_at ?? "") }
    }
    var body: some View {
        List {
            Section("Filter loaded history") {
                TextField("Symbol", text: $search)
                Picker("Broker", selection: $broker) { Text("All").tag("All"); ForEach(Array(Set(events.map(\.broker))).sorted(), id: \.self) { Text($0) } }
                Picker("Account", selection: $account) { Text("All").tag("All"); ForEach(Array(Set(events.map(\.account))).sorted(), id: \.self) { Text("…\($0.suffix(4))").tag($0) } }
                Picker("Event type", selection: $kind) { Text("All").tag("All"); ForEach(Array(Set(events.map(\.event_type))).sorted(), id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ")).tag($0) } }
                Picker("Status", selection: $status) { Text("All").tag("All"); ForEach(Array(Set(events.map(\.freshness))).sorted(), id: \.self) { Text($0) } }
                Picker("Date range", selection: $range) { ForEach(["Recent", "7 days", "All loaded"], id: \.self) { Text($0) } }
            }
            if let error { Text(error).foregroundStyle(.orange) }
            Section(raw ? "Evidence records" : "Recent broker activity") {
                if filtered.isEmpty { Text("No matching records in loaded history") }
                ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                    if let e = group.first {
                        NavigationLink {
                            List { ForEach(group) { item in
                                Section(item.symbol) {
                                    Text("Event: \(item.event_type)")
                                    Text("Canonical account: \(item.account)")
                                    Text("Connection: \(item.connection)")
                                    Text("Record: \(item.id)")
                                    Text("Observed: \(item.observed_at ?? "UNKNOWN")")
                                    Text("Received: \(item.received_at ?? "UNKNOWN")")
                                    Text("Quantity: \(item.quantity.map(String.init(describing:)) ?? "UNKNOWN")")
                                    Text("Price: \(item.price.map(String.init(describing:)) ?? "UNKNOWN")")
                                    Text("Origin: \(item.origin) · Protection: \(item.protection)")
                                    Text("Freshness: \(item.freshness)")
                                    ForEach(item.warnings, id: \.self) { Text($0) }
                                }
                            } }.navigationTitle("Evidence Log").textSelection(.enabled)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(accounts.first { $0.canonical_account == e.account || $0.native_account == e.account }.map(AdminNavigationPresentation.account) ?? "\(e.broker.uppercased()) · Account identity unavailable").font(.headline)
                                Text("\(e.event_type.replacingOccurrences(of: "_", with: " ").capitalized) · \(group.count) record(s)").font(.subheadline)
                                Text("\(AdminNavigationPresentation.time(e.observed_at)) · \(e.freshness)").font(.caption)
                                Text(Array(Set(group.map(\.symbol))).sorted().joined(separator: " · ")).font(.caption)
                            }
                        }
                    }
                }
            }
            if more { Button("Next 30 records") { Task { await load(reset: false) } }.disabled(busy) }
            Text("Filters apply to this bounded page. Next page replaces it; pull to refresh returns to recent records. Historical records are not current positions.").font(.caption)
        }.navigationTitle(raw ? "Advanced Evidence Log" : "Broker Activity")
            .task { await load(reset: true) }.refreshable { await load(reset: true) }
    }
    private func load(reset: Bool) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do {
            if reset { accounts = (try? await APIService.shared.fetchAdminOperations(accessToken: accessToken).accounts) ?? [] }
            let page = try await APIService.shared.fetchBrokerOperationsEvidence(accessToken: accessToken, cursor: reset ? nil : cursor)
            events = page.events; cursor = page.cursor; more = page.more; error = nil
        } catch { self.error = "Evidence unavailable. No broker action performed." }
    }
}
