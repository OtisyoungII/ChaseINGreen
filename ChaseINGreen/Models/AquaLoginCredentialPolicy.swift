import Foundation

enum AquaLoginCredentialPolicy {
    static func username(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func password(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }
}
