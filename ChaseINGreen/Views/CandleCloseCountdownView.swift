import SwiftUI

struct CandleCloseCountdownView: View {
    let timeframe: String
    let symbol: String
    var authoritativeClose: Date? = nil
    var includesTimeframe = true

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if scenePhase == .active {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    label(at: context.date)
                }
            } else {
                label(at: Date())
            }
        }
        .accessibilityLabel(accessibilityText(at: Date()))
    }

    @ViewBuilder
    private func label(at now: Date) -> some View {
        let text = countdown(at: now)
        if includesTimeframe {
            Text("\(CandleCloseCountdown.displayName(for: timeframe)) · \(text)")
        } else {
            Text(text)
        }
    }

    private func countdown(at now: Date) -> String {
        let interval = MarketBarInterval.parse(timeframe)
        if case .ticks = interval.basis {
            return interval.activityDescription ?? "Activity-based close"
        }
        guard let close = CandleCloseCountdown.closeDate(
            timeframe: timeframe,
            now: now,
            authoritativeClose: authoritativeClose,
            usesContinuousUTCBoundaries: isContinuousCrypto
        ) else {
            return "Close time unavailable"
        }
        return CandleCloseCountdown.formatted(
            CandleCloseCountdown.remaining(until: close, now: now)
        )
    }

    private var isContinuousCrypto: Bool {
        WatchSymbol.marketIdentity(symbol: symbol).assetClass == "Crypto"
    }

    private func accessibilityText(at now: Date) -> String {
        "\(CandleCloseCountdown.displayName(for: timeframe)) candle closes in \(countdown(at: now))"
    }
}
