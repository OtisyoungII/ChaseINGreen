import SwiftUI

/// A temporal decision narrative, not a reconstructed market-price chart.
struct RecordedDecisionTimeline: View {
    let variant: ReplayVariant
    let cursor: Date
    let side: String
    @State private var selected: ReplayMarker?
    private var reached: [ReplayMarker] { variant.markers(at: cursor).sorted { $0.at < $1.at } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Recorded actions", systemImage: "clock.arrow.circlepath").font(.headline)
                Spacer()
                Text("\(reached.count) reached").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            if reached.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ready to watch Chase’s recorded decisions").font(.headline)
                    Text("Press Play or Step. Entry, management and exit appear only when their recorded time is reached.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }.padding(.vertical, 8)
            } else {
                ForEach(Array(reached.suffix(3).reversed())) { marker in
                    Button { selected = marker } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: marker.icon).font(.title3).foregroundStyle(marker.action == "EXIT" ? .orange : .cyan)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(marker.action == "ENTRY" ? side.uppercased() + " ENTRY" : marker.action).font(.subheadline.bold())
                                    Spacer()
                                    if let price = marker.price { Text(price.formatted()).font(.caption.monospacedDigit()) }
                                }
                                Text(marker.at, format: .dateTime.month().day().hour().minute().second()).font(.caption).foregroundStyle(.secondary)
                                Text(marker.reason).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                            }
                        }.padding(10).background(Color.secondary.opacity(0.08),in:RoundedRectangle(cornerRadius:10))
                    }.buttonStyle(.plain).accessibilityLabel(marker.action + ", " + marker.reason)
                }
                if reached.count > 3 { Text("Latest three reached actions shown. Earlier actions remain in Recorded transitions below or can be inspected by stepping back.").font(.caption2).foregroundStyle(.secondary) }
            }
            Text("Recorded observations only · no inferred prices between samples").font(.caption2).foregroundStyle(.secondary)
        }
        .onChange(of: cursor) { _, _ in selected = nil }
        .sheet(item: $selected) { marker in
            NavigationStack {
                let frame = variant.frame(at: marker.at)
                List {
                    Text(marker.action).font(.title2.bold())
                    Text(marker.at, format: .dateTime.year().month().day().hour().minute().second())
                    LabeledContent("Recorded price",value:marker.price.map { $0.formatted() } ?? "Unavailable")
                    Text(marker.reason)
                    LabeledContent("Thesis",value:frame?.details["thesis"] ?? "Unavailable")
                    LabeledContent("Confidence",value:frame?.details["confidence"] ?? "Unavailable")
                    ForEach(["entry","mark","quantity","stop","target","mfe","mae","giveback","realized_pnl"],id: \.self) { key in
                        LabeledContent(key.replacingOccurrences(of:"_",with:" ").capitalized,value:frame?.numbers[key].map { $0.formatted() } ?? "Unavailable")
                    }
                    Text(variant.badge).font(.caption)
                }.navigationTitle("Recorded decision").toolbar { Button("Done") { selected = nil } }
            }.presentationDetents([.medium,.large])
        }
    }
}
