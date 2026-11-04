import XCTest
@testable import ChaseINGreenAuthorization
final class LogPrivacyPolicyTests: XCTestCase {
    func testPrivateValuesAreNotLogged() {
        for value in ["email=person@example.test", "sub=auth0|person", "account=U123456789", "last_four=6789",
                      "balance=12345.67", "equity=23456.78", "pnl=987.65", "cost_basis=43.21",
                      "Bearer private-token", "api_key=private-key", "broker_token=private-broker", "Authorization=secret"] {
            XCTAssertEqual(LogPrivacyPolicy.sanitize(value), "[Runtime]")
        }
    }
    func testOperationalDiagnosticsSurvive() {
        let safe = LogPrivacyPolicy.sanitize("provider=kraken lifecycle=stale included=3 unpriced=2 success=false elapsedMs=23 requestId=abcdef01")
        XCTAssertTrue(safe.contains("provider=kraken"))
        XCTAssertTrue(safe.contains("included=3"))
        XCTAssertTrue(safe.contains("requestId=abcdef01"))
        XCTAssertTrue(safe.contains("elapsedMs=23"))
    }
    func testRawErrorCannotInjectDiagnostics() {
        XCTAssertEqual(LogPrivacyPolicy.sanitize("error=upstream included=123456789 email=person@example.test"), "[Runtime]")
    }
}
