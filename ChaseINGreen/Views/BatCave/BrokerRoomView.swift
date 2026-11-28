import SwiftUI

/// Native translation of brokers-room.html. One persistent surface per provider;
/// entering changes that surface's geometry rather than navigating to a copy.
struct BrokerRoomView: View {
    let accessToken: String
    @ObservedObject private var session = AuthSessionCoordinator.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var selected = 0
    @State private var expanded = false
    @State private var accounts: [BrokerAccountResponse] = []
    @State private var positions: [LoggedTradeResponse] = []
    @State private var selectedAccounts: [String: UUID] = [:]
    @State private var error: String?
    @State private var loaded = false
    @State private var loading = false
    @State private var loadedSessionGeneration: UInt64?
    @State private var lastRead: Date?
    @State private var positionReadFailed = false
    @State private var positionsLoaded = false
    @State private var showingUniversal = false
    @State private var showingWatchlist = false
    @State private var watchSymbol: String?
    @State private var showingMarket = false
    private let brokers = RoomBroker.allCases
    private var broker: RoomBroker { brokers[selected] }
    private var permitted: Bool { BrokerRoomAccessPolicy.permits(session.capabilityProfile) }

    var body: some View {
        Group {
            if permitted { room }
            else { ContentUnavailableView("Workspace unavailable", systemImage: "lock", description: Text("Your current account does not have access to this workspace.")) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { BrokerRoomEnvironment(accent: broker.accent).ignoresSafeArea() }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationTitle("Batcave")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(expanded)
        .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { gesture in
            if expanded && gesture.startLocation.x < 24 && gesture.translation.width > 70
                && abs(gesture.translation.height) < 70 {
                animate { expanded = false }
            }
        })
        .toolbar {
            if expanded {
                ToolbarItem(placement: .topBarLeading) {
                    Button { animate { expanded = false } } label: {
                        Label("Back", systemImage: "chevron.left")
                    }.accessibilityIdentifier("broker-room-back")
                }
            }
            if permitted {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Universal", systemImage: "globe") { showingUniversal = true }
                        NavigationLink { OpportunityScreenerView(accessToken: accessToken) } label: { Label("Discovery", systemImage: "safari") }
                        Button("Watchlist", systemImage: "star") { showingWatchlist = true }
                        NavigationLink { TradingCalendarView(accessToken: accessToken) } label: { Label("Journal & performance", systemImage: "calendar") }
                        Button("Refresh retained truth", systemImage: "arrow.clockwise") { Task { await load(force: true) } }.disabled(loading)
                    } label: { Image(systemName: "globe").accessibilityLabel("Workstation destinations") }
                }
            }
        }
        .sheet(isPresented: $showingUniversal) {
            NavigationStack {
                if permitted { universal }
                else { Text("Workspace access unavailable") }
            }
        }
        .sheet(isPresented: $showingWatchlist, onDismiss: { showingMarket = watchSymbol != nil && permitted }) {
            if permitted {
                NavigationStack {
                    WatchlistView(accessToken: accessToken) { symbol in
                        watchSymbol = symbol
                        showingWatchlist = false
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showingMarket) {
            if permitted, let symbol = watchSymbol {
                MarketDetailView(requestSymbol: symbol, displayName: symbol, tradeSymbol: symbol, accessToken: accessToken)
            }
        }
        .task(id: accessToken) {
            if loadedSessionGeneration != session.sessionGeneration {
                accounts = []; positions = []; selectedAccounts = [:]
                lastRead = nil; loaded = false; positionsLoaded = false; error = nil
                loadedSessionGeneration = session.sessionGeneration
            }
            await load()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await load() } }
        }
        .onChange(of: session.capabilityProfile) { _, _ in
            if !permitted { accounts = []; positions = []; loaded = false; expanded = false; showingUniversal = false; showingWatchlist = false; showingMarket = false; watchSymbol = nil }
        }
    }

