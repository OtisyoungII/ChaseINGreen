import SwiftUI

/// Shared retained-truth presentation. No valuation, order or provider requests.
struct NormalizedPositionCard: View {
    let position: LoggedTradeResponse
    private var holding: Bool { position.activitySubtype == "spotHolding" }
    private func value(_ number: Double?) -> String { MarketNumberFormat.price(number) }

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
            LabeledContent("Current price", value: value(position.currentPrice))
            LabeledContent("Market value", value: value(position.marketValue))
            LabeledContent("Unrealized P/L", value: value(position.pnlAvailable == true ? position.openPnl : nil))
            Text("Currency: \(position.currency ?? "Unavailable") · retained values")
                .foregroundStyle(.secondary)
            if !holding {
                LabeledContent("Reported SL / TP", value: "\(value(position.stopLoss)) / \(value(position.takeProfit))")
                Text("Reported values alone do not verify active protection.").foregroundStyle(.secondary)
            }
            Text("Observed \(observedTime) · Reported freshness: \(position.brokerFreshness ?? "Unavailable")")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(12)
        .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }

    private var observedTime: String {
        guard let raw = position.brokerSnapshotAt ?? position.lastBrokerConfirmationAt else { return "Unavailable" }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return (parser.date(from: raw) ?? ISO8601DateFormatter().date(from: raw))?
            .formatted(date: .abbreviated, time: .standard) ?? "Unavailable"
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
                Text("Management").font(.headline)
                Text("This retained position snapshot does not establish current action authorization. Use the existing provider workspace and confirmation flow for supported actions. Analysis does not authorize execution.")
                    .font(.callout).foregroundStyle(.secondary)
            }.padding()
        }
        .navigationTitle(position.marketDisplaySymbol)
        .navigationBarTitleDisplayMode(.inline)
    }
}
