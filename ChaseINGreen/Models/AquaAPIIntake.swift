import Foundation

/// Sanitized server status only. Credentials are never part of this model.
struct AquaAPIIntake: Decodable, Identifiable {
    var id: UUID { intake_id }
    struct Capabilities: Decodable {
        let read_resources: [String]?
        let account_access_right: String?
        let last_completed_stage: String?
    }
    let capabilities: Capabilities
    let intake_id: UUID
    let state: String
    let failure: String?
    let native_account_id: String?
    let pending_until: String?
    let updated_at: String
    let credential_retained: Bool
    let observation_active: Bool
    let trade_authorized: Bool

    var canValidate: Bool {
        credential_retained && ["RECEIVED", "PROVIDER_UNAVAILABLE", "UNKNOWN_FAILURE", "PERSISTENCE_FAILED", "RECOVERY_REQUIRED"].contains(state)
    }
    var explanation: String {
        switch state {
        case "RECEIVED": return "Encrypted key saved. Provider validation has not started."
        case "VALIDATING": return "Validation admitted. Refresh status; do not submit another key."
        case "BOUND": return "Exact account and required reads verified. Observation activation is a separate step."
        case "RECOVERY_REQUIRED": return "Validation was interrupted. The encrypted key is retained until its retention deadline. Validate again only when ready."
        case "EXPIRED": return "Pending retention expired. The pending encrypted key was removed."
        case "DISCONNECTED": return "This intake is disconnected. Historical evidence is preserved."
        default: return "Validation did not complete. See the safe failure category."
        }
    }
}
