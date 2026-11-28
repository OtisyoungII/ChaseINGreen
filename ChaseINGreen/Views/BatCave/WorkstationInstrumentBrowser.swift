import SwiftUI

/// One browser for both authorized workstation surfaces. Selection is metadata only.
struct WorkstationInstrumentBrowser: View {
    let items: [WorkstationInstrumentItem]
    let context: String
    let accessToken: String
    let selectedID: String?
    let owned: Set<String>
    let onSelect: (String) -> Void
    @ObservedObject private var session = AuthSessionCoordinator.shared
    @State private var presented = false
    @State private var query = ""
    @State private var assetClass: String?
    @State private var recent: [String] = []
    @State private var watched: Set<String> = []
    @State private var watchlistStatus = "Watchlist not loaded"
    @FocusState private var searchFocused: Bool
    private var results: [WorkstationInstrumentItem] {
        WorkstationInstrumentSearch.results(items, query: query, assetClass: assetClass,
            recent: recent, owned: owned, watched: watched)
    }
    var body: some View {
        Button {
            presented = true
        } label: {
            Label(items.first(where: { $0.id == selectedID })?.label ?? "Search instruments", systemImage: "magnifyingglass")
        }.buttonStyle(.bordered)
        .sheet(isPresented: $presented) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 10) {
                    Text(context).font(.caption).foregroundStyle(.secondary)
                    TextField("Ticker, asset or pair", text: $query)
                        .textFieldStyle(.roundedBorder).autocorrectionDisabled()
                        .textInputAutocapitalization(.characters).focused($searchFocused)
                        .submitLabel(.done).onSubmit { searchFocused = false }
                    Picker("Asset class", selection: $assetClass) {
                        Text("All catalog classes").tag(String?.none)
                        ForEach(Array(Set(items.map(\.assetClass))).sorted(), id: \.self) { Text($0).tag(Optional($0)) }
                    }
                    Text("\(results.count) matches · recent, owned and watchlisted pairs promoted. \(watchlistStatus)")
                        .font(.caption).foregroundStyle(.secondary)
                    List(results) { item in
                        Button {
                            recent.removeAll { $0 == item.id }; recent.insert(item.id, at: 0)
                            recent = Array(recent.prefix(12))
                            onSelect(item.id); searchFocused = false; presented = false
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack { Text(item.label).font(.headline); Spacer(); if item.id == selectedID { Image(systemName: "checkmark") } }
                                Text("\(item.assetClass) · \(item.id)").font(.caption).foregroundStyle(.secondary)
                                if !item.detail.isEmpty { Text(item.detail).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }.listStyle(.plain).scrollDismissesKeyboard(.interactively)
                    if results.isEmpty { Text(items.isEmpty ? "Catalog unavailable" : "No matching catalog instrument").font(.callout) }
                }.padding(.horizontal)
                .navigationTitle("Instruments").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { searchFocused = false; presented = false } }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Hide keyboard") { searchFocused = false } }
                }
                .task {
                    searchFocused = true
                    let generation = session.sessionGeneration
                    do {
                        let lists = try await AppRefreshCoordinator.shared.watchlists(accessToken: accessToken)
                        guard session.isCurrentSession(generation), !Task.isCancelled else { return }
                        watched = Set(lists.flatMap(\.symbols).map(WorkstationInstrumentSearch.key))
                        watchlistStatus = "Watchlist available"
                    } catch { watchlistStatus = "Watchlist unavailable; catalog remains usable" }
                }
            }
        }
    }
}
