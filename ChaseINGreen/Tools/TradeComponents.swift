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
                    .foregroundStyle(AppTheme.secondaryText)

                Text(value)
                    .font(.headline.bold())
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.cardBlack)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.cardStroke)
        }
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
            .background(isSelected ? Color.primary.opacity(0.12) : Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