    private var room: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                VStack(spacing: 12) {
                    if !expanded {
                        VStack(spacing: 10) {
                            Text("THE BROKER ROOM").font(.caption2.bold()).tracking(3).foregroundStyle(broker.accent)
                            Text("Choose your vantage point.").font(.system(size: 31, weight: .semibold, design: .rounded)).tracking(-1.4).multilineTextAlignment(.center)
                            Text("Move through the room. Tap the closest surface to step inside.")
                                .font(.caption).foregroundStyle(.white.opacity(0.65)).multilineTextAlignment(.center)
                        }.padding(.horizontal, 32).padding(.top, 16)
                    }
                    stage(size: geometry.size)
                    if !expanded {
                        HStack(spacing: 25) {
                            rotationButton(-1)
                            HStack(spacing: 7) {
                                ForEach(brokers.indices, id: \.self) { index in
                                    Capsule().fill(index == selected ? broker.accent : .white.opacity(0.3))
                                        .frame(width: index == selected ? 22 : 5, height: 5)
                                }
                            }
                            rotationButton(1)
                        }
                        Text("SWIPE TO ROTATE · TAP THE CLOSEST SURFACE")
                            .font(.system(size: 9, weight: .semibold)).tracking(1.1).foregroundStyle(.white.opacity(0.5))
                            .padding(.bottom, 12)
                    }
                }
            }
            .foregroundStyle(.white)
            .clipped()
        }
    }

    private func stage(size: CGSize) -> some View {
        let height = expanded ? max(300, size.height - 12) : max(330, size.height - 240)
        let width = min(280, size.width * 0.72)
        return ZStack {
            ForEach(brokers.indices, id: \.self) { index in
                let offset = roomOffset(index)
                let front = offset == 0
                let item = brokers[index]
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        surfaceHeader(item, index: index)
                        BrokerRoomOrb(glyph: item.glyph, accent: broker.accent)
                            .frame(height: expanded && front ? 190 : 135)
                        Text(item.scope.uppercased()).font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(broker.accent)
                        Text(item.headline).font(.system(size: expanded && front ? 43 : 29, weight: .medium, design: .rounded)).tracking(-1.3)
                        Divider().overlay(.white.opacity(0.2))
                        if expanded && front {
                            details(item)
                        } else {
                            HStack {
                                Text(summary(item)).font(.caption2).foregroundStyle(.white.opacity(0.75))
                                Spacer()
                                Image(systemName: "arrow.up.right").foregroundStyle(broker.accent)
                            }
                        }
                    }.padding(expanded && front ? 25 : 22)
                }
                .scrollDisabled(!expanded || !front)
                .frame(width: expanded && front ? size.width - 24 : width, height: height)
                .background(surfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .overlay(RoundedRectangle(cornerRadius: 25).stroke(.white.opacity(0.27), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 24, y: 24)
                .scaleEffect(front ? 1 : 0.70, anchor: .bottom)
                .rotation3DEffect(.degrees(front ? 0 : Double(-offset) * 20), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
                .offset(x: front ? 0 : CGFloat(offset) * size.width * 0.525, y: front ? 0 : -20)
                .opacity(expanded && !front || abs(offset) > 1 ? 0 : front ? 1 : 0.9)
                .zIndex(front ? 5 : 1)
                .allowsHitTesting(!expanded || front)
                .onTapGesture {
                    guard !expanded else { return }
                    animate { if front { expanded = true } else { selected = index } }
                    if front {
                        #if DEBUG
                        print("[BrokerRoomIntent] layer=enter work=retained-account-read")
                        #endif
                        Task { await load() }
                    }
                }
                .accessibilityIdentifier("broker-room-\(item.rawValue)")
            }
        }
        .frame(maxWidth: .infinity).frame(height: height)
        .simultaneousGesture(DragGesture(minimumDistance: 35).onEnded { value in
            guard !expanded, abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }
            rotate(value.translation.width < 0 ? 1 : -1)
        })
    }

    private var surfaceBackground: some View {
        ZStack {
            Color(red: 0.035, green: 0.045, blue: 0.075)
            broker.accent.opacity(0.12)
            LinearGradient(colors: [.white.opacity(0.10), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [broker.accent.opacity(0.15), .clear], center: .topTrailing, startRadius: 0, endRadius: 350)
        }
    }

    private func surfaceHeader(_ item: RoomBroker, index: Int) -> some View {
        HStack(spacing: 10) {
            Text(item.glyph).font(.headline).foregroundStyle(.black)
                .frame(width: 33, height: 33).background(broker.accent, in: RoundedRectangle(cornerRadius: 11))
            Text(item.title).font(.headline).minimumScaleFactor(0.75).lineLimit(1)
            Spacer(minLength: 2)
            Text(String(format: "%02d / %02d", index + 1, brokers.count)).font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.5))
        }
    }

    @ViewBuilder private func details(_ item: RoomBroker) -> some View {
        if let error { Text(error).font(.caption).foregroundStyle(.orange) }
        if !loaded { ProgressView("Loading retained broker truth…") }
        if item == .robinhood {
            Text("Crypto connection only. Equities, options and the total Robinhood portfolio are not covered. Empty crypto holdings do not mean your investment portfolio is empty.")
                .font(.callout).foregroundStyle(.white.opacity(0.75))
        }
        let list = brokerAccounts(item)
        if list.isEmpty && loaded {
            Text("No active normalized accounts returned. This does not establish an empty provider portfolio.").font(.callout)
        }
        if !list.isEmpty {
            Picker("Account", selection: Binding<UUID?>(get: { selectedAccounts[item.rawValue] }, set: { selectedAccounts[item.rawValue] = $0 })) {
                Text("Choose an account").tag(UUID?.none)
                ForEach(list) { account in Text(accountName(account)).tag(Optional(account.id)) }
            }.tint(broker.accent)
        }
        if let account = list.first(where: { $0.id == selectedAccounts[item.rawValue] }) {
            accountDetails(account)
            BrokerTradingSurface(accessToken: accessToken, account: account, positions: accountPositions(account))
                .id("\(session.sessionGeneration)|\(account.id)")
        } else if list.count > 1 {
            Text("Select the account to view its own positions and balances.").font(.caption)
        }
        Divider().overlay(.white.opacity(0.2))
        if item == .robinhood {
            NavigationLink { RobinhoodConnectionView(accessToken: accessToken) } label: { Label("Connection & Confirm Trade", systemImage: "checkmark.shield") }
        }
        NavigationLink {
            ScrollView {
                BrokerManagementPanel(
                    selectedSymbol: "", accessToken: accessToken,
                    focusedProvider: item.rawValue, focusedAccountID: nil,
                    onProviderSelected: { _ in }, onAccountSelected: { _, _, _ in },
                    onConnectionDisconnected: { _, _ in }, onSyncComplete: { await load(force: true) }
                ).padding()
            }.navigationTitle("Broker Management").navigationBarTitleDisplayMode(.inline)
        } label: { Label("Broker Management", systemImage: "link") }
        NavigationLink { BrokerAccountsView(accessToken: accessToken) } label: { Label("Account records", systemImage: "building.columns") }
        if session.capabilityProfile?.canAccessBatCave == true {
            NavigationLink("Internal workspace") {
                TradingWorkspaceView(accessToken: accessToken, symbol: "BTCUSD", direction: nil, broker: item.rawValue, accountKey: nil)
            }
        }
        Text("Connection capability does not grant execution authority. Existing trade confirmation and authorization remain required.")
            .font(.caption).foregroundStyle(.white.opacity(0.55))
    }

    private func accountDetails(_ account: BrokerAccountResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(accountName(account)).font(.title3.bold())
            Label(manual(account) ? "Manually maintained · no live synchronization" : (account.connectionStatus ?? "Connection state unavailable"), systemImage: manual(account) ? "pencil.line" : "link").font(.caption)
            Text("Account status: \(account.accountStatus ?? "Unavailable")").font(.caption)
            Text("Observed: \(readable(observationTime(account)))")
                .font(.caption).foregroundStyle(.white.opacity(0.65))
            Text(manual(account) ? "Manual evidence — not broker verified" : (fresh(account) ? "Fresh within provider snapshot window" : "Freshness unverified or stale — retained evidence"))
                .font(.caption).foregroundStyle(broker.accent)
            DisclosureGroup("Positions / holdings") {
            let matching = accountPositions(account)
            if positionReadFailed { Text("Latest position read failed; retained rows may be stale.").font(.caption).foregroundStyle(.orange) }
            if matching.isEmpty {
                Text(!positionReadFailed && fresh(account) && account.brokerCurrentState?.currentHoldingCount == 0 ? "No holdings in this fresh account snapshot" : "No active position rows returned; completeness unverified")
                    .font(.callout)
            }
            ForEach(matching) { position in
                positionRow(position)
                Divider().overlay(.white.opacity(0.15))
            }
            }
            Text("ACCOUNT EVIDENCE").font(.caption.bold()).tracking(1.5)
            valueRow("Currency", account.currency ?? "Unavailable")
            valueRow("Balance", number(account.balance))
            valueRow("Equity", number(account.equity))
            valueRow("Cash", number(account.cashBalance))
            valueRow("Buying power", number(account.buyingPower))
            valueRow("Open P/L", number(account.unrealizedPnl))
            Label("Orders & fills", systemImage: "list.bullet.rectangle").font(.caption.bold())
            Text(manual(account) ? "No automated fills or API execution. Review manually maintained history in Account records / Journal." : "Open-order and fill collections are not supplied by this account endpoint. Unavailable here; not confirmed empty.")
                .font(.caption).foregroundStyle(.white.opacity(0.65))
            Label("Access & capability", systemImage: "lock.shield").font(.caption.bold())
            Text(manual(account) ? "Manual records only · no API execution" : "Retained account/position reads. Execution and protection authority are not established by this snapshot.")
                .font(.caption).foregroundStyle(.white.opacity(0.65))
            Text("Values are retained account evidence, not live quotes. Missing values remain unavailable.").font(.caption).foregroundStyle(.white.opacity(0.55))
        }
    }

    private func valueRow(_ title: String, _ value: String) -> some View {
        HStack { Text(title).foregroundStyle(.white.opacity(0.65)); Spacer(); Text(value) }.font(.callout)
    }
    private func number(_ value: Double?) -> String { value.map { $0.formatted(.number.precision(.fractionLength(0...6))) } ?? "Unavailable" }
    private func readable(_ raw: String?) -> String {
        guard let raw else { return "Unavailable" }
        let parser = ISO8601DateFormatter(); parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        return date?.formatted(date: .abbreviated, time: .standard) ?? "Unavailable"
    }
    private func accountName(_ account: BrokerAccountResponse) -> String {
        account.accountTitle ?? account.accountName ?? account.connectionName ?? "Account …\(account.accountId.suffix(4))"
    }
    private func brokerAccounts(_ item: RoomBroker) -> [BrokerAccountResponse] {
        accounts.filter { WorkstationAccountPresentation.isPrimary(active: $0.isActive, status: $0.accountStatus) && item.matches($0.broker) }
    }
    private func summary(_ item: RoomBroker) -> String {
        guard loaded else { return "Loading account evidence" }
        let count = brokerAccounts(item).count
        return count == 0 ? "Account evidence unavailable" : "\(count) active account\(count == 1 ? "" : "s") · retained truth"
    }
    private func roomOffset(_ index: Int) -> Int {
        let forward = (index - selected + brokers.count) % brokers.count
        return forward == brokers.count - 1 ? -1 : forward
    }
    private func rotationButton(_ step: Int) -> some View {
        Button { rotate(step) } label: {
            Image(systemName: step < 0 ? "arrow.left" : "arrow.right")
                .frame(width: 44, height: 44).background(.white.opacity(0.07), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.25)))
        }.accessibilityLabel(step < 0 ? "Previous broker" : "Next broker")
    }
    private func rotate(_ step: Int) {
        #if DEBUG
        print("[BrokerRoomIntent] layer=seat work=none")
        #endif
        animate { selected = (selected + step + brokers.count) % brokers.count }
    }
    private func animate(_ change: () -> Void) {
        withAnimation(reduceMotion ? nil : .timingCurve(0.18, 0.8, 0.16, 1, duration: 0.85), change)
    }
    private func manual(_ account: BrokerAccountResponse) -> Bool {
        BrokerRoomEvidencePolicy.isManual(sourceMode: account.sourceMode, connectionMode: account.connectionMode)
    }
    private func observationTime(_ account: BrokerAccountResponse) -> String? {
        manual(account) ? account.lastManualUpdateAt : (account.brokerCurrentState?.snapshotReceivedAt ?? account.lastSuccessfulSync)
    }
    private func fresh(_ account: BrokerAccountResponse) -> Bool {
        !manual(account) && BrokerRoomEvidencePolicy.isFresh(observedAt: observationTime(account), maxAge: account.brokerCurrentState?.snapshotMaxAgeSeconds, providerFresh: account.brokerCurrentState?.snapshotFresh, stale: account.stale)
    }
    private func accountPositions(_ account: BrokerAccountResponse) -> [LoggedTradeResponse] {
        positions.filter { position in
            let canonical = account.canonicalAccountId ?? account.id.uuidString
            return position.canonicalAccountId?.lowercased() == canonical.lowercased()
                || position.brokerAccountId?.lowercased() == account.id.uuidString.lowercased()
        }
    }
    private func positionRow(_ position: LoggedTradeResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NormalizedPositionCard(position: position)
            NavigationLink("Inspect / Analyze") {
                NormalizedPositionDetails(position: position, accessToken: accessToken)
            }
        }
    }
    private var universal: some View {
        List {
            Section {
                Label("Your trading operation", systemImage: "globe").font(.headline)
                Text(loaded && error == nil ? "\(accounts.filter(\.isActive).count) active account records" : "Account count unavailable")
                Text(positionsLoaded ? "\(positions.count) retained open position rows" : "Position count unavailable")
                Text("Last successful account read: \(lastRead?.formatted(date: .abbreviated, time: .standard) ?? "Unavailable")")
                Text("Total equity / exposure: unavailable. Mixed currencies, coverage and timestamps are not summed.")
                if let error { Text(error).foregroundStyle(.orange) }
                if positionReadFailed { Text("Latest position read failed. Retained rows are not current confirmation.").foregroundStyle(.orange) }
                Button("Refresh retained truth", systemImage: "arrow.clockwise") { Task { await load(force: true) } }.disabled(loading)
            }
            Section("Accounts — including manual records") {
                ForEach(accounts) { account in
                    NavigationLink {
                        ScrollView { accountDetails(account).padding() }
                            .background(Color(red: 0.035, green: 0.045, blue: 0.075)).foregroundStyle(.white)
                            .navigationTitle(accountName(account))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(accountName(account), systemImage: manual(account) ? "pencil.line" : "building.columns")
                            Text("\(account.broker) · \(manual(account) ? "Manual · no live sync" : account.connectionStatus ?? "Connection unavailable")").font(.caption)
                            Text("Observed \(readable(observationTime(account)))").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Positions across accounts") {
                if positions.isEmpty { Text(positionsLoaded ? "No retained open rows. Collection completeness is not established by this count." : "Position evidence unavailable.") }
                ForEach(positions) { position in positionRow(position) }
            }
            Section("Coverage") {
                Text("Robinhood is Crypto scope only. Equity/options holdings and whole-portfolio value are not covered.")
                Text("Historical/inactive account records remain in Account records; they are not counted as current operational accounts here.")
            }
        }
        .navigationTitle("Universal")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showingUniversal = false } } }
    }

    @MainActor private func load(force: Bool = false) async {
        guard permitted, !loading else { return }
        if !force, let lastRead, Date().timeIntervalSince(lastRead) < 30 { return }
        loading = true
        defer { loading = false }
        let generation = session.sessionGeneration
        // Existing customer GET paths only. No provider synchronization or polling loop.
        do {
            let result = try await APIService.shared.fetchBrokerAccounts(accessToken: accessToken)
            guard session.isCurrentSession(generation), permitted else { return }
            accounts = result; loaded = true; error = nil; lastRead = Date()
            for item in brokers {
                selectedAccounts[item.rawValue] = BrokerRoomEvidencePolicy.retainedSelection(selectedAccounts[item.rawValue], available: brokerAccounts(item).map(\.id))
            }
        } catch {
            guard session.isCurrentSession(generation), permitted else { return }
            self.error = "Account read failed. Retained evidence may be stale; connections are unchanged."
            loaded = true
        }
        do {
            let result = try await APIService.shared.fetchOpenTrades(accessToken: accessToken)
            guard session.isCurrentSession(generation), permitted else { return }
            positions = result; positionReadFailed = false; positionsLoaded = true
        } catch {
            guard session.isCurrentSession(generation), permitted else { return }
            positionReadFailed = true
        }
    }

}

