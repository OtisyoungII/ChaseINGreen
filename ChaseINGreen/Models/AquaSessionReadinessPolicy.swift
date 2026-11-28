import Foundation

enum AquaSessionReadinessPolicy {
    static func displayStatus(authenticated: Bool?, tokenExpired: Bool?, expiresAt: String?, now: Date = Date()) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expiry = expiresAt.flatMap { parser.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) }
        if tokenExpired == true || expiry.map({ $0 <= now }) == true { return "Session expired · refresh required" }
        guard authenticated == true, let expiry, expiry > now else { return "Current session verification unavailable" }
        return "Authenticated session"
    }

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
