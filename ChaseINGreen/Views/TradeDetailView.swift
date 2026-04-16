//
//  TradeDetailView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 4/16/26.
//

import SwiftUI

struct TradeDetailView: View {
    let trade: Trade

    var body: some View {
        List {
            Section("Overview") {
                row("Asset", trade.asset.displayName)
                row("Direction", trade.direction.displayName)
                row("Entry", trade.entryPrice)
                row("Stop Loss", trade.stopLoss)
                row("Take Profit", trade.takeProfit)
            }

            Section("Timing") {
                row("Opened", trade.openedAt.formatted(date: .abbreviated, time: .shortened))
            }

            if !trade.notes.isEmpty {
                Section("Notes") {
                    Text(trade.notes)
                }
            }
        }
        .navigationTitle(trade.asset.displayName)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
