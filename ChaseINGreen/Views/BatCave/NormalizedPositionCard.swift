import SwiftUI

/// Shared retained-truth presentation. No valuation, order or provider requests.
struct NormalizedPositionCard: View {
    let position: LoggedTradeResponse
    private var holding: Bool { position.activitySubtype == "spotHolding" }
    private func value(_ number: Double?) -> String { number == nil ? "—" : MarketNumberFormat.price(number) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(position.marketDisplaySymbol).font(.headline)
                Spacer()
                Text(holding ? "Spot holding" : position.direction).font(.caption.bold())
            }
            Text("\(position.provider ?? "Provider unavailable") · \(position.accountDisplayName ?? position.brokerAccountName ?? "Account unavailable")")
                .font(.caption).foregroundStyle(.secondary)
            LabeledContent("Quantity", value: MarketNumberFormat.quantity(position.quantity))
            if holding {
                LabeledContent("Available", value: MarketNumberFormat.quantity(position.availableQuantity))
                LabeledContent("Reserved", value: MarketNumberFormat.quantity(position.heldQuantity))
            }
            LabeledContent(holding ? "Cost basis / unit" : "Entry", value: value(holding && position.costBasisAvailable != true ? nil : position.knownEntryPrice))
            LabeledContent("Last-known price", value: value(position.currentPrice))
            LabeledContent("Market value", value: MarketNumberFormat.currency(position.marketValue, code: position.currency))
            LabeledContent("Unrealized P/L", value: MarketNumberFormat.currency(position.pnlAvailable == true ? position.openPnl : nil, code: position.currency))
            Text("Currency: \(position.currency ?? "Unavailable") · retained values")
                .foregroundStyle(.secondary)
            if !holding {
                LabeledContent("Reported SL / TP", value: "\(value(position.stopLoss)) / \(value(position.takeProfit))")
                Text("Reported values alone do not verify active protection.").foregroundStyle(.secondary)
            }
            TimelineView(.periodic(from: .now, by: 15)) { timeline in
                if let valuation = position.marketValuation {
                    Text(valuation.label(at: timeline.date)).foregroundStyle(.secondary)
                } else {
                    Text("Last known · \(observedTime) · current price freshness unverified").foregroundStyle(.secondary)
                }
            }
            DisclosureGroup("Evidence & reconciliation") {
                Text(basisExplanation).font(.caption)
                Text("Reconciliation: \(position.basisStatus ?? "No acquisition reconciliation supplied")")
                Text("Snapshot: \(position.brokerSnapshotAt ?? position.lastBrokerConfirmationAt ?? "Unavailable")").textSelection(.enabled)
                Text("Snapshot time records observation, not purchase time. Market value does not establish acquisition cost. — means missing, never zero.")
            }
        }
        .font(.caption)
        .padding(12)
        .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }

    private var basisExplanation: String {
        switch position.basisStatus {
        case "unknown_incomplete_history": return "Acquisition history is incomplete. Existing account synchronization must reconcile executions and ledger history before basis can be supplied."
        case "unknown_transfer_or_deposit": return "Transferred or deposited assets have unresolved acquisition cost. Transfers are not purchases or profit."
        case "unknown_quantity_mismatch": return "Known executions do not explain the full holding quantity. Unknown and known acquisition cost must not be combined."
        case "known" where position.providerKey.lowercased().contains("kraken"):
            return "Existing Kraken reconciliation uses confirmed USD fills and fees with proportional weighted-average disposal, and requires complete matching ledger/quantity history. This is reconstructed basis, not broker tax-lot advice."
        default: return "Only supplied basis is displayed. Unresolved history is not valued at the current price. Realized P/L and cash flows require separate execution and ledger evidence."
        }
    }
    private var observedTime: String {
        MarketNumberFormat.timestamp(position.brokerSnapshotAt ?? position.lastBrokerConfirmationAt)
    }

}

/// Inspection does not infer execution authority from a normalized portfolio row.
struct NormalizedPositionDetails: View {
    let position: LoggedTradeResponse
    let accessToken: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NormalizedPositionCard(position: position)
                Text("Account identity").font(.headline)
                Text(position.canonicalAccountId ?? position.brokerAccountId ?? "Unavailable").font(.caption).textSelection(.enabled)
                NavigationLink("Analyze instrument") {
                    MarketDetailView(
                        requestSymbol: position.brokerInstrumentContext?.canonicalSymbol ?? position.symbol,
                        displayName: position.assetDisplayName ?? position.marketDisplaySymbol,
                        tradeSymbol: position.symbol,
                        accessToken: accessToken,
                        broker: position.providerKey,
                        accountKey: position.canonicalAccountId ?? position.brokerAccountId,
                        connectionID: position.connectionId,
                        instrumentID: position.providerPair ?? position.providerSymbol
                    )
                }.buttonStyle(.borderedProminent)
                NavigationLink("Journal / Calendar — all authorized accounts") {
                    TradingCalendarView(accessToken: accessToken)
                }
                Text("Calendar opens the existing account-aware history. This link does not imply every holding has reconciled transaction history.").font(.caption).foregroundStyle(.secondary)
                Text("Management").font(.headline)
                Text("This retained position snapshot does not establish current action authorization. Use the existing provider workspace and confirmation flow for supported actions. Analysis does not authorize execution.")
                    .font(.callout).foregroundStyle(.secondary)
            }.padding()
        }
        .navigationTitle(position.marketDisplaySymbol)
        .navigationBarTitleDisplayMode(.inline)
    }
}
