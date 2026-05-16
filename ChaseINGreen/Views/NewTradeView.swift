//
//  NewTradeView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 4/16/26.
//

import SwiftUI

struct NewTradeView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var asset: TradeAsset = .bitcoin
    @State private var direction: TradeDirection = .buy
    @State private var entryPrice = ""
    @State private var stopLoss = ""
    @State private var takeProfit = ""
    @State private var openedAt = Date()
    @State private var notes = ""

    let onSave: (Trade) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Trade") {
                    Picker("Asset", selection: $asset) {
                        ForEach(TradeAsset.allCases) { asset in
                            Text(asset.displayName).tag(asset)
                        }
                    }

                    Picker("Direction", selection: $direction) {
                        ForEach(TradeDirection.allCases) { direction in
                            Text(direction.displayName).tag(direction)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Entry") {
                    TextField("Entry Price", text: $entryPrice)
                    DatePicker("Opened At", selection: $openedAt)
                }

                Section("Risk") {
                    TextField("Stop Loss", text: $stopLoss)
                    TextField("Take Profit", text: $takeProfit)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("New Trade")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trade = Trade(
                            asset: asset,
                            direction: direction,
                            entryPrice: entryPrice,
                            stopLoss: stopLoss,
                            takeProfit: takeProfit,
                            openedAt: openedAt,
                            notes: notes
                        )
                        onSave(trade)
                        dismiss()
                    }
                    .disabled(entryPrice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