private enum RoomBroker: String, CaseIterable {
    case kraken, aqua, ibkr, robinhood
    var title: String { switch self { case .kraken: "Kraken"; case .aqua: "Aqua / MatchTrader"; case .ibkr: "IBKR"; case .robinhood: "Robinhood Crypto" } }
    var glyph: String { switch self { case .kraken: "K"; case .aqua: "A"; case .ibkr: "I"; case .robinhood: "R" } }
    var scope: String { switch self { case .kraken: "Digital assets"; case .aqua: "Account-specific trading"; case .ibkr: "Brokerage"; case .robinhood: "Crypto scope only" } }
    var headline: String { switch self { case .kraken: "The current\nin motion."; case .aqua: "Find your\nflow."; case .ibkr: "Room to\ndecide."; case .robinhood: "Crypto in\nview." } }
    var accent: Color { switch self { case .kraken: Color(red: 0.73, green: 0.67, blue: 1); case .aqua: Color(red: 0.55, green: 0.97, blue: 0.92); case .ibkr: Color(red: 1, green: 0.67, blue: 0.64); case .robinhood: Color(red: 0.7, green: 0.94, blue: 0.57) } }
    func matches(_ raw: String) -> Bool {
        let value = raw.lowercased()
        switch self {
        case .aqua: return value.contains("aqua") || value.contains("match")
        case .ibkr: return value.contains("ibkr") || value.contains("interactive")
        default: return value.contains(rawValue)
        }
    }
}

