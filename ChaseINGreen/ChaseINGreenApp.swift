//
//  ChaseINGreenApp.swift
//  ChaseINGreen
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import UserNotifications

struct TradeNotificationRoute: Hashable, Identifiable {
    let id = UUID()
    let symbol: String
    let broker: String
    let accountId: String?
    let positionId: String?
    let side: String?
    let decision: String?
}

@MainActor
final class TradeAlertNavigationStore: ObservableObject {
    static let shared = TradeAlertNavigationStore()

    @Published var pendingRoute: TradeNotificationRoute?
    @Published var activeRoute: TradeNotificationRoute?

    func receive(_ userInfo: [AnyHashable: Any]) {
        guard let symbol = userInfo["symbol"] as? String,
              !symbol.isEmpty else {
            return
        }

        let route = TradeNotificationRoute(
            symbol: symbol,
            broker: userInfo["broker"] as? String
                ?? "Aqua Funding",
            accountId: userInfo["account_id"] as? String,
            positionId: userInfo["position_id"] as? String,
            side: userInfo["side"] as? String,
            decision: userInfo["decision"] as? String
        )
        activeRoute = route
        pendingRoute = route
    }
}

#if canImport(UIKit)
final class ChaseINGreenAppDelegate: NSObject,
    UIApplicationDelegate,
    UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [
            UIApplication.LaunchOptionsKey: Any
        ]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { _, _ in }

        let reviewProtection = UNNotificationAction(
            identifier: "REVIEW_TRADE_PROTECTION",
            title: "Review Protection",
            options: [.foreground]
        )
        let notNow = UNNotificationAction(
            identifier: "NOT_NOW",
            title: "Not Now",
            options: []
        )
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: "AQUA_TRADE_ALERT",
                actions: [reviewProtection, notNow],
                intentIdentifiers: [],
                options: []
            )
        ])
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (
            UNNotificationPresentationOptions
        ) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer {
            completionHandler()
        }

        guard response.actionIdentifier != "NOT_NOW" else {
            return
        }

        let userInfo = response.notification.request.content.userInfo

        Task { @MainActor in
            TradeAlertNavigationStore.shared.receive(userInfo)
        }
    }
}
#endif

#if canImport(AppKit) && !canImport(UIKit)
final class ChaseINGreenMacAppDelegate: NSObject,
    NSApplicationDelegate,
    UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { _, _ in }

        let reviewProtection = UNNotificationAction(
            identifier: "REVIEW_TRADE_PROTECTION",
            title: "Review Protection",
            options: [.foreground]
        )
        let notNow = UNNotificationAction(
            identifier: "NOT_NOW",
            title: "Not Now",
            options: []
        )
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: "AQUA_TRADE_ALERT",
                actions: [reviewProtection, notNow],
                intentIdentifiers: [],
                options: []
            )
        ])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (
            UNNotificationPresentationOptions
        ) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer {
            completionHandler()
        }

        guard response.actionIdentifier != "NOT_NOW" else {
            return
        }

        let userInfo = response.notification.request.content.userInfo

        Task { @MainActor in
            TradeAlertNavigationStore.shared.receive(userInfo)
        }
    }
}
#endif

@MainActor
enum ChaseTradeNotifications {
    private struct PendingAlert {
        let identifier: String
        let symbol: String
        let title: String
        let body: String
        let critical: Bool
        let userInfo: [String: String]
        let createdAt: Date
    }

    private static let defaults = UserDefaults.standard
    private static let fingerprintPrefix = "cig.alert.fingerprint."
    private static let deliveredAtPrefix = "cig.alert.delivered."
    private static var pendingBatch: [PendingAlert] = []
    private static let batchWindow: TimeInterval = 20
    private static let individualDelay: TimeInterval = 22

    static func deliver(
        key: String,
        fingerprint: String,
        title: String,
        body: String,
        critical: Bool = false,
        cooldown: TimeInterval = 10 * 60,
        routeUserInfo: [String: String] = [:]
    ) {
        let fingerprintKey = fingerprintPrefix + key
        let deliveredAtKey = deliveredAtPrefix + key
        let previousDate = defaults.object(
            forKey: deliveredAtKey
        ) as? Date

        let effectiveCooldown = critical
            ? min(cooldown, 2 * 60)
            : cooldown

        if let previousDate,
           Date().timeIntervalSince(previousDate) < effectiveCooldown {
            return
        }

        defaults.set(fingerprint, forKey: fingerprintKey)
        defaults.set(Date(), forKey: deliveredAtKey)

        let now = Date()
        pendingBatch.removeAll {
            now.timeIntervalSince($0.createdAt) > batchWindow
        }

        let identifier = "\(key).\(fingerprint).\(UUID().uuidString)"
        let symbol = routeUserInfo["symbol"] ?? title
        let pending = PendingAlert(
            identifier: identifier,
            symbol: symbol,
            title: title,
            body: body,
            critical: critical,
            userInfo: routeUserInfo,
            createdAt: now
        )
        pendingBatch.append(pending)

        if pendingBatch.count >= 3 {
            deliverBatchSummary()
            return
        }

        let content = notificationContent(
            title: title,
            body: body,
            userInfo: routeUserInfo,
            alertKey: key,
            fingerprint: fingerprint
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: individualDelay,
                repeats: false
            )
        )

        UNUserNotificationCenter.current().add(request)
    }

    private static func notificationContent(
        title: String,
        body: String,
        userInfo: [String: String],
        alertKey: String,
        fingerprint: String
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [
            "alert_key": alertKey,
            "fingerprint": fingerprint,
        ].merging(userInfo) { _, routeValue in
            routeValue
        }

        if userInfo["broker"]?
            .localizedCaseInsensitiveContains("aqua") == true {
            content.categoryIdentifier = "AQUA_TRADE_ALERT"
        }

        return content
    }

    private static func deliverBatchSummary() {
        let alerts = pendingBatch
        pendingBatch.removeAll()

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(
            withIdentifiers: alerts.map(\.identifier)
        )

        let symbols = Array(
            Set(alerts.map { $0.symbol.uppercased() })
        )
        .sorted()

        let content = UNMutableNotificationContent()
        content.title = "ChaseINGreen Trade Alerts"
        content.body = "Review conditions on \(symbols.joined(separator: ", "))."
        content.sound = .default
        content.userInfo = [
            "batched_alert": "true",
            "alert_count": String(alerts.count),
            "symbols": symbols.joined(separator: ","),
        ]

        let request = UNNotificationRequest(
            identifier: "trade-alert-batch.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }
}

@main
struct ChaseINGreenApp: App {
#if canImport(UIKit)
    @UIApplicationDelegateAdaptor(
        ChaseINGreenAppDelegate.self
    ) private var appDelegate
#elseif canImport(AppKit)
    @NSApplicationDelegateAdaptor(
        ChaseINGreenMacAppDelegate.self
    ) private var appDelegate
#endif

    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                showSplash = false
                            }
                        }
                    }
            } else {
                ContentView()
            }
        }
    }
}
