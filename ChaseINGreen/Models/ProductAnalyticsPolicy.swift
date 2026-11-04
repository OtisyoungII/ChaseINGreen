import Foundation

/// Coarse, non-identifying client metadata. Never infers an exact hardware model.
public enum ProductAnalyticsPolicy {
    public static func metadata(platform: String, deviceClass: String, osVersion: String,
                                appVersion: String?, build: String?, language: String?) -> [String: String] {
        func version(_ value: String?) -> String {
            guard let value, !value.isEmpty, value.count <= 24,
                  value.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }) else { return "not_collected" }
            return value
        }
        let known = ["ios", "ipados", "macos", "web"].contains(platform) ? platform : "unknown"
        return ["platform": known,
                "device_class": ["phone", "tablet", "desktop"].contains(deviceClass) ? deviceClass : "unknown",
                "os_family": known == "web" ? "unknown" : known,
                "os_version": version(osVersion), "app_version": version(appVersion), "build": version(build),
                "client_kind": "native", "language": ["en", "es"].contains(language ?? "") ? language! : "other"]
    }
}
