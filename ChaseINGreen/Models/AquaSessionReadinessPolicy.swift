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

        if ["reconnect_required", "disconnected"].contains(normalizedStatus) {
            return false
        }

        if authenticated == true {
            return true
        }

        let hasRecoverableSavedSession = connected == true
            && savedRosterAvailable == true
            && refreshExpired != true

        if hasRecoverableSavedSession {
            return true
        }

        if authenticated == false {
            return false
        }

        if connected == true {
            return true
        }

        return [
            "ready",
            "connected",
            "active",
            "healthy",
            "synced",
            "login_ready",
            "refresh_required"
        ].contains(normalizedStatus)
            || (connected == nil && authenticated == nil)
    }
}
