//
//  CandleChartView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/13/26.
//

import SwiftUI

enum CandleChartStyle: String, CaseIterable, Identifiable {
    case standard = "Candles"
    case heikinAshi = "Heikin Ashi"

    var id: String { rawValue }
}

struct CandleChartView: View {
    let candles: [MarketCandle]
    let currentPrice: Double?
    let showAILevels: Bool
    let context: PreTradeContextResponse?
    let chartStyle: CandleChartStyle
    let patternAnnotations: [PatternChartAnnotationDTO]
    let authoritativePatternIDs: Set<String>
    let enabledIndicators: Set<QuantMetricID>
    let interactiveWorkbench: Bool
    let chartHeight: CGFloat
    let replayOverlay: CandleReplayOverlay?
    let emaPeriods: Set<Int>
    @Binding var viewport: ChartViewport
    @State private var dragStartViewport: ChartViewport?
    @State private var zoomStartViewport: ChartViewport?
    @State private var indicatorSnapshot = QuantIndicatorSnapshot(
        ema20: [], bollingerUpper: [], bollingerMiddle: [], bollingerLower: [],
        rsi14: nil, macd: nil, macdSignal: nil, macdHistogram: nil, vwap: []
    )

    init(
        candles: [MarketCandle],
        currentPrice: Double?,
        showAILevels: Bool,
        context: PreTradeContextResponse?,
        chartStyle: CandleChartStyle = .standard,
        patternAnnotations: [PatternChartAnnotationDTO] = [],
        authoritativePatternIDs: Set<String> = [],
        enabledIndicators: Set<QuantMetricID> = [],
        interactiveWorkbench: Bool = false,
        chartHeight: CGFloat = 270,
        viewport: Binding<ChartViewport> = .constant(ChartViewport()),
        replayOverlay: CandleReplayOverlay? = nil,
        emaPeriods: Set<Int> = []
    ) {
        self.candles = candles
        self.currentPrice = currentPrice
        self.showAILevels = showAILevels
        self.context = context
        self.chartStyle = chartStyle
        self.patternAnnotations = patternAnnotations
        self.authoritativePatternIDs = authoritativePatternIDs
        self.enabledIndicators = enabledIndicators
        self.interactiveWorkbench = interactiveWorkbench
        self.chartHeight = chartHeight
        _viewport = viewport
        self.replayOverlay = replayOverlay
        self.emaPeriods = emaPeriods
    }

    private let leftPadding: CGFloat = 12
    private let rightPadding: CGFloat = 58
    private let topPadding: CGFloat = 18
    private let bottomPadding: CGFloat = 28

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(AppTheme.deepBlack.opacity(0.82))