private struct BrokerRoomOrb: View {
    let glyph: String
    let accent: Color
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [accent.opacity(0.23), .clear], center: .center, startRadius: 0, endRadius: 85))
            Circle().stroke(accent.opacity(0.5))
            Ellipse().stroke(accent.opacity(0.3)).frame(width: 65, height: 155).rotationEffect(.degrees(-23))
            Ellipse().stroke(accent.opacity(0.3)).frame(width: 175, height: 60).rotationEffect(.degrees(-30))
            Text(glyph).font(.system(size: 66, weight: .medium, design: .rounded)).foregroundStyle(accent)
        }.frame(width: 140, height: 140).shadow(color: accent.opacity(0.25), radius: 25)
            .frame(maxWidth: .infinity)
    }
}

private struct BrokerRoomEnvironment: View {
    let accent: Color
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.025, green: 0.035, blue: 0.065)
                RadialGradient(colors: [accent.opacity(0.38), accent.opacity(0.12), .clear], center: UnitPoint(x: 0.5, y: 0.35), startRadius: 0, endRadius: geometry.size.height * 0.65)
                UnevenRoundedRectangle(topLeadingRadius: geometry.size.width / 2, bottomLeadingRadius: 20, bottomTrailingRadius: 20, topTrailingRadius: geometry.size.width / 2)
                    .stroke(accent.opacity(0.2)).padding(.horizontal, 16).padding(.vertical, 25)
                UnevenRoundedRectangle(topLeadingRadius: geometry.size.width / 2, bottomLeadingRadius: 20, bottomTrailingRadius: 20, topTrailingRadius: geometry.size.width / 2)
                    .stroke(accent.opacity(0.1)).padding(.horizontal, 35).padding(.vertical, 45)
                Canvas { context, size in
                    var floor = Path()
                    let horizon = size.height * 0.77
                    for i in -5...5 {
                        floor.move(to: CGPoint(x: size.width / 2 + CGFloat(i) * 25, y: horizon))
                        floor.addLine(to: CGPoint(x: size.width / 2 + CGFloat(i) * 140, y: size.height))
                    }
                    for fraction in [0.0, 0.1, 0.25, 0.48, 0.75, 1.0] {
                        let y = horizon + (size.height - horizon) * fraction
                        floor.move(to: CGPoint(x: 0, y: y)); floor.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(floor, with: .color(accent.opacity(0.1)), lineWidth: 0.5)
                }
            }.ignoresSafeArea()
        }.allowsHitTesting(false)
    }
}
