//
//  ChaseINGreenApp.swift
//  ChaseINGreen
//

import SwiftUI
import UIKit
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

enum ChaseTradeNotifications {
    private static let defaults = UserDefaults.standard
    private static let fingerprintPrefix = "cig.alert.fingerprint."
    private static let deliveredAtPrefix = "cig.alert.delivered."

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

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [
            "alert_key": key,
            "fingerprint": fingerprint,
        ].merging(routeUserInfo) { _, routeValue in
            routeValue
        }

        if routeUserInfo["broker"]?
            .localizedCaseInsensitiveContains("aqua") == true {
            content.categoryIdentifier = "AQUA_TRADE_ALERT"
        }

        let request = UNNotificationRequest(
            identifier: "\(key).\(fingerprint)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

@main
struct ChaseINGreenApp: App {
    @UIApplicationDelegateAdaptor(
        ChaseINGreenAppDelegate.self
    ) private var appDelegate

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
