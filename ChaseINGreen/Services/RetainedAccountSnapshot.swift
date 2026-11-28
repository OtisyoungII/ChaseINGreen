import Foundation
import Security

/// Device-only encrypted cache of account responses, never broker credentials.
/// Two bounded slots; the owner hash must match before any value is returned.
@MainActor
enum RetainedAccountSnapshot {
    private static let service = "com.APLDEVO.ChaseINGreen.account-snapshot.v1"
    private struct Envelope: Codable {
        let owner: String
        let savedAt: Date
        let accounts: [BrokerAccountResponse]
    }
    private static func query(_ historical: Bool) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: historical ? "historical" : "operational"]
    }
    static func read(owner: String, historical: Bool) -> [BrokerAccountResponse]? {
        var q = query(historical)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, data.count <= 512_000,
              let value = try? JSONDecoder().decode(Envelope.self, from: data),
              value.owner == owner, Date().timeIntervalSince(value.savedAt) >= 0,
              Date().timeIntervalSince(value.savedAt) < 7 * 24 * 3600 else { return nil }
        return value.accounts
    }
    static func save(_ accounts: [BrokerAccountResponse], owner: String, historical: Bool) {
        guard let data = try? JSONEncoder().encode(Envelope(owner: owner, savedAt: Date(), accounts: accounts)),
              data.count <= 512_000 else { return }
        let q = query(historical)
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(q as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var item = q
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }
    }
    static func clear() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                       kSecAttrService as String: service] as CFDictionary)
    }
}
