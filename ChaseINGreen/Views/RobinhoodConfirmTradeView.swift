import SwiftUI

/// Native review over the real owner-scoped server proposal; never an app-only order.
struct RobinhoodConfirmTradeView: View {
    let connectionID: String
    let accountID: String
    let accountSuffix: String
    let accessToken: String
    @Environment(\.dismiss) private var dismiss
    @State private var symbol = "BTC-USD"
    @State private var side = "buy"
    @State private var quantity = ""
    @State private var orderType = "market"
    @State private var limitPrice = ""
    @State private var proposal: RobinhoodTradeProposal?
    @State private var busy = false
    @State private var message: String?
    @State private var confirmAttempted = false
    private let root = "/crypto-brokers/robinhood"

    var body: some View {
        Form {
            if let proposal { review(proposal) } else { preparation }
            if busy { ProgressView("Checking Robinhood…") }
            if let message { Section { Text(message).foregroundStyle(.secondary) } }
        }
        .navigationTitle("Confirm Trade")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .onChange(of: accessToken) { _, _ in proposal = nil; confirmAttempted = false }
    }

    private var preparation: some View {
        Section("Robinhood Crypto · …\(accountSuffix)") {
            Text("Prepare a supervised trade review. This is not a Chase market recommendation.")
                .font(.caption).foregroundStyle(.secondary)
            TextField("Pair, e.g. BTC-USD", text: $symbol).textInputAutocapitalization(.characters).autocorrectionDisabled()
            Picker("Direction", selection: $side) { Text("BUY").tag("buy"); Text("SELL held crypto").tag("sell") }
            TextField("Crypto quantity", text: $quantity).keyboardType(.decimalPad)
            Picker("Order", selection: $orderType) { Text("Market").tag("market"); Text("Limit · GTC").tag("limit") }
            if orderType == "limit" { TextField("Limit price · USD", text: $limitPrice).keyboardType(.decimalPad) }
            Toggle("Attached stop", isOn: .constant(false)).disabled(true)
            Text("Robinhood supports separate stop orders. An atomic entry with an attached stop is not available here. Chase will not claim protection from a checkbox.")
                .font(.caption).foregroundStyle(.secondary)
            Text("Real submission remains blocked pending authorization for the specific first live test.")
                .font(.caption).foregroundStyle(.orange)
            Button("Prepare trade review — no order") { Task { await prepare() } }
                .disabled(busy || quantity.isEmpty || (orderType == "limit" && limitPrice.isEmpty))
        }
    }

