import Foundation

actor AquaHealthRequestCoalescer<Value: Sendable> {
    enum Source: String, Sendable {
        case network
        case joinedInflight = "joined-inflight"
    }

    private var inFlight: [String: Task<Value, Error>] = [:]

    func value(
        for key: String,
        loader: @escaping @Sendable () async throws -> Value
    ) async throws -> (value: Value, source: Source) {
        if let existing = inFlight[key] {
            return (try await existing.value, .joinedInflight)
        }

        let task = Task { try await loader() }
        inFlight[key] = task

        do {
            let value = try await task.value
            inFlight.removeValue(forKey: key)
            return (value, .network)
        } catch {
            inFlight.removeValue(forKey: key)
            throw error
        }
    }
}
