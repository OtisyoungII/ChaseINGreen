import Foundation

/// Manual identity never derives from a balance or account size.
enum ManualAccountIdentityPolicy {
    static func initialBroker<Value>(selected: Value, editing: Value?) -> Value {
        editing ?? selected
    }

    static func lastFour(_ value: String?) -> String? {
        let safe = (value ?? "").unicodeScalars.filter {
            (48...57).contains($0.value) || (65...90).contains($0.value) || (97...122).contains($0.value)
        }.map(String.init).joined().uppercased()
        return safe.count >= 4 ? String(safe.suffix(4)) : nil
    }

    static func showsConnectionDiagnostics(sourceMode: String?, connectionMode: String?) -> Bool {
        sourceMode?.lowercased() != "manual" && connectionMode?.lowercased() != "manual"
    }

    static func verifyReadBack(savedID: UUID, listedIDs: [UUID]) throws {
        guard listedIDs.contains(savedID) else { throw ReadBackError.missing }
    }

    enum ReadBackError: LocalizedError {
        case missing
        var errorDescription: String? { "The saved account was not returned by Saved Accounts." }
    }
}

enum ManualAccountSaveState: Equatable {
    case unsaved
    case savedAwaitingRefresh(UUID)
    case verified(UUID)

    var savedID: UUID? {
        switch self {
        case .unsaved: nil
        case .savedAwaitingRefresh(let id), .verified(let id): id
        }
    }

    var failureMessage: String {
        savedID == nil ? "Save failed. Please retry."
            : "Account saved, but refresh could not be verified. Retry refresh; do not create another account."
    }
}
