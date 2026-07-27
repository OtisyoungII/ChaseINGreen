//
//  ChaseINGreenApp.swift
//  ChaseINGreen
//

import SwiftUI
import UIKit
import UserNotifications

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
        cooldown: TimeInterval = 10 * 60
    ) {
        let fingerprintKey = fingerprintPrefix + key
        let deliveredAtKey = deliveredAtPrefix + key
        let previousFingerprint = defaults.string(
            forKey: fingerprintKey
        )
        let previousDate = defaults.object(
            forKey: deliveredAtKey
        ) as? Date

        let effectiveCooldown = critical
            ? min(cooldown, 2 * 60)
            : cooldown

        if previousFingerprint == fingerprint,
           let previousDate,
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
        ]

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
