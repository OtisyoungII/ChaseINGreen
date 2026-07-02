//
//  APIRefreshKey.swift
//  ChaseINGreen
//
//  Created by Otis Young on 7/2/26.
//

import Foundation

enum APIRefreshSpeed {
    case live
    case medium
    case slow
    case manual

    var cooldownSeconds: TimeInterval {
        switch self {
        case .live:
            return 5
        case .medium:
            return 30
        case .slow:
            return 90
        case .manual:
            return 0
        }
    }
}

struct APIRefreshKey: Hashable {
    let name: String
    let symbol: String?
    let broker: String?
    let accountKey: String?
    let speed: APIRefreshSpeed

    init(
        _ name: String,
        symbol: String? = nil,
        broker: String? = nil,
        accountKey: String? = nil,
        speed: APIRefreshSpeed
    ) {
        self.name = name
        self.symbol = symbol?.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.broker = broker?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.accountKey = accountKey?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.speed = speed
    }

    var storageKey: String {
        [
            name,
            symbol ?? "",
            broker ?? "",
            accountKey ?? "",
            "\(speed.cooldownSeconds)"
        ]
        .joined(separator: "|")
    }
}

@MainActor
final class APIRefreshGate {
    static let shared = APIRefreshGate()

    private var lastRefreshByKey: [String: Date] = [:]
    private var activeKeys: Set<String> = []

    private init() {}

    func shouldRefresh(
        _ key: APIRefreshKey,
        force: Bool = false
    ) -> Bool {
        if force {
            return true
        }

        let storageKey = key.storageKey

        if activeKeys.contains(storageKey) {
            return false
        }

        guard let lastRefresh = lastRefreshByKey[storageKey] else {
            return true
        }

        return Date().timeIntervalSince(lastRefresh) >= key.speed.cooldownSeconds
    }

    func begin(_ key: APIRefreshKey) {
        activeKeys.insert(key.storageKey)
    }

    func finish(_ key: APIRefreshKey) {
        activeKeys.remove(key.storageKey)
        lastRefreshByKey[key.storageKey] = Date()
    }

    func reset(_ key: APIRefreshKey) {
        activeKeys.remove(key.storageKey)
        lastRefreshByKey.removeValue(forKey: key.storageKey)
    }

    func resetAll() {
        activeKeys.removeAll()
        lastRefreshByKey.removeAll()
    }
}
