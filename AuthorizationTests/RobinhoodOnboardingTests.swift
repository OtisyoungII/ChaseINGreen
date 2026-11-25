import XCTest
import CryptoKit
@testable import ChaseINGreenAuthorization

final class RobinhoodOnboardingTests: XCTestCase {
    private final class MemoryStore: RobinhoodDraftStore {
        var data: [String: Data] = [:]
        func read(owner: String) throws -> Data? { data[owner] }
        func save(_ seed: Data, owner: String) throws { data[owner] = seed }
        func delete(owner: String) throws { data.removeValue(forKey: owner) }
    }
    private let ownerA = String(repeating: "a", count: 64)
    private let ownerB = String(repeating: "b", count: 64)

    func testIndependentKeysAndResumeWithoutRegeneration() throws {
        let store = MemoryStore(), keys = RobinhoodOnboardingKeys(store: MemoryStore())
        XCTAssertThrowsError(try keys.generate(owner: ""))
        let manager = RobinhoodOnboardingKeys(store: store)
        let first = try manager.generate(owner: ownerA)
        let other = try manager.generate(owner: ownerB)
        XCTAssertNotEqual(first, other)
        XCTAssertEqual(first.base64.count, 44)
        XCTAssertEqual(Data(base64Encoded: first.base64)?.count, 32)
        XCTAssertEqual(try RobinhoodOnboardingKeys(store: store).generate(owner: ownerA), first)
        XCTAssertEqual(store.data.count, 2)
    }
    func testIntakeMatchesPublicKeyAndOwnership() throws {
        let store = MemoryStore(), manager = RobinhoodOnboardingKeys(store: MemoryStore())
        XCTAssertThrowsError(try manager.intakeBody(owner: ownerA, publicKey: RobinhoodPublicKey(base64: "invalid"), name: "Test", apiKey: "fixture", feeTierPermission: false))
        let keys = RobinhoodOnboardingKeys(store: store)
        let publicKey = try keys.generate(owner: ownerA)
        let data = try keys.intakeBody(owner: ownerA, publicKey: publicKey, name: "Customer", apiKey: " fixture ", feeTierPermission: true)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(body["onboarding_owner"] as? String, ownerA)
        XCTAssertEqual(body["api_key"] as? String, "fixture")
        XCTAssertEqual(body["fee_tier_order_permission_confirmed"] as? Bool, true)
        XCTAssertNil(body["execution_authorized"])
        let seed = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(body["private_key"] as? String)))
        let signer = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        XCTAssertEqual(signer.publicKey.rawRepresentation.base64EncodedString(), publicKey.base64)
        let message = Data("fixture-signature-never-sent".utf8)
        XCTAssertTrue(signer.publicKey.isValidSignature(try signer.signature(for: message), for: message))
        let b = try keys.generate(owner: ownerB)
        XCTAssertThrowsError(try keys.intakeBody(owner: ownerA, publicKey: b, name: "Wrong", apiKey: "fixture", feeTierPermission: false))
    }
    func testSuccessfulCompletionDeletesOnlyMatchingOwnerDraft() throws {
        let store = MemoryStore(), keys = RobinhoodOnboardingKeys(store: MemoryStore())
        XCTAssertThrowsError(try keys.discard(owner: ownerA, expectedPublicKey: RobinhoodPublicKey(base64: "missing")))
        let manager = RobinhoodOnboardingKeys(store: store)
        let a = try manager.generate(owner: ownerA), b = try manager.generate(owner: ownerB)
        XCTAssertThrowsError(try manager.discard(owner: ownerA, expectedPublicKey: b))
        try manager.discard(owner: ownerA, expectedPublicKey: a)
        XCTAssertNil(try manager.pendingPublicKey(owner: ownerA))
        XCTAssertEqual(try manager.pendingPublicKey(owner: ownerB), b)
        XCTAssertNotEqual(try manager.generate(owner: ownerA), a)
    }
    func testPublicPresentationContainsNoPrivateSeedField() throws {
        XCTAssertEqual(RobinhoodOnboardingStep.allCases.count, 4)
        XCTAssertFalse(RobinhoodOnboardingStep.allCases.contains { $0.title.lowercased().contains("private") })
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("ChaseINGreen/Views/RobinhoodConnectionView.swift"), encoding: .utf8)
        XCTAssertFalse(source.contains("SecureField(\"Base64 private seed\""))
        XCTAssertFalse(source.contains("@State private var privateKey"))
        XCTAssertTrue(source.contains("Copy Public Key"))
        XCTAssertTrue(source.contains("Robinhood API key"))
    }
}
