import Foundation
import Combine

/// Ephemeral app-session draft. Deliberately not Codable and never persisted.
@MainActor
final class KrakenConnectionDraft: ObservableObject {
    static let shared = KrakenConnectionDraft()
    static let lifetime: TimeInterval = 15 * 60
    enum Field { case name, classification, key, secret }
    @Published private(set) var name = ""
    @Published private(set) var classification = "personal"
    @Published private(set) var key = ""
    @Published private(set) var secret = ""
    @Published private(set) var revision = UUID()
    @Published private(set) var expired = false
    private var lastEdit: Date?
    private var expiryTask: Task<Void, Never>?

    var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 150
        && ["personal", "business"].contains(classification)
        && !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func update(_ field: Field, _ value: String, now: Date = Date()) {
        expireIfNeeded(now: now)
        switch field {
        case .name: name = value
        case .classification: classification = value
        case .key: key = value
        case .secret: secret = value
        }
        expired = false
        lastEdit = now
        expiryTask?.cancel()
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.lifetime))
            guard !Task.isCancelled else { return }
            self?.expireIfNeeded()
        }
    }

    func expireIfNeeded(now: Date = Date()) {
        if let lastEdit, now.timeIntervalSince(lastEdit) >= Self.lifetime {
            clear()
            expired = true
        }
    }

    func clear() {
        expiryTask?.cancel(); expiryTask = nil
        name = ""; classification = "personal"; key = ""; secret = ""
        lastEdit = nil; revision = UUID(); expired = false
    }

    /// A late response may not clear a newer session's draft.
    func registrationSucceeded(revision expected: UUID) {
        if revision == expected { clear() }
    }
}
