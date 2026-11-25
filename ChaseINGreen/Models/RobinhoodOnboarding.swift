import Foundation
import CryptoKit
import Security

/// Only a public key is presentation state. The pending seed stays in device Keychain.
public struct RobinhoodPublicKey: Equatable, Sendable {
    public let base64: String
}

public enum RobinhoodOnboardingError: Error {
    case invalidOwner, protectedStorageUnavailable, missingDraft, changedDraft, secureTransportRequired
}

public protocol RobinhoodDraftStore {
    func read(owner: String) throws -> Data?
    func save(_ seed: Data, owner: String) throws
    func delete(owner: String) throws
}

public final class RobinhoodDeviceDraftStore: RobinhoodDraftStore {
    private let service = "com.APLDEVO.ChaseINGreen.robinhood.onboarding"
    public init() {}
    private func query(_ owner: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: owner,
         kSecAttrSynchronizable as String: false]
    }
    public func read(owner: String) throws -> Data? {
        var request = query(owner)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw RobinhoodOnboardingError.protectedStorageUnavailable
        }
        return data
    }
    public func save(_ seed: Data, owner: String) throws {
        var request = query(owner)
        request[kSecValueData as String] = seed
        request[kSecAttrAccessible as String] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        let status = SecItemAdd(request as CFDictionary, nil)
        guard status == errSecSuccess else { throw RobinhoodOnboardingError.protectedStorageUnavailable }
    }
    public func delete(owner: String) throws {
        let status = SecItemDelete(query(owner) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw RobinhoodOnboardingError.protectedStorageUnavailable
        }
    }
}

public final class RobinhoodOnboardingKeys {
    private let store: any RobinhoodDraftStore
    public init(store: any RobinhoodDraftStore = RobinhoodDeviceDraftStore()) { self.store = store }
    private func validate(_ owner: String) throws {
        guard owner.count == 64, owner.allSatisfy(\.isHexDigit) else { throw RobinhoodOnboardingError.invalidOwner }
    }
    public func pendingPublicKey(owner: String) throws -> RobinhoodPublicKey? {
        try validate(owner)
        guard var seed = try store.read(owner: owner) else { return nil }
        defer { seed.resetBytes(in: 0..<seed.count) }
        return RobinhoodPublicKey(base64: try Curve25519.Signing.PrivateKey(rawRepresentation: seed).publicKey.rawRepresentation.base64EncodedString())
    }
    public func generate(owner: String) throws -> RobinhoodPublicKey {
        if let pending = try pendingPublicKey(owner: owner) { return pending }
        let key = Curve25519.Signing.PrivateKey()
        var seed = key.rawRepresentation
        defer { seed.resetBytes(in: 0..<seed.count) }
        try store.save(seed, owner: owner)
        return RobinhoodPublicKey(base64: key.publicKey.rawRepresentation.base64EncodedString())
    }
    /// The seed is serialized only for authenticated HTTPS intake, never for UI or clipboard.
    public func intakeBody(owner: String, publicKey: RobinhoodPublicKey, name: String,
                           apiKey: String, feeTierPermission: Bool) throws -> Data {
        try validate(owner)
        guard var seed = try store.read(owner: owner) else { throw RobinhoodOnboardingError.missingDraft }
        defer { seed.resetBytes(in: 0..<seed.count) }
        let actual = try Curve25519.Signing.PrivateKey(rawRepresentation: seed).publicKey.rawRepresentation.base64EncodedString()
        guard actual == publicKey.base64 else { throw RobinhoodOnboardingError.changedDraft }
        return try JSONSerialization.data(withJSONObject: [
            "connection_name": name, "api_key": apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            "private_key": seed.base64EncodedString(), "public_key": actual,
            "onboarding_owner": owner, "fee_tier_order_permission_confirmed": feeTierPermission
        ])
    }
    public func discard(owner: String, expectedPublicKey: RobinhoodPublicKey) throws {
        guard try pendingPublicKey(owner: owner) == expectedPublicKey else { throw RobinhoodOnboardingError.changedDraft }
        try store.delete(owner: owner)
    }
}

public enum RobinhoodOnboardingStep: Int, CaseIterable, Sendable {
    case introduction, publicKey, permissions, apiKey
    public var title: String {
        switch self {
        case .introduction: "Connect Robinhood"
        case .publicKey: "Your connection key"
        case .permissions: "Choose Robinhood permissions"
        case .apiKey: "Enter Robinhood API key"
        }
    }
}
