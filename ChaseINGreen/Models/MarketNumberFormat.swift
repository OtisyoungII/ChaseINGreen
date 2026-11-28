import Foundation

/// Presentation only. Never use these strings as inputs to valuation arithmetic.
enum MarketNumberFormat {
    static func quantity(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "Unavailable" }
        return number(value, minimumFractionDigits: 0)
    }

    static func price(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "Unavailable" }
        return number(value, minimumFractionDigits: abs(value) >= 1 || value == 0 ? 2 : 0)
    }

    static func money(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "Unavailable" }
        if value != 0 && abs(value) < 0.01 { return value < 0 ? "−<$0.01" : "<$0.01" }
        return (value < 0 ? "−$" : "$") + number(abs(value), minimumFractionDigits: 2, currency: true)
    }

    static func currency(_ value: Double?, code: String?) -> String {
        guard let value, value.isFinite else { return "—" }
        guard let code, !code.isEmpty else { return price(value) + " (currency unknown)" }
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        if value != 0 && abs(value) < pow(10, -Double(formatter.maximumFractionDigits)) {
            return price(value) + " " + code
        }
        return formatter.string(from: NSNumber(value: value)) ?? (price(value) + " " + code)
    }

    static func timestamp(_ raw: String?) -> String {
        guard let raw else { return "Time unavailable" }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return (parser.date(from: raw) ?? ISO8601DateFormatter().date(from: raw))?
            .formatted(date: .abbreviated, time: .standard) ?? "Time unavailable"
    }

    private static func number(_ value: Double, minimumFractionDigits: Int, currency: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = minimumFractionDigits
        // Preserve useful quantity precision; tiny prices need significant digits,
        // not a fixed decimal-place cap that silently turns a holding into zero.
        formatter.maximumFractionDigits = currency ? 2 : max(8, min(340, Int(max(0, -log10(max(abs(value), Double.leastNonzeroMagnitude)))) + 6))
        let result = formatter.string(from: NSNumber(value: value)) ?? String(value)
        if value != 0 && Double(result.replacingOccurrences(of: ",", with: "")) == 0 {
            return String(format: "%.6g", value)
        }
        return result
    }
}