    @ViewBuilder private func review(_ p: RobinhoodTradeProposal) -> some View {
        Section {
            Text(p.symbol).font(.title2.bold())
            Text(p.side).font(.headline).foregroundStyle(p.side == "BUY" ? .green : .orange)
            LabeledContent("Broker / account", value: "Robinhood Crypto · …\(p.account_suffix)")
            LabeledContent("Quantity", value: p.quantity)
            LabeledContent("Estimated value", value: "$\(p.estimated_notional)")
            LabeledContent("Order", value: p.order_type.capitalized + (p.order_type == "limit" ? " · GTC" : ""))
            if let price = p.requested_price { LabeledContent("Requested price", value: "$\(price)") }
            LabeledContent("Market reference", value: "$\(p.market_reference)")
            LabeledContent("Estimated fee", value: "$\(p.estimated_fee)")
            if let risk = p.maximum_capital_at_risk { LabeledContent("Capital at risk · estimated", value: "$\(risk)") }
            Text(p.risk_note).font(.caption).foregroundStyle(.secondary)
            LabeledContent("Protection", value: "Not protected")
            Text("No attached stop will be submitted.").font(.caption).foregroundStyle(.orange)
        }
        Section("Reasoning") { Text(p.reasoning).font(.subheadline) }
        Section("Evidence") {
            if let market = RobinhoodTradeProposal.date(p.market_at) { LabeledContent("Market", value: market.formatted(date: .omitted, time: .standard)) }
            if let expires = RobinhoodTradeProposal.date(p.expires_at) { LabeledContent("Review expires", value: expires.formatted(date: .omitted, time: .standard)) }
            LabeledContent("Status", value: p.state.replacingOccurrences(of: "_", with: " ").uppercased())
            ForEach(Array(p.blockers.enumerated()), id: \.offset) { _, blocker in
                Text(RobinhoodTradeProposal.blockerText(blocker)).font(.caption).foregroundStyle(.orange)
            }
        }
        Section {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Button("Confirm Trade") { Task { await confirm(p) } }
                    .buttonStyle(.borderedProminent)
                    .disabled(busy || confirmAttempted || !p.permitsConfirmation(at: context.date))
            }
            if p.state == "previewed" {
                Button("Prepare a fresh review") { proposal = nil; confirmAttempted = false }
                    .disabled(busy)
            } else {
                Button("Check broker result — read only") { Task { await reconcile(p) } }.disabled(busy)
                Text("An uncertain submission is never retried. Broker acknowledgment is not a fill.").font(.caption)
            }
            Button("Cancel", role: .cancel) { dismiss() }.disabled(busy)
        }
    }

    @MainActor private func prepare() async {
        guard !busy else { return }
        busy = true; message = nil; defer { busy = false }
        let generation = AuthSessionCoordinator.shared.sessionGeneration
        do {
            var payload: [String: Any] = ["canonical_account_id": accountID, "symbol": symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), "side": side, "quantity": quantity, "order_type": orderType, "protection_requested": false]
            if orderType == "limit" { payload["limit_price"] = limitPrice }
            let data = try await APIService.shared.sendRequest(path: root + "/connections/\(connectionID)/trade-proposals", method: "POST", accessToken: accessToken, body: try JSONSerialization.data(withJSONObject: payload), label: "Robinhood trade review", timeoutInterval: 40)
            guard AuthSessionCoordinator.shared.isCurrentSession(generation) else { return }
            let decoded = try JSONDecoder().decode(RobinhoodTradeProposal.self, from: data)
            proposal = decoded; confirmAttempted = false
            _ = try? await APIService.shared.sendRequest(path: root + "/trade-proposals/\(decoded.id)/presented", method: "POST", accessToken: accessToken, label: "Trade review presented")
        } catch {
            message = "Trade review unavailable, read cooldown active, or provider evidence incomplete. No order was sent."
        }
    }

    @MainActor private func confirm(_ p: RobinhoodTradeProposal) async {
        guard !busy, !confirmAttempted, p.permitsConfirmation(at: .now) else { return }
        confirmAttempted = true; busy = true; message = "Submitting exact confirmed proposal…"
        defer { busy = false }
        let generation = AuthSessionCoordinator.shared.sessionGeneration
        do {
            let data = try await APIService.shared.sendRequest(path: root + "/trade-proposals/\(p.id)/confirm", method: "POST", accessToken: accessToken, body: try JSONSerialization.data(withJSONObject: ["proposal_hash": p.proposal_hash, "confirm_exact_trade": true]), label: "Confirm exact Robinhood trade", timeoutInterval: 60, allowsAuthRefresh: false)
            guard AuthSessionCoordinator.shared.isCurrentSession(generation) else { return }
            proposal = try JSONDecoder().decode(RobinhoodTradeProposal.self, from: data); message = nil
        } catch {
            message = "Confirmation result unavailable or blocked. Do not retry submission. Check the retained broker result."
            await readRetained(p)
        }
    }
    @MainActor private func readRetained(_ p: RobinhoodTradeProposal) async {
        let generation = AuthSessionCoordinator.shared.sessionGeneration
        guard let data = try? await APIService.shared.sendRequest(path: root + "/trade-proposals/\(p.id)", method: "GET", accessToken: accessToken, label: "Retained execution state"), AuthSessionCoordinator.shared.isCurrentSession(generation) else { return }
        proposal = try? JSONDecoder().decode(RobinhoodTradeProposal.self, from: data)
    }
    @MainActor private func reconcile(_ p: RobinhoodTradeProposal) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        let generation = AuthSessionCoordinator.shared.sessionGeneration
        do {
            let data = try await APIService.shared.sendRequest(path: root + "/trade-proposals/\(p.id)/reconcile", method: "POST", accessToken: accessToken, label: "Robinhood independent readback", timeoutInterval: 40)
            guard AuthSessionCoordinator.shared.isCurrentSession(generation) else { return }
            proposal = try JSONDecoder().decode(RobinhoodTradeProposal.self, from: data); message = nil
        } catch { message = "Broker readback unavailable. No retry or additional order was sent." }
    }
}
