import Foundation

enum AquaSessionReadinessPolicy {
    static func isReady(
        hasConnection: Bool,
        connected: Bool?,
        authenticated: Bool?,
        savedRosterAvailable: Bool?,
        status: String?,
        refreshExpired: Bool?
    ) -> Bool {
        guard hasConnection else { return false }

        let normalizedStatus = (status ?? "")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if ["refresh_required", "reconnect_required", "disconnected", "error"].contains(normalizedStatus) {
            return false
        }

        if connected == true && authenticated == true {
            return [
            "ready",
            "connected",
            "active",
            "healthy",
            "synced",
            "login_ready"
            ].contains(normalizedStatus) || normalizedStatus.isEmpty
        }

        return false
    }
}
