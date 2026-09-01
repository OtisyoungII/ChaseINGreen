import Foundation

enum AquaProtectionScope: String, CaseIterable, Identifiable {
    case position
    case symbol
    case portfolio

    var id: String { rawValue }
}

struct AquaProtectionTargetIdentity: Hashable {
    let provider: String
    let connectionID: String?
    let accountID: String
    let positionID: String

    var canonicalKey: String {
        [provider, connectionID ?? "default", accountID, positionID]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: "|")
    }
}

struct AquaProtectionStopInput {
    let currentPrice: Double?
    let openPrice: Double?
    let side: String?
}

enum AquaProtectionBatchPolicy {
    static func isSameBrokerSymbol(
        _ candidate: String,
        as selected: String
    ) -> Bool {
        candidate.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            == selected.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static func runSerial<T, Result>(
        captured targets: [T],
        attempt: (T) async -> Result
    ) async -> [Result] {
        var results: [Result] = []
        results.reserveCapacity(targets.count)
        for target in targets {
            results.append(await attempt(target))
        }
        return results
    }

    static func stopPrice(
        for input: AquaProtectionStopInput,
        percent: Double
    ) -> Double? {
        guard percent > 0,
              percent.isFinite,
              let referencePrice = input.currentPrice ?? input.openPrice,
              referencePrice > 0,
              referencePrice.isFinite else {
            return nil
        }

        let side = (input.side ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let isLong: Bool
        if side.contains("buy") || side.contains("long") {
            isLong = true
        } else if side.contains("sell") || side.contains("short") {
            isLong = false
        } else {
            return nil
        }

        let multiplier = 1 + (isLong ? -1 : 1) * percent / 100
        let result = referencePrice * multiplier
        return result > 0 && result.isFinite ? result : nil
    }

    static func uniqueIndices(
        for identities: [AquaProtectionTargetIdentity]
    ) -> [Int] {
        var seen = Set<String>()
        return identities.indices.filter {
            seen.insert(identities[$0].canonicalKey).inserted
        }
    }
}

enum AquaProtectionResultState: String {
    case protected
    case failed
    case verificationPending
}

struct AquaProtectionBatchSummary: Equatable {
    let total: Int
    let protected: Int
    let failed: Int
    let verificationPending: Int

    init(states: [AquaProtectionResultState]) {
        total = states.count
        protected = states.filter { $0 == .protected }.count
        failed = states.filter { $0 == .failed }.count
        verificationPending = states.filter {
            $0 == .verificationPending
        }.count
    }
}
