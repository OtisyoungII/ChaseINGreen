import Foundation

/// Production logs accept a bounded operational vocabulary, never free-form errors/payloads.
public enum LogPrivacyPolicy {
    public static func sanitize(_ text: String) -> String {
        let enums: Set<String> = ["kraken", "ibkr", "aqua", "manual", "yahoo", "unknown", "fresh", "stale",
            "unavailable", "true", "false", "start", "complete", "failed", "active", "background", "inactive",
            "GET", "POST", "PATCH", "DELETE", "network", "cache", "cancelled"]
        let enumKeys: Set<String> = ["provider", "lifecycle", "status", "action", "success", "complete", "scene", "source", "method"]
        let numericKeys: Set<String> = ["count", "included", "excluded", "priced", "unpriced", "elapsedMs", "ms", "statusCode", "residentMB", "memoryWarnings"]
        // Never parse arbitrary error text as operational fields.
        let prefix = text.components(separatedBy: "error=").first ?? ""
        let events: Set<String> = ["Network", "AuthState", "AuthRefresh", "AuthSession", "RefreshPerf", "RefreshOwner",
            "PositionPresentation", "Portfolio", "BrokerAccounts", "KrakenTrader", "AquaPositionSync",
            "IBKREnrollment", "ReleaseHealth", "Navigation", "LedgerTruth"]
        let label = text.first == "[" ? String(text.dropFirst().prefix(while: { $0 != "]" })) : ""
        var output = [events.contains(label) ? "[\(label)]" : "[Runtime]"]
        for part in prefix.split(separator: " ") {
            let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
            guard pair.count == 2 else { continue }
            let key = pair[0], value = pair[1]
            if enumKeys.contains(key), enums.contains(value) { output.append("\(key)=\(value)") }
            else if numericKeys.contains(key), let number = Double(value), number.isFinite {
                output.append("\(key)=\(number)")
            } else if key == "requestId", value.count == 8, value.allSatisfy(\.isHexDigit) {
                output.append("requestId=\(value)")
            } else if ["owner_alias", "account_alias"].contains(key), value.count == 24,
                      value.allSatisfy(\.isHexDigit) {
                output.append("\(key)=\(value)")
            }
        }
        return output.joined(separator: " ")
    }
}
