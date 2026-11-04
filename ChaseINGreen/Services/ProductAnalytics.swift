import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ProductAnalytics {
    static let shared = ProductAnalytics()
    private var recent: [String: Date] = [:]
    private var pending = 0

    static func metadata() -> [String: String] {
        #if os(iOS)
        let tablet = UIDevice.current.userInterfaceIdiom == .pad
        let platform = ProcessInfo.processInfo.isiOSAppOnMac ? "macos" : (tablet ? "ipados" : "ios")
        let device = ProcessInfo.processInfo.isiOSAppOnMac ? "desktop" : (tablet ? "tablet" : "phone")
        #else
        let platform = "macos"
        let device = "desktop"
        #endif
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return ProductAnalyticsPolicy.metadata(platform: platform, deviceClass: device,
            osVersion: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
            language: Locale.current.language.languageCode?.identifier)
    }

    func record(_ name: String, accessToken: String) {
        guard pending < 4, !accessToken.isEmpty else { return }
        let now = Date()
        if let last = recent[name], now.timeIntervalSince(last) < 30 { return }
        recent[name] = now
        pending += 1
        let metadata = Self.metadata()
        let payload: [String: Any] = ["event_id": UUID().uuidString, "name": name, "metadata": metadata]
        Task {
            defer { pending -= 1 }
            guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
            _ = try? await APIService.shared.sendRequest(path: "/admin/dashboard/events", method: "POST",
                accessToken: accessToken, body: body, label: "productEvent", timeoutInterval: 5, allowsAuthRefresh: false)
        }
    }
}

extension View {
    func productAnalytics(_ name: String, accessToken: String) -> some View {
        onAppear { ProductAnalytics.shared.record(name, accessToken: accessToken) }
    }
}
