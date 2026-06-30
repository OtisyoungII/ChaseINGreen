//
//  TradeReviewCard.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import SwiftUI

struct TradeReviewCard: View {
    let review: TradeReviewDetailResponse
    let outcome: TradeOutcomeResponse?

    private var safeHeadline: String {
        review.headline ?? "Trade Review"
    }

    private var safeGrade: Int {
        review.overallGrade ?? outcome?.outcomeGrade ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(safeHeadline)
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.softGold)

                Spacer()

                Text("\(safeGrade)/100")
                    .font(.headline.bold())
                    .foregroundStyle(gradeColor)
            }

            Text(review.summary ?? outcome?.outcomeSummary ?? "No review summary available.")
                .font(.caption)
                .foregroundStyle(AppTheme.primaryText)

            section("Strengths", review.strengths)
            section("Improve", review.improvements)
            section("Coach", review.coachingNotes)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var gradeColor: Color {
        if safeGrade >= 80 { return .green }
        if safeGrade >= 60 { return .orange }
        return .red
    }

    @ViewBuilder
    private func section(_ title: String, _ text: String?) -> some View {
        if let text, !text.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.softGold)

                Text("• " + text.replacingOccurrences(of: " | ", with: "\n• "))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }
}
