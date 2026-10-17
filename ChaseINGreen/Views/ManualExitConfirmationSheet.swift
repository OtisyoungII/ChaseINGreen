import SwiftUI

struct ManualExitConfirmationSheet: View {
    let trade: LoggedTradeResponse
    let accessToken: String
    let onComplete: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var priceText = ""
    @State private var preview: APIService.ManualExitPreview?
    @State private var error: String?
    @State private var saving = false
    @State private var accounts: [BrokerAccountResponse] = []
    @State private var accountId: UUID?


    var body: some View {
        NavigationStack {
            Form {
                Section("Historical manual execution") {
                    Text("\(trade.symbol) • quantity \(trade.quantity ?? 0, specifier: "%.4g")")
                    Text("Entry: \(trade.entryPrice.map { String(format: "%.4f", $0) } ?? "Unavailable")")
                    Text("Closed: \(trade.closedAt ?? "Unknown")")
                    TextField("Actual historical exit price", text: $priceText)
                    if trade.canonicalAccountId == nil {
                        Picker("Associate closed leg with account", selection: $accountId) {
                            Text("Leave unassociated").tag(UUID?.none)
                            ForEach(accounts) { account in
                                Text(account.accountName ?? account.broker).tag(Optional(account.id))
                            }
                        }
                        Text("Only this closed leg is linked. The surviving position is not changed.").font(.caption)
                    }
                    Text("Enter the price you actually executed. No current quote is substituted. This does not claim broker confirmation.")
                }
                if let preview {
                    Section("Review realization") {
                        Text("Gross P/L: \(preview.gross_pnl.map { String(format: "%.2f", $0) } ?? "Unavailable")")
                        Text("Known costs: \(preview.known_costs, specifier: "%.2f")")
                        Text("Net P/L: \(preview.net_pnl.map { String(format: "%.2f", $0) } ?? "Unavailable")")
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
                Button("Confirm my historical exit") {
                    guard let price = Double(priceText), preview?.exit_price == price else { return }
                    saving = true
                    Task {
                        do {
                            try await APIService.shared.confirmHistoricalExit(tradeId: trade.id, price: price, accountId: accountId, accessToken: accessToken)
                            await onComplete()
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                        saving = false
                    }
                }.disabled(saving || preview?.net_pnl == nil || preview?.exit_price != Double(priceText))
            }
            .navigationTitle("Confirm exit price")
            .toolbar { Button("Cancel") { dismiss() } }
            .task {
                if trade.canonicalAccountId == nil {
                    do { accounts = try await APIService.shared.fetchBrokerAccounts(accessToken: accessToken) }
                    catch { self.error = error.localizedDescription }
                }
            }
            .task(id: priceText) {
                preview = nil
                error = nil
                guard let price = Double(priceText), price.isFinite, price > 0 else { return }
                do {
                    let result = try await APIService.shared.previewManualExit(tradeId: trade.id, price: price, quantity: nil, accessToken: accessToken)
                    guard !Task.isCancelled, Double(priceText) == price else { return }
                    preview = result
                } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
            }
        }
    }
}
