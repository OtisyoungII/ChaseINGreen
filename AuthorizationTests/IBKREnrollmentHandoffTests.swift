import XCTest
@testable import ChaseINGreenAuthorization

final class IBKREnrollmentHandoffTests: XCTestCase {
    private let nonce = String(repeating: "n", count: 43)

    func testOnlyLiteralLoopbackURLIsAccepted() throws {
        let receiver = try IBKRLocalReceiver("http://127.0.0.1:54321/ibkr-enrollment#\(nonce)")
        XCTAssertEqual(receiver.port, 54321)
        for url in [
            "http://localhost:54321/ibkr-enrollment#\(nonce)",
            "http://192.168.1.2:54321/ibkr-enrollment#\(nonce)",
            "http://127.0.0.1.evil.invalid:54321/ibkr-enrollment#\(nonce)",
            "http://127.0.0.1:80/ibkr-enrollment#\(nonce)",
            "https://127.0.0.1:54321/ibkr-enrollment#\(nonce)",
            "http://127.0.0.1:54321/ibkr-enrollment?redirect=evil#\(nonce)",
            "http://user@127.0.0.1:54321/ibkr-enrollment#\(nonce)",
            "http://127.0.0.1:54321/ibkr-enrollment#short"
        ] { XCTAssertThrowsError(try IBKRLocalReceiver(url)) }
    }

    func testHandoffContainsOnlyScopedCredentialIdentityAndNonce() throws {
        let receiver = try IBKRLocalReceiver("http://127.0.0.1:54321/ibkr-enrollment#\(nonce)")
        let credential = IBKRMachineEnrollment(connection_id: UUID().uuidString.lowercased(), agent_token: "cig_ibkr_" + String(repeating: "x", count: 43))
        let request = try receiver.request(credential: credential)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: String])
        XCTAssertEqual(Set(body.keys), ["connection_id", "agent_token", "nonce"])
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
        XCTAssertFalse(request.httpShouldHandleCookies)
        XCTAssertNil(request.url?.fragment)
        XCTAssertNil(request.url?.query)
    }

    func testPreparationContainsNoCredential() throws {
        let receiver = try IBKRLocalReceiver("http://127.0.0.1:54321/ibkr-enrollment#\(nonce)")
        let request = try receiver.request()
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: String])
        XCTAssertEqual(Set(body.keys), ["nonce"])
    }

    func testJWTLikeValueCannotBecomeMachineCredential() {
        let value = IBKRMachineEnrollment(connection_id: UUID().uuidString, agent_token: "synthetic.jwt.value")
        XCTAssertThrowsError(try value.validate())
    }

    func testOnlyKnownOwnershipLabelsAccepted() throws {
        try IBKREnrollmentDescription(connection_name: "Personal IBKR", agent_label: "MacBook", ownership_type: "personal").validate()
        XCTAssertThrowsError(try IBKREnrollmentDescription(connection_name: "Test", agent_label: "MacBook", ownership_type: "admin").validate())
    }
}
