//
//  CandleChartView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/13/26.
//

import SwiftUI

struct CandleChartView: View {
    let candles: [MarketCandle]
    let currentPrice: Double?
    let showAILevels: Bool
    let context: PreTradeContextResponse?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(AppTheme.deepBlack.opacity(0.65))

                VStack(spacing: 10) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.largeTitle)
                        .foregroundStyle(AppTheme.gold)

                    Text("Live Candle Chart")
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.primaryText)

                    Text(showAILevels ? "AI levels unlocked" : "AI levels locked")
                        .font(.caption.bold())
                        .foregroundStyle(showAILevels ? .green : AppTheme.secondaryText)
                }
            }
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    CandleChartView(
        candles: [],
        currentPrice: 77.80,
        showAILevels: false,
        context: nil
    )
}
