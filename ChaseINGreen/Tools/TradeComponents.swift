//
//  TradeComponents.swift
//  ChaseINGreen
//
//  Created by Otis Young on 4/16/26.
//

import SwiftUI

struct DashboardStatCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.headline.bold())
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct AssetButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)

                Text(title)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(width: 82, height: 82)
            .background(isSelected ? Color.primary.opacity(0.12) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

struct TradeCardView: View {
    let trade: Trade

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(trade.asset.displayName, systemImage: trade.asset.systemImage)
                    .font(.headline)

                Spacer()

                Text(trade.direction.displayName)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
            }

            HStack {
                tradeMetric(title: "Entry", value: trade.entryPrice)
                tradeMetric(title: "Stop", value: trade.stopLoss)
                tradeMetric(title: "Target", value: trade.takeProfit)
            }

            HStack {
                Text("Opened")
                    .foregroundStyle(.secondary)

                Spacer()

                Text(trade.openedAt.formatted(date: .omitted, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            if !trade.notes.isEmpty {
                Text(trade.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func tradeMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
