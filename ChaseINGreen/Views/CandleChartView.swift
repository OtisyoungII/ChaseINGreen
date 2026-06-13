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

    private let chartHeight: CGFloat = 250
    private let leftPadding: CGFloat = 10
    private let rightPadding: CGFloat = 54
    private let topPadding: CGFloat = 18
    private let bottomPadding: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(AppTheme.deepBlack.opacity(0.78))

                if candles.isEmpty {
                    emptyChart
                } else {
                    chartCanvas(size: proxy.size)
                }
            }
        }
        .frame(height: chartHeight)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var emptyChart: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.xyaxis.line")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.gold)

            Text("Loading Candle Chart")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text("Waiting for market candles.")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private func chartCanvas(size: CGSize) -> some View {
        let prices = allVisiblePrices
        let minPrice = prices.min() ?? 0
        let maxPrice = prices.max() ?? 1
        let range = max(maxPrice - minPrice, 0.01)

        func xPosition(_ index: Int) -> CGFloat {
            let plotWidth = max(size.width - leftPadding - rightPadding, 1)
            guard candles.count > 1 else { return leftPadding + plotWidth / 2 }
            return leftPadding + (CGFloat(index) / CGFloat(candles.count - 1)) * plotWidth
        }

        func yPosition(_ price: Double) -> CGFloat {
            let plotHeight = max(size.height - topPadding - bottomPadding, 1)
            let normalized = (price - minPrice) / range
            return topPadding + (1 - CGFloat(normalized)) * plotHeight
        }

        return ZStack {
            gridLines(size: size)

            ForEach(Array(candles.enumerated()), id: \.element.id) { index, candle in
                let x = xPosition(index)
                let openY = yPosition(candle.open)
                let closeY = yPosition(candle.close)
                let highY = yPosition(candle.high)
                let lowY = yPosition(candle.low)
                let isGreen = candle.close >= candle.open
                let candleWidth = max(min((size.width - leftPadding - rightPadding) / CGFloat(max(candles.count, 1)) * 0.55, 9), 3)

                Path { path in
                    path.move(to: CGPoint(x: x, y: highY))
                    path.addLine(to: CGPoint(x: x, y: lowY))
                }
                .stroke(isGreen ? Color.green : Color.red, lineWidth: 1.4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(isGreen ? Color.green.opacity(0.88) : Color.red.opacity(0.88))
                    .frame(width: candleWidth, height: max(abs(closeY - openY), 2))
                    .position(x: x, y: (openY + closeY) / 2)
            }

            if let currentPrice {
                priceLine(
                    title: "Now",
                    value: currentPrice,
                    y: yPosition(currentPrice),
                    color: AppTheme.gold,
                    size: size
                )
            }

            if showAILevels {
                aiLevelLines(yPosition: yPosition, size: size)
            }

            rightAxisLabels(
                minPrice: minPrice,
                maxPrice: maxPrice,
                size: size
            )
        }
        .padding(.vertical, 2)
    }

    private var allVisiblePrices: [Double] {
        var values = candles.flatMap { [$0.open, $0.high, $0.low, $0.close] }

        if let currentPrice {
            values.append(currentPrice)
        }

        if showAILevels, let context {
            values.append(contentsOf: [
                context.supportLevel,
                context.resistanceLevel,
                context.support1,
                context.support2,
                context.resistance1,
                context.resistance2,
                context.breakoutAbove,
                context.breakdownBelow,
                context.target1,
                context.target2
            ].compactMap { $0 })
        }

        return values
    }

    private func gridLines(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                let y = topPadding + CGFloat(index) * ((size.height - topPadding - bottomPadding) / 4)

                Path { path in
                    path.move(to: CGPoint(x: leftPadding, y: y))
                    path.addLine(to: CGPoint(x: size.width - rightPadding, y: y))
                }
                .stroke(AppTheme.cardStroke.opacity(0.45), lineWidth: 0.8)
            }
        }
    }

    private func aiLevelLines(
        yPosition: (Double) -> CGFloat,
        size: CGSize
    ) -> some View {
        ZStack {
            if let support = context?.supportLevel {
                priceLine(title: "Support", value: support, y: yPosition(support), color: .green, size: size)
            }

            if let resistance = context?.resistanceLevel {
                priceLine(title: "Resistance", value: resistance, y: yPosition(resistance), color: .red, size: size)
            }

            if let breakout = context?.breakoutAbove {
                priceLine(title: "Breakout", value: breakout, y: yPosition(breakout), color: .blue, size: size)
            }

            if let breakdown = context?.breakdownBelow {
                priceLine(title: "Breakdown", value: breakdown, y: yPosition(breakdown), color: .orange, size: size)
            }

            if let target = context?.target1 {
                priceLine(title: "Target", value: target, y: yPosition(target), color: AppTheme.gold, size: size)
            }
        }
    }

    private func priceLine(
        title: String,
        value: Double,
        y: CGFloat,
        color: Color,
        size: CGSize
    ) -> some View {
        ZStack(alignment: .leading) {
            Path { path in
                path.move(to: CGPoint(x: leftPadding, y: y))
                path.addLine(to: CGPoint(x: size.width - rightPadding, y: y))
            }
            .stroke(color.opacity(0.82), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))

            Text("\(title) \(formatPrice(value))")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(AppTheme.deepBlack.opacity(0.9))
                .clipShape(Capsule())
                .position(x: max(size.width - rightPadding - 34, 42), y: y - 10)
        }
    }

    private func rightAxisLabels(
        minPrice: Double,
        maxPrice: Double,
        size: CGSize
    ) -> some View {
        ZStack {
            Text(formatPrice(maxPrice))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)
                .position(x: size.width - 27, y: topPadding)

            Text(formatPrice((maxPrice + minPrice) / 2))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)
                .position(x: size.width - 27, y: size.height / 2)

            Text(formatPrice(minPrice))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)
                .position(x: size.width - 27, y: size.height - bottomPadding)
        }
    }

    private func formatPrice(_ value: Double) -> String {
        String(format: "%.2f", value)
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
