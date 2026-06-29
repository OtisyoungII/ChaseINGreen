//
//  TradeReviewCard.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import SwiftUI

struct TradeReviewCard: View {
    let review: TradeReviewResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(review.headline)
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.softGold)

                Spacer()

                Text("\(review.grade)/100 \(review.gradeLetter)")
                    .font(.headline.bold())
                    .foregroundStyle(gradeColor)
            }

            Text(review.summary)
                .font(.caption)
                .foregroundStyle(AppTheme.primaryText)

            if let accountKey = review.accountKey {
                Text("Scope: \(accountKey) • \(review.scopedTradesCount ?? 0) trade(s)")
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.secondaryText)
            }

            section("Strengths", review.strengths)
            section("Improve", review.improvements)
            section("Coach", review.coachingNotes)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var gradeColor: Color {
        if review.grade >= 80 { return .green }
        if review.grade >= 60 { return .orange }
        return .red
    }

    @ViewBuilder
    private func section(_ title: String, _ text: String) -> some View {
        if !text.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.softGold)

                Text(text.replacingOccurrences(of: " | ", with: "\n• "))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }
}