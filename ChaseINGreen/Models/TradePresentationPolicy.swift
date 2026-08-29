import Foundation

struct KnownPnlSummary: Equatable {
    let knownTotal: Double?
    let unavailableCount: Int
}

enum TradePresentationPolicy {
    static func summarizePnl(_ values: [Double?]) -> KnownPnlSummary {
        let known = values.compactMap { $0 }
        return KnownPnlSummary(
            knownTotal: known.isEmpty ? nil : known.reduce(0, +),
            unavailableCount: values.count - known.count
        )
    }

    static func uniqueReasoning(_ values: [String?]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            guard let value else { return nil }
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty,
                  seen.insert(clean.lowercased()).inserted else { return nil }
            return clean
        }
    }

    static func compactMoney(_ value: Double) -> String {
        let magnitude = abs(value)
        let sign = value >= 0 ? "+$" : "-$"
        if magnitude >= 1_000_000 {
            return String(format: "%@%.2fM", sign, magnitude / 1_000_000)
        }
        if magnitude >= 1_000 {
            return String(format: "%@%.2fK", sign, magnitude / 1_000)
        }
        return String(format: "%@%.2f", sign, magnitude)
    }
}
