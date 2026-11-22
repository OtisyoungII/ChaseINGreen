import SwiftUI

/// Uses Chase's existing candle workbench. No provider requests or execution controls.
struct EpisodeTradingChart: View {
    let replay: EpisodeReplay
    let variant: ReplayVariant
    let cursor: Date
    let playing: Bool
    @State private var viewport = ChartViewport()
    @State private var style = CandleChartStyle.standard
    @State private var bands = true
    @State private var emas: Set<Int> = []
    @State private var showMACD = true
    @State private var showRSI = false
    @State private var indicators = ReplayIndicatorSeries()
    @State private var selected: ReplayMarker?
    private var candles: [MarketCandle] { ReplayChartEvidence.candles(replay, at: cursor) }
    private var frame: ReplayFrame? { variant.frame(at: cursor) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if replay.candles.isEmpty {
                ContentUnavailableView("OHLC evidence not retained", systemImage: "chart.xyaxis.line",
                    description: Text("This episode has recorded decisions, but no reviewed candle window. A market chart, indicators and post-exit price playback cannot be reconstructed from isolated samples."))
                    .frame(minHeight: 250)
                Text("Decision-only replay remains available below. No synthetic candles or price plots are substituted.").font(.caption).foregroundStyle(.secondary)
            } else {
                Picker("Chart mode", selection: $style) {
                    ForEach(CandleChartStyle.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
                DisclosureGroup("Overlays & indicators") {
                    Toggle("Bollinger · 20 / 2σ", isOn: $bands)
                    ForEach([12,26,50,200], id: \.self) { period in
                        Toggle("EMA \(period)", isOn: Binding(get: { emas.contains(period) },set: { if $0 { emas.insert(period) } else { emas.remove(period) } }))
                    }
                    Toggle("MACD · 12 / 26 / 9", isOn: $showMACD)
                    Toggle("RSI · 14", isOn: $showRSI)
                }.font(.caption)
                if candles.isEmpty {
                    ContentUnavailableView("Before first retained candle", systemImage: "clock", description: Text("Press Play to reveal evidence as it becomes available.")).frame(height: 290)
                } else {
                    CandleChartView(candles: candles, currentPrice: frame?.numbers["mark"] ?? candles.last?.close,
                        showAILevels: false, context: nil, chartStyle: style,
                        enabledIndicators: bands ? [.bollinger] : [], interactiveWorkbench: !playing,
                        chartHeight: 330, viewport: $viewport,
                        replayOverlay: CandleReplayOverlay(levels: ReplayChartEvidence.activeLevels(frame),
                            markers: variant.markers(at: cursor), side: replay.side, select: { selected = $0 }), emaPeriods: emas)
                        .environment(\.colorScheme, .dark)
                    if showMACD {
                        ReplayIndicatorPanel(title: "MACD 12 / 26 / 9", candles: candles, viewport: viewport,
                            first: indicators.macd, second: indicators.signal, histogram: indicators.histogram, rsi: false)
                    }
                    if showRSI {
                        ReplayIndicatorPanel(title: "RSI 14", candles: candles, viewport: viewport,
                            first: indicators.rsi, second: [], histogram: [], rsi: true)
                    }
                    HStack {
                        Button("Zoom in") { viewport.zoom(scale: 1.5, loadedCount: candles.count) }
                        Button("Zoom out") { viewport.zoom(scale: 0.67, loadedCount: candles.count) }
                        Button("Latest") { viewport.reset() }
                    }.font(.caption).disabled(playing)
                    Text(playing ? "Pause to inspect markers, pan or pinch to zoom." : "Drag to pan · pinch to zoom · tap a trade marker")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text("\(candles.count) closed bars revealed. Bands need 20; EMA needs its period; MACD needs 35; RSI needs 15. Missing warmup stays blank. Indicators use original OHLC, including in Heikin-Ashi mode.")
                        .font(.caption2).foregroundStyle(.secondary)
                    if let quantity = frame?.numbers["quantity"] { Text("Retained position size: \(quantity.formatted())").font(.caption.monospacedDigit()) }
                }
            }
        }
        .task(id: candles.count) { indicators = ReplayChartEvidence.indicators(candles) }
        .onChange(of: cursor) { old, new in if new < old { viewport.reset(); selected = nil } }
        .sheet(item: $selected) { marker in
            let state = variant.frame(at: marker.at)
            NavigationStack {
                List {
                    Text(marker.action).font(.title2.bold())
                    Text(marker.at, format: .dateTime.year().month().day().hour().minute().second())
                    LabeledContent("Price", value: marker.price.map { $0.formatted() } ?? "Unavailable")
                    LabeledContent("Thesis", value: state?.details["thesis"] ?? "Unavailable")
                    Text(marker.reason)
                    LabeledContent("Confidence", value: state?.details["confidence"] ?? "Unavailable")
                    Text(variant.badge).font(.caption)
                }.navigationTitle("Recorded decision").toolbar { Button("Done") { selected = nil } }
            }.presentationDetents([.medium,.large])
        }
    }
}

private struct ReplayIndicatorPanel: View {
    let title: String
    let candles: [MarketCandle]
    let viewport: ChartViewport
    let first, second, histogram: [Double?]
    let rsi: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.bold())
            Canvas { context, size in
                let range = viewport.range(loadedCount: candles.count)
                let values = [first,second,histogram].flatMap { series in range.compactMap { series.indices.contains($0) ? series[$0] : nil } }
                let lower = rsi ? 0 : min(values.min() ?? -1, 0)
                let upper = rsi ? 100 : max(values.max() ?? 1, 0)
                let padding = rsi ? 0 : max((upper-lower)*0.1,0.00001)
                func x(_ i: Int) -> Double { ChartGeometry.x(index: i-range.lowerBound,count: range.count,left: 12,width: max(size.width-70,1)) }
                func y(_ n: Double) -> Double { ChartGeometry.y(price: n,minimum: lower-padding,maximum: upper+padding,top: 10,height: max(size.height-20,1)) }
                for level in rsi ? [30.0,50,70] : [0.0] {
                    var path=Path();path.move(to: CGPoint(x:12,y:y(level)));path.addLine(to: CGPoint(x:size.width-58,y:y(level)))
                    context.stroke(path,with:.color(.secondary.opacity(0.4)),style:StrokeStyle(lineWidth:0.7,dash:[3,3]))
                    context.draw(Text(level.formatted()).font(.system(size:9)).foregroundColor(.secondary),at:CGPoint(x:size.width-28,y:y(level)))
                }
                for i in range where histogram.indices.contains(i) {
                    if let n=histogram[i] {
                        let rect=CGRect(x:x(i)-2,y:min(y(n),y(0)),width:4,height:max(abs(y(n)-y(0)),0.5))
                        context.fill(Path(rect),with:.color(n>=0 ? .green.opacity(0.65) : .red.opacity(0.65)))
                    }
                }
                for (series,color) in [(first,Color.cyan),(second,Color.orange)] {
                    var path=Path();var started=false
                    for i in range {
                        guard series.indices.contains(i),let n=series[i] else { started=false;continue }
                        let p=CGPoint(x:x(i),y:y(n));if started { path.addLine(to:p) } else { path.move(to:p);started=true }
                    }
                    context.stroke(path,with:.color(color),lineWidth:1.4)
                }
            }.frame(height:110).background(Color.secondary.opacity(0.06),in:RoundedRectangle(cornerRadius:8))
            if !first.contains(where: { $0 != nil }) { Text("Insufficient retained warmup").font(.caption2).foregroundStyle(.secondary) }
        }
    }
}