                if candles.isEmpty {
                    emptyChart
                } else {
                    chartCanvas(size: proxy.size)
                }
            }
            .contentShape(Rectangle())
            .allowsHitTesting(interactiveWorkbench)
            .simultaneousGesture(panGesture(plotWidth: max(proxy.size.width - leftPadding - rightPadding, 1)))
            .simultaneousGesture(zoomGesture)
        }
        .frame(height: chartHeight)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear {
            var next = viewport
            next.normalize(loadedCount: candles.count)
            viewport = next
            indicatorSnapshot = QuantIndicatorEngine.calculate(candles)
        }
        .onChange(of: candles.count) { previousCount, loadedCount in
            var next = viewport
            next.reconcileLoadedCount(from: previousCount, to: loadedCount)
            viewport = next
            indicatorSnapshot = QuantIndicatorEngine.calculate(candles)
        }
        .onChange(of: indicatorInputVersion) { _, _ in
            indicatorSnapshot = QuantIndicatorEngine.calculate(candles)
        }
    }

    private var indicatorInputVersion: String {
        guard let last = candles.last else { return "empty" }
        return [
            String(candles.count), last.id,
            String(last.open.bitPattern), String(last.high.bitPattern),
            String(last.low.bitPattern), String(last.close.bitPattern),
            String(last.volume?.bitPattern ?? 0)
        ].joined(separator: "|")
    }

    private var emptyChart: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.xyaxis.line")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.gold)

            Text("Loading Candle Chart")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text("Waiting for real market candles.")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private func chartCanvas(size: CGSize) -> some View {
        let transformed = transformedCandles
        let visibleRange = viewport.range(loadedCount: transformed.count)
        let plottedCandles = Array(transformed[visibleRange])
        let sourceCandles = Array(candles[visibleRange])
        let prices = allVisiblePrices(from: plottedCandles, range: visibleRange, snapshot: indicatorSnapshot)
        let minPrice = prices.min() ?? 0
        let maxPrice = prices.max() ?? 1
        let rangePadding = max((maxPrice - minPrice) * 0.08, 0.01)
        let chartMin = minPrice - rangePadding
        let chartMax = maxPrice + rangePadding
        let range = max(chartMax - chartMin, 0.01)

        func xPosition(_ index: Int) -> CGFloat {
            let plotWidth = max(size.width - leftPadding - rightPadding, 1)
            guard plottedCandles.count > 1 else { return leftPadding + plotWidth / 2 }
            return leftPadding + (CGFloat(index) / CGFloat(plottedCandles.count - 1)) * plotWidth
        }

        func yPosition(_ price: Double) -> CGFloat {
            let plotHeight = max(size.height - topPadding - bottomPadding, 1)
            let normalized = (price - chartMin) / range
            return topPadding + (1 - CGFloat(normalized)) * plotHeight
        }

        return ZStack {
            gridLines(size: size)

            patternRegions(yPosition: yPosition, size: size)

            ForEach(Array(plottedCandles.enumerated()), id: \.element.id) { index, candle in
                candleBody(
                    candle: candle,
                    index: index,
                    candleCount: plottedCandles.count,
                    size: size,
                    xPosition: xPosition,
                    yPosition: yPosition
                )
            }

            if let currentPrice {
                priceLine(
                    title: replayOverlay == nil ? "Now" : "Replay",
                    value: currentPrice,
                    y: yPosition(currentPrice),
                    color: AppTheme.gold,
                    size: size
                )
            }

            if showAILevels {
                aiLevelLines(yPosition: yPosition, size: size)
            }

            indicatorLines(snapshot: indicatorSnapshot, range: visibleRange,
                xPosition: xPosition, yPosition: yPosition)

            patternPrimitives(candles: sourceCandles, xPosition: xPosition,
                yPosition: yPosition, size: size)

            replayPrimitives(candles: sourceCandles, xPosition: xPosition, yPosition: yPosition, size: size)

            rightAxisLabels(
                high: chartMax,
                middle: (chartMax + chartMin) / 2,
                low: chartMin,
                size: size
            )
        }
    }

    private func panGesture(plotWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if dragStartViewport == nil { dragStartViewport = viewport }
                var next = dragStartViewport ?? viewport
                let density = Double(max(next.visibleCount, 1)) / Double(max(plotWidth, 1))
                next.pan(candles: Int((Double(value.translation.width) * density).rounded()),
                         loadedCount: candles.count)
                viewport = next
            }
            .onEnded { _ in dragStartViewport = nil }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { value in
                if zoomStartViewport == nil { zoomStartViewport = viewport }
                let baseline = zoomStartViewport ?? viewport
                var next = baseline
                let focalAnchor = baseline.isFollowingLatest ? 1.0 : Double(value.startAnchor.x)
                next.zoom(scale: Double(value.magnification), loadedCount: candles.count,
                          anchorFraction: focalAnchor)
                viewport = next
            }
            .onEnded { _ in zoomStartViewport = nil }
    }

    private func candleBody(
        candle: MarketCandle,
        index: Int,
        candleCount: Int,
        size: CGSize,
        xPosition: (Int) -> CGFloat,
        yPosition: (Double) -> CGFloat
    ) -> some View {
        let x = xPosition(index)
        let openY = yPosition(candle.open)
        let closeY = yPosition(candle.close)
        let highY = yPosition(candle.high)
        let lowY = yPosition(candle.low)
        let isGreen = candle.close >= candle.open
        let spacing = (size.width - leftPadding - rightPadding) / CGFloat(max(candleCount, 1))
        let candleWidth = max(min(spacing * 0.62, 18), min(spacing * 0.45, 2.5))

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: x, y: highY))
                path.addLine(to: CGPoint(x: x, y: lowY))
            }
            .stroke(isGreen ? Color.green : Color.red, lineWidth: 1.2)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(isGreen ? Color.green.opacity(0.9) : Color.red.opacity(0.9))
                .frame(width: candleWidth, height: max(abs(closeY - openY), 2))
                .position(x: x, y: (openY + closeY) / 2)
        }
    }

    private var transformedCandles: [MarketCandle] {
        switch chartStyle {
        case .standard:
            return candles
        case .heikinAshi:
            return heikinAshiCandles(from: candles)
        }
    }

    private func heikinAshiCandles(from source: [MarketCandle]) -> [MarketCandle] {
        QuantIndicatorEngine.heikinAshi(source)
    }

    private func allVisiblePrices(
        from visibleCandles: [MarketCandle],
        range: Range<Int>,
        snapshot: QuantIndicatorSnapshot
    ) -> [Double] {
        var values = visibleCandles.flatMap { [$0.open, $0.high, $0.low, $0.close] }

        values.append(contentsOf: replayOverlay?.levels.values.map { $0 } ?? [])
        for period in emaPeriods {
            let series = QuantIndicatorEngine.emaSeries(candles.map(\.close), period: period)
            values.append(contentsOf: range.compactMap { series[$0] })
        }
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

        for annotation in patternAnnotations {
            values.append(contentsOf: [annotation.price, annotation.priceLow, annotation.priceHigh].compactMap { $0 })
        }
        if enabledIndicators.contains(.ema) {
            values.append(contentsOf: range.compactMap { snapshot.ema20[$0] })
        }
        if enabledIndicators.contains(.bollinger) {
            values.append(contentsOf: range.flatMap {
                [snapshot.bollingerUpper[$0], snapshot.bollingerLower[$0]].compactMap { $0 }
            })
        }
        if enabledIndicators.contains(.vwap) {
            values.append(contentsOf: range.compactMap { snapshot.vwap[$0] })
        }

        return values
    }

    private func patternRegions(
        yPosition: @escaping (Double) -> CGFloat,
        size: CGSize
    ) -> some View {
        ZStack {
            ForEach(patternAnnotations.filter { $0.annotationType == .priceRegion }) { annotation in
                if let low = annotation.priceLow, let high = annotation.priceHigh {
                    let upper = yPosition(max(low, high)), lower = yPosition(min(low, high))
                    Rectangle()
                        .fill(patternColor(annotation).opacity(annotationIsAuthoritative(annotation) ? 0.16 : 0.08))
                        .frame(width: max(size.width - leftPadding - rightPadding, 1),
                               height: max(lower - upper, 1))
                        .position(x: leftPadding + max(size.width - leftPadding - rightPadding, 1) / 2,
                                  y: (upper + lower) / 2)
                }
            }
        }
    }

    private func patternPrimitives(
        candles: [MarketCandle],
        xPosition: @escaping (Int) -> CGFloat,
        yPosition: @escaping (Double) -> CGFloat,
        size: CGSize
    ) -> some View {
        ZStack {
            ForEach(patternAnnotations) { annotation in
                switch annotation.annotationType {
                case .horizontalLevel:
                    if let price = annotation.price {
                        priceLine(title: viewport.showsDetailedAnnotations
                                  ? CustomerPresentation.patternAnnotation(annotation.semanticRole) : "", value: price,
                            y: yPosition(price), color: patternColor(annotation), size: size,
                            solid: annotationIsAuthoritative(annotation))
                    }
                case .patternPoint:
                    if let price = annotation.price,
                       let index = candles.firstIndex(where: {
                           guard let id = $0.candleID else { return false }
                           return annotation.sourceCandleIDs.contains(id)
                       }) {
                        Circle().fill(patternColor(annotation))
                            .frame(width: 8, height: 8)
                            .position(x: xPosition(index), y: yPosition(price))
                    }
                case .priceRegion, .label, .unknown:
                    EmptyView()
                }
            }
        }
    }

    private func indicatorLines(
        snapshot: QuantIndicatorSnapshot,
        range: Range<Int>,
        xPosition: @escaping (Int) -> CGFloat,
        yPosition: @escaping (Double) -> CGFloat
    ) -> some View {
        ZStack {
            ForEach(emaPeriods.sorted(), id: \.self) { period in
                seriesLine(QuantIndicatorEngine.emaSeries(candles.map(\.close), period: period), range: range, color: emaColor(period), xPosition: xPosition, yPosition: yPosition)
            }
            if enabledIndicators.contains(.ema) {
                seriesLine(snapshot.ema20, range: range, color: .yellow,
                           xPosition: xPosition, yPosition: yPosition)
            }
            if enabledIndicators.contains(.bollinger) {
                seriesLine(snapshot.bollingerUpper, range: range, color: .purple,
                           xPosition: xPosition, yPosition: yPosition)
                seriesLine(snapshot.bollingerMiddle, range: range, color: .purple.opacity(0.65),
                           xPosition: xPosition, yPosition: yPosition)
                seriesLine(snapshot.bollingerLower, range: range, color: .purple,
                           xPosition: xPosition, yPosition: yPosition)
            }
            if enabledIndicators.contains(.vwap) {
                seriesLine(snapshot.vwap, range: range, color: .cyan,
                           xPosition: xPosition, yPosition: yPosition)
            }
        }
    }

    private func seriesLine(
        _ values: [Double?], range: Range<Int>, color: Color,
        xPosition: @escaping (Int) -> CGFloat, yPosition: @escaping (Double) -> CGFloat
    ) -> some View {
        Path { path in
            var started = false
            for (local, global) in range.enumerated() {
                guard values.indices.contains(global), let value = values[global] else { continue }
                let point = CGPoint(x: xPosition(local), y: yPosition(value))
                if started { path.addLine(to: point) } else { path.move(to: point); started = true }
            }
        }
        .stroke(color.opacity(0.9), lineWidth: 1.3)
    }

    private func emaColor(_ period: Int) -> Color {
        switch period { case 12: return .cyan; case 26: return .orange; case 50: return .pink; default: return .yellow }
    }
    @ViewBuilder private func replayPrimitives(candles source: [MarketCandle],
        xPosition: @escaping (Int) -> CGFloat, yPosition: @escaping (Double) -> CGFloat, size: CGSize) -> some View {
        if let replayOverlay {
            ForEach(replayOverlay.levels.keys.sorted(), id: \.self) { key in
                if let price = replayOverlay.levels[key] {
                    priceLine(title: key.uppercased(), value: price, y: yPosition(price),
                              color: key == "stop" ? .red : key == "target" ? .green : .cyan, size: size)
                }
            }
            ForEach(replayOverlay.markers) { marker in
                if let index = ReplayChartEvidence.candleIndex(at: marker.at, candles: source), let price = marker.price,
                   marker.at <= (source.last?.timestamp ?? .distantPast).addingTimeInterval(source.count > 1 ? source[1].timestamp.timeIntervalSince(source[0].timestamp) : 0) {
                    Button { replayOverlay.select(marker) } label: {
                        Image(systemName: marker.action == "ENTRY" ? (replayOverlay.side == "short" ? "arrow.down.circle.fill" : "arrow.up.circle.fill") : marker.icon)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(marker.action == "EXIT" ? .orange : .cyan)
                            .padding(3).background(.black.opacity(0.7), in: Circle())
                    }.buttonStyle(.plain).position(x: xPosition(index), y: yPosition(price))
                        .accessibilityLabel(marker.action + " " + marker.at.formatted())
                }
            }
            ForEach(Array(Set([0, max(0, source.count / 2), max(0, source.count - 1)])).sorted(), id: \.self) { index in
                if source.indices.contains(index) {
                    Text(source[index].timestamp, format: .dateTime.hour().minute())
                        .font(.system(size: 9).monospacedDigit()).foregroundStyle(.secondary)
                        .position(x: xPosition(index), y: size.height - 10)
                }
            }
        }
    }

    private func annotationIsAuthoritative(_ annotation: PatternChartAnnotationDTO) -> Bool {
        PatternPresentationAuthority.isAuthoritative(
            annotation,
            authoritativePatternIDs: authoritativePatternIDs
        )
    }

    private func patternColor(_ annotation: PatternChartAnnotationDTO) -> Color {
        if annotationIsAuthoritative(annotation) { return .green }
        switch annotation.patternState {
        case "failed", "invalidated": return .red
        case "testing": return .orange
        default: return AppTheme.softGold
        }
    }

    private func gridLines(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                let y = topPadding + CGFloat(index) * ((size.height - topPadding - bottomPadding) / 4)

                Path { path in
                    path.move(to: CGPoint(x: leftPadding, y: y))
                    path.addLine(to: CGPoint(x: size.width - rightPadding, y: y))
                }
                .stroke(AppTheme.cardStroke.opacity(0.35), lineWidth: 0.8)
            }
        }
    }

    private func aiLevelLines(
        yPosition: (Double) -> CGFloat,
        size: CGSize
    ) -> some View {
        ZStack {
            if let resistance = context?.resistanceLevel {
                priceLine(title: "Resistance", value: resistance, y: yPosition(resistance), color: .red, size: size)
            }

            if let support = context?.supportLevel {
                priceLine(title: "Support", value: support, y: yPosition(support), color: .green, size: size)
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
        size: CGSize,
        solid: Bool = false
    ) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: leftPadding, y: y))
                path.addLine(to: CGPoint(x: size.width - rightPadding, y: y))
            }
            .stroke(color.opacity(0.78), style: StrokeStyle(lineWidth: 1, dash: solid ? [] : [5, 5]))

            Text(title.isEmpty ? formatPrice(value) : "\(title) \(formatPrice(value))")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(AppTheme.deepBlack.opacity(0.92))
                .clipShape(Capsule())
                .position(x: max(size.width - rightPadding - 42, 55), y: y - 10)
        }
    }

    private func rightAxisLabels(
        high: Double,
        middle: Double,
        low: Double,
        size: CGSize
    ) -> some View {
        ZStack {
            axisLabel(formatPrice(high), size: size, y: topPadding)
            axisLabel(formatPrice(middle), size: size, y: size.height / 2)
            axisLabel(formatPrice(low), size: size, y: size.height - bottomPadding)
        }
    }

    private func axisLabel(_ text: String, size: CGSize, y: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(AppTheme.secondaryText)
            .position(x: size.width - 28, y: y)
    }

    private func formatPrice(_ value: Double) -> String {
        if abs(value) < 10 {
            return String(format: "%.4f", value)
        }

        if abs(value) < 100 {
            return String(format: "%.2f", value)
        }

        return String(format: "%.0f", value)
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

struct CandleReplayOverlay {
    let levels: [String: Double]
    let markers: [ReplayMarker]
    let side: String
    let select: (ReplayMarker) -> Void
}
