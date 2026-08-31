import XCTest
@testable import ChaseINGreenAuthorization

final class AquaLoginCredentialPolicyTests: XCTestCase {
    func testUsernameIsTrimmed() {
        XCTAssertEqual(
            AquaLoginCredentialPolicy.username("  user@example.com\n"),
            "user@example.com"
        )
    }

    func testPasswordIsTransmittedExactly() {
        XCTAssertEqual(
            AquaLoginCredentialPolicy.password("  secret value \n"),
            "  secret value \n"
        )
        XCTAssertEqual(AquaLoginCredentialPolicy.password("   "), "   ")
    }

    func testOnlyTrulyEmptyPasswordIsRejected() {
        XCTAssertNil(AquaLoginCredentialPolicy.password(""))
    }
}
