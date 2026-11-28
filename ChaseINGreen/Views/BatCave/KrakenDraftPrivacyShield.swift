import SwiftUI
import UIKit

/// Covers credential drafts on background entry, not transient inactive interruptions.
/// System screenshots cannot universally be blocked; both credential fields remain secure.
/// Never makes the shield key, so clipboard switching does not reset field focus.
@MainActor
final class KrakenDraftPrivacyShield {
    static let shared = KrakenDraftPrivacyShield()
    private var windows: [UIWindow] = []
    private var observers: [NSObjectProtocol] = []
    private init() {}

    func install() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Self.shared.cover() }
        })
        observers.append(center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                KrakenConnectionDraft.shared.expireIfNeeded()
                Self.shared.windows.forEach { $0.isHidden = true }
                Self.shared.windows.removeAll()
            }
        })
    }

    private func cover() {
        guard windows.isEmpty, !KrakenConnectionDraft.shared.key.isEmpty || !KrakenConnectionDraft.shared.secret.isEmpty else { return }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            let controller = UIViewController()
            controller.view.backgroundColor = .black
            let label = UILabel()
            label.text = "ChaseInGreen · Private"
            label.textColor = .white
            label.textAlignment = .center
            label.frame = controller.view.bounds
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            controller.view.addSubview(label)
            window.rootViewController = controller
            window.isHidden = false
            windows.append(window)
        }
    }
}
