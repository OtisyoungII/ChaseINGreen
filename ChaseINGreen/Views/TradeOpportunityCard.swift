//
//  TradeOpportunityCard.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/24/26.
//

import SwiftUI

struct TradeOpportunityCard: View {
    let opportunity: TradeOpportunityResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trade Opportunity")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.secondaryText)

                    Text(opportunity.symbol)
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.primaryText)
                }

                Spacer()

                Text(opportunity.bias.uppercased())
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.gold.opacity(0.18))
                    .foregroundStyle(AppTheme.gold)
                    .clipShape(Capsule())
            }

            Text(opportunity.setupType.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.headline.bold())
                .foregroundStyle(AppTheme.softGold)

            Text("Quality: \(opportunity.setupQuality.capitalized)")
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text(opportunity.runnerPotential ? "Runner potential active" : "No runner edge yet")
                .font(.caption.bold())
                .foregroundStyle(opportunity.runnerPotential ? .green : AppTheme.secondaryText)

            Text(opportunity.alertText)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding()
        .background(AppTheme.cardBlack)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.gold.opacity(0.35), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
