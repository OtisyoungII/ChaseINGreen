import Foundation

enum ProviderRefreshScope: Equatable {
    case globalPortfolio
    case provider(String)
    case presentation

    func allows(_ provider: String) -> Bool {
        switch self {
        case .globalPortfolio:
            return true
        case .provider(let selected):
            return ProviderRefreshPolicy.identity(selected)
                == ProviderRefreshPolicy.identity(provider)
        case .presentation:
            return false
        }
    }
}

enum ProviderRefreshDecision: Equatable {
    case start
    case coalesced
    case unrelatedProvider
    case presentationOnly
    case fresh
    case failureCooldown
}

enum ProviderRefreshPolicy {
    static func decision(
        provider: String,
        scope: ProviderRefreshScope,
        isInFlight: Bool,
        lastSuccess: Date?,
        lastFailure: Date?,
        now: Date = Date(),
        maximumAge: TimeInterval,
        failureCooldown: TimeInterval,
        force: Bool
    ) -> ProviderRefreshDecision {
        if case .presentation = scope { return .presentationOnly }
        guard scope.allows(provider) else { return .unrelatedProvider }
        if isInFlight { return .coalesced }
        if force { return .start }
        if let lastSuccess,
           now.timeIntervalSince(lastSuccess) < maximumAge {
            return .fresh
        }
        if let lastFailure,
           now.timeIntervalSince(lastFailure) < failureCooldown {
            return .failureCooldown
        }
        return .start
    }

    static func identity(_ value: String) -> String {
        let compact = value.lowercased().filter(\.isLetter)
        if compact.contains("aqua") || compact.contains("matchtrader") {
            return "aqua"
        }
        if compact.contains("kraken") { return "kraken" }
        if compact == "ibkr" || compact.contains("interactivebrokers") {
            return "ibkr"
        }
        return compact
    }
}

/// Process-local, owner-scoped retained snapshots. Cache receipt never renews
/// provider evidence timestamps. Failed refreshes preserve the last snapshot.
@MainActor
final class RetainedSnapshotStore<Value> {
    private struct Entry { let value: Value; let receivedAt: Date }
    @MainActor private final class Snapshot {
        let value: Value
        init(_ value: Value) { self.value = value }
    }
    private struct Flight { let id: UUID; let task: Task<Snapshot, Error> }
    private var entries: [String: Entry] = [:]
    private var flights: [String: Flight] = [:]
    private var generation = UUID()

    func cached(_ key: String) -> Value? { entries[key]?.value }

    func clear() {
        generation = UUID()
        flights.values.forEach { $0.task.cancel() }
        flights.removeAll()
        entries.removeAll()
    }

    func load(_ key: String, force: Bool = false, maxAge: TimeInterval = 15,
              now: Date = Date(), fetch: @escaping @MainActor () async throws -> Value) async throws -> Value {
        let epoch = generation
        if let running = flights[key] {
            let value = try await running.task.value.value
            guard epoch == generation else { throw CancellationError() }
            return value
        }
        if !force, let entry = entries[key], now.timeIntervalSince(entry.receivedAt) < maxAge {
            return entry.value
        }
        let id = UUID()
        let task = Task { Snapshot(try await fetch()) }
        flights[key] = Flight(id: id, task: task)
        do {
            let value = try await task.value.value
            try Task.checkCancellation()
            guard epoch == generation else { throw CancellationError() }
            if flights[key]?.id == id { flights[key] = nil }
            entries[key] = Entry(value: value, receivedAt: Date())
            if entries.count > 8, let oldest = entries.min(by: { $0.value.receivedAt < $1.value.receivedAt })?.key {
                entries[oldest] = nil
            }
            return value
        } catch {
            guard epoch == generation else { throw CancellationError() }
            if flights[key]?.id == id { flights[key] = nil }
            if !(error is CancellationError), let retained = entries[key] { return retained.value }
            throw error
        }
    }
}
