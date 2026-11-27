import SwiftUI
import UIKit

/// Official Crypto surface only; product access is enforced independently on the server.
struct RobinhoodConnectionView: View {
    let accessToken: String
    let initialConnectionID: String?
    init(accessToken: String, initialConnectionID: String? = nil) {
        self.accessToken = accessToken
        self.initialConnectionID = initialConnectionID
    }
    @State private var connections: [RHConnection] = []
    @State private var name = "Personal Crypto"
    @State private var apiKey = ""
    @Environment(\.scenePhase) private var scenePhase
    @State private var onboardingOwner: String?
    @State private var publicKey: RobinhoodPublicKey?
    @State private var showingSetup = false
    @State private var step = RobinhoodOnboardingStep.introduction
    @State private var readPermissionsConfirmed = false
    @State private var feeTierPermissionConfirmed = false
    @State private var discardConfirmation = false
    @State private var progress: String?
    private let keys = RobinhoodOnboardingKeys()
    @State private var message: String?
    @State private var busy = false
    @State private var accounts: [RHAccountTruth] = []
    @State private var selectedID: String?
    @State private var serverAvailable = false
    private let root = "/crypto-brokers/robinhood/connections"

    var body: some View {
        Form {
            Section("Robinhood · Read only") {
                Text("Crypto API • Chase Gold / Admin")
                Text("Trading permission at Robinhood does not authorize Chase to trade. Live order submission is disabled.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Equities and options are not available through this Crypto credential. Robinhood Trading MCP is a separate integration and is not connected here.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let message { Section { Text(message).foregroundStyle(.secondary) } }
            if let progress { Section { ProgressView(progress) } }
            Section("Connections") {
                if connections.isEmpty { Text("Not connected") }
                ForEach(connections) { connection in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(connection.name).font(.headline)
                        Text(connection.status.replacingOccurrences(of: "_", with: " "))
                        Button("View retained account truth") {
                            Task { await loadTruth(connection.id, refresh: false) }
                        }
                        Button("Refresh — read only") {
                            Task { await loadTruth(connection.id, refresh: true) }
                        }
                    }
                }
            }
            ForEach(accounts, id: \.snapshot.account.identity.native_account_id) { item in
                Section("Crypto • …\(String(item.snapshot.account.identity.native_account_id.suffix(4)))") {
                    if let cid = selectedID, let aid = item.snapshot.account.identity.canonical_account_id {
                        NavigationLink("Review a crypto trade") {
                            RobinhoodConfirmTradeView(connectionID: cid, accountID: aid,
                                accountSuffix: String(item.snapshot.account.identity.native_account_id.suffix(4)), accessToken: accessToken)
                        }
                    }
                    LabeledContent("Evidence", value: item.snapshot.account.freshness)
                    LabeledContent("Observed", value: readable(item.snapshot.account.received_at))
                    LabeledContent("Buying power", value: amount(item.snapshot.account.buying_power))
                    Text("Equity / account balance: Not provided")
                    Text("Provider timestamp: Not provided; observation time shown")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Holdings: \(item.snapshot.positions.count)")
                    ForEach(Array(item.snapshot.positions.enumerated()), id: \.offset) { _, position in
                        LabeledContent(position.identity.instrument_id ?? "Unavailable", value: amount(position.quantity))
                    }
                    Text("Order history: \(item.snapshot.orders.count) retained records")
                    ForEach(Array(item.snapshot.orders.enumerated()), id: \.offset) { _, order in
                        Text("\(order.identity.symbol ?? "Unavailable") • \(order.side) • \(order.order_status ?? "Unknown")")
                            .font(.caption)
                    }
                    Text("Protection coverage: Unknown • no execution authority")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if showingSetup {
                onboardingSection
            } else {
                Section {
                    Button(connections.isEmpty ? "Connect Robinhood" : "Connect another Robinhood account") {
                        showingSetup = true
                        step = publicKey == nil ? .introduction : .publicKey
                    }
                    .disabled(!serverAvailable || onboardingOwner == nil)
                }
            }
        }
        .navigationTitle("Robinhood")
        .disabled(busy)
        .task(id: accessToken) { await load() }
        .onDisappear { apiKey = "" }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { apiKey = "" }
        }
        .confirmationDialog("Discard this unfinished connection key?", isPresented: $discardConfirmation, titleVisibility: .visible) {
            Button("Discard unfinished setup", role: .destructive) { discardDraft() }
        } message: {
            Text("This removes only the pending key on this iPhone. Existing Chase connections and Robinhood accounts are unchanged. A public key already registered with Robinhood will no longer match a new setup key.")
        }
    }
    private func amount(_ value: Double?) -> String {
        value.map { String($0) } ?? "Not provided"
    }
    private func readable(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
        return date?.formatted(date: .abbreviated, time: .standard) ?? "Unavailable"
    }
    @MainActor private func load() async {
        let generation = AuthSessionCoordinator.shared.sessionGeneration
        busy = true; defer { busy = false }
        do {
            let data = try await APIService.shared.sendRequest(path: root, method: "GET", accessToken: accessToken, label: "Robinhood connections")
            guard AuthSessionCoordinator.shared.isCurrentSession(generation) else { return }
            let result = try JSONDecoder().decode(RHConnections.self, from: data)
            connections = result.connections
            if onboardingOwner != result.onboarding_owner {
                apiKey = ""; publicKey = nil; showingSetup = false; step = .introduction
                readPermissionsConfirmed = false; feeTierPermissionConfirmed = false
            }
            onboardingOwner = result.onboarding_owner
            if let owner = onboardingOwner { publicKey = try keys.pendingPublicKey(owner: owner) }
            serverAvailable = true; message = nil
            if selectedID == nil, let initialConnectionID,
               connections.contains(where: { $0.id == initialConnectionID }) {
                await loadTruth(initialConnectionID, refresh: false)
            } else if initialConnectionID == nil, connections.count == 1, selectedID == nil {
                await loadTruth(connections[0].id, refresh: false)
            }
        } catch {
            serverAvailable = false
            message = "Robinhood connection service unavailable or access not authorized. Existing broker accounts have not been changed."
        }
    }
    @ViewBuilder private var onboardingSection: some View {
        Section("Step \(step.rawValue + 1) of 4 · \(step.title)") {
            switch step {
            case .introduction:
                Text("Connect your crypto account through Robinhood’s official Crypto API. You’ll create a credential in Robinhood, then return here to verify it.")
                Text("Your iPhone creates the signing key. You never need to send a private key to support.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Continue") { generateKey() }
            case .publicKey:
                if let publicKey {
                    Text("Public key").font(.headline)
                    Text(publicKey.base64).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    Button("Copy Public Key") {
                        UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: publicKey.base64]], options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(600)])
                        message = "Public key copied. Paste it into Robinhood’s Public key field."
                    }
                    Text("This is safe to provide to Robinhood. Chase keeps the private signing key protected.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Continue to permissions") { step = .permissions; message = nil }
                }
            case .permissions:
                Text("In Robinhood, open Crypto → API Trading → Add key. Name your key, then paste the public key.")
                Link("Open Robinhood Crypto settings", destination: URL(string: "https://robinhood.com/account/crypto")!)
                Text("Enable these read permissions:").font(.headline)
                ForEach(["Read crypto accounts", "Read crypto holdings", "Read crypto orders", "Read crypto products", "Read crypto quotes"], id: \.self) { Text("• " + $0).font(.subheadline) }
                Toggle("I enabled all five read permissions", isOn: $readPermissionsConfirmed)
                Text("For full future trading capability, also enable “Place crypto orders with fee tiers” in Robinhood.")
                    .font(.subheadline)
                Toggle("I enabled fee-tier order permission", isOn: $feeTierPermissionConfirmed)
                Text("Robinhood permitting trading is separate from your approval for Chase to trade. Connecting here enables no live orders or Auto Trader.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("I have my Robinhood API key") { step = .apiKey; message = nil }
                    .disabled(!readPermissionsConfirmed)
            case .apiKey:
                TextField("Connection name", text: $name)
                SecureField("Robinhood API key", text: $apiKey)
                    .textContentType(nil).textInputAutocapitalization(.never).autocorrectionDisabled().privacySensitive()
                Text("Enter the API key Robinhood issued. Chase will securely pair it with the protected key generated on this iPhone.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Connect Robinhood") { Task { await save() } }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || publicKey == nil || !readPermissionsConfirmed)
            }
            if step != .introduction {
                Button("Back") { step = RobinhoodOnboardingStep(rawValue: step.rawValue - 1) ?? .introduction; apiKey = "" }
            }
            Button("Finish later") { showingSetup = false; apiKey = "" }
            if publicKey != nil {
                Button("Discard unfinished setup", role: .destructive) { discardConfirmation = true }
            }
        }
    }
    private func generateKey() {
        guard let owner = onboardingOwner else { return }
        do {
            publicKey = try keys.generate(owner: owner)
            step = .publicKey; message = nil
        } catch {
            message = "A protected connection key could not be created. Ensure this iPhone is unlocked and has a device passcode, then try again."
        }
    }
    private func discardDraft() {
        guard let owner = onboardingOwner, let publicKey else { return }
        do {
            try keys.discard(owner: owner, expectedPublicKey: publicKey)
            self.publicKey = nil; apiKey = ""; step = .introduction
            readPermissionsConfirmed = false; feeTierPermissionConfirmed = false
        } catch { message = "The pending key could not be removed. Your existing connections are unchanged." }
    }
    @MainActor private func save() async {
        guard let owner = onboardingOwner, let publicKey else { return }
        let generation = AuthSessionCoordinator.shared.sessionGeneration
        busy = true; progress = "Connecting securely…"
        defer { busy = false; progress = nil; apiKey = "" }
        do {
            var body = try keys.intakeBody(owner: owner, publicKey: publicKey, name: name, apiKey: apiKey, feeTierPermission: feeTierPermissionConfirmed)
            defer { body.resetBytes(in: 0..<body.count) }
            let data = try await APIService.shared.saveRobinhoodConnection(body: body)
            let connection = try JSONDecoder().decode(RHConnection.self, from: data)
            apiKey = ""
            do {
                try keys.discard(owner: owner, expectedPublicKey: publicKey)
                self.publicKey = nil
            } catch {
                message = "Connection saved. This iPhone still has a protected setup draft; discard the unfinished draft when available."
            }
            guard AuthSessionCoordinator.shared.isCurrentSession(generation) else { return }
            showingSetup = false
            if !connections.contains(where: { $0.id == connection.id }) { connections.append(connection) }
            progress = "Verifying Robinhood account and holdings…"
            // One bounded synchronization, never retry a provider read automatically.
            await loadTruth(connection.id, refresh: true)
        } catch {
            message = "Connection could not be confirmed. Your protected setup key is retained so you can retry with the same Robinhood API key. Never send credentials to support."
        }
    }
    @MainActor private func loadTruth(_ id: String, refresh: Bool) async {
        let generation = AuthSessionCoordinator.shared.sessionGeneration
        busy = true; defer { busy = false }
        if selectedID != id { accounts = []; selectedID = id }
        do {
            let data = try await APIService.shared.sendRequest(path: root + "/\(id)/" + (refresh ? "refresh" : "truth"), method: refresh ? "POST" : "GET", accessToken: accessToken, label: "Robinhood read-only truth", timeoutInterval: 40)
            guard AuthSessionCoordinator.shared.isCurrentSession(generation) else { return }
            let result = try JSONDecoder().decode(RHTruth.self, from: data)
            accounts = result.accounts
            if let index = connections.firstIndex(where: { $0.id == id }) { connections[index] = result.connection }
            message = accounts.isEmpty ? "No verified account snapshot yet. This does not mean the account is empty." : (refresh ? (result.connection.status == "CONNECTED" ? "Connection verified." : "Account verified. Some supporting reads are incomplete.") : nil)
        } catch {
            accounts = [] // never display previously fresh labels after a failed refresh
            message = "Read unavailable, rate limited, or authentication required. Retained server evidence is preserved; view it to inspect stale truth."
        }
    }
}
struct RHConnection: Decodable, Identifiable { let id: String; let name: String; let status: String }
struct RHConnections: Decodable { let connections: [RHConnection]; let onboarding_owner: String? }
struct RHTruth: Decodable { let connection: RHConnection; let accounts: [RHAccountTruth] }
struct RHAccountTruth: Decodable {
    let snapshot: RHSnapshot
    let pairs: [RHRetainedPair]?
    let observed_at: String?
    enum CodingKeys: String, CodingKey { case snapshot, pairs, observed_at }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        snapshot = try c.decode(RHSnapshot.self, forKey: .snapshot)
        pairs = try? c.decode([RHRetainedPair].self, forKey: .pairs)
        observed_at = try? c.decode(String.self, forKey: .observed_at)
    }
}
struct RHRetainedPair: Decodable {
    let symbol: String
    let is_api_tradable: Bool?
    let min_order_size: String?
    let max_order_size: String?
    let asset_increment: String?
    let quote_increment: String?
    enum CodingKeys: String, CodingKey { case symbol, is_api_tradable, min_order_size, max_order_size, asset_increment, quote_increment }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try c.decode(String.self, forKey: .symbol)
        is_api_tradable = try? c.decode(Bool.self, forKey: .is_api_tradable)
        func text(_ key: CodingKeys) -> String? {
            if let value = try? c.decode(String.self, forKey: key) { return value }
            return (try? c.decode(Double.self, forKey: key)).map { String($0) }
        }
        min_order_size = text(.min_order_size); max_order_size = text(.max_order_size)
        asset_increment = text(.asset_increment); quote_increment = text(.quote_increment)
    }
}
struct RHSnapshot: Decodable { let account: RHAccount; let positions: [RHPosition]; let orders: [RHOrder] }
struct RHIdentity: Decodable { let native_account_id: String; let canonical_account_id: String?; let instrument_id: String?; let symbol: String? }
struct RHAccount: Decodable { let identity: RHIdentity; let freshness: String; let received_at: String; let buying_power: Double? }
struct RHPosition: Decodable { let identity: RHIdentity; let quantity: Double? }
struct RHOrder: Decodable { let identity: RHIdentity; let side: String; let order_status: String? }
