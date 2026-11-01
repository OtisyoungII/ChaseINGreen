import Foundation

enum CandleCloseCountdown {
    static func duration(for timeframe: String) -> TimeInterval? {
        guard case .time(let seconds) = MarketBarInterval.parse(timeframe).basis else { return nil }
        return seconds
    }

    static func displayName(for timeframe: String) -> String {
        MarketBarInterval.parse(timeframe).displayName
    }

    static func closeDate(
        timeframe: String,
        now: Date,
        authoritativeClose: Date?,
        usesContinuousUTCBoundaries: Bool
    ) -> Date? {
        if let authoritativeClose, authoritativeClose >= now {
            return authoritativeClose
        }
        guard usesContinuousUTCBoundaries,
              let duration = duration(for: timeframe) else {
            return nil
        }
        let elapsed = now.timeIntervalSince1970
        let boundaryIndex = floor(elapsed / duration) + 1
        return Date(timeIntervalSince1970: boundaryIndex * duration)
    }

    static func remaining(until close: Date, now: Date) -> TimeInterval {
        max(0, ceil(close.timeIntervalSince(now)))
    }

    static func formatted(_ remaining: TimeInterval) -> String {
        let total = max(0, Int(ceil(remaining)))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        if total >= 3_600 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func parseISO8601(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let normalized = value.replacingOccurrences(of: " ", with: "T")
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = fractional.date(from: normalized) {
            return parsed
        }
        return ISO8601DateFormatter().date(from: normalized)
    }
}
