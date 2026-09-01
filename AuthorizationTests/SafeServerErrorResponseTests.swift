import XCTest
@testable import ChaseINGreenAuthorization

final class SafeServerErrorResponseTests: XCTestCase {
    func testDecodesNestedFastAPIAquaErrorAndBuildsSafeDiagnostic() throws {
        let data = Data(#"{"detail":{"status":"login_rejected","headline":"Aqua Funding login was not accepted.","message":"Aqua Funding did not accept the login request.","reason":"upstream_bad_request","upstream_status":400}}"#.utf8)
        let response = try JSONDecoder().decode(SafeServerErrorResponse.self, from: data)
        XCTAssertEqual(response.status, "login_rejected")
        XCTAssertEqual(response.reason, "upstream_bad_request")
        XCTAssertEqual(response.upstreamStatus, 400)
        XCTAssertEqual(response.readableMessage, "Aqua Funding did not accept the login request. (upstream_bad_request)")
        XCTAssertEqual(response.diagnostic(httpStatus: 400), "httpStatus=400 status=login_rejected reason=upstream_bad_request upstreamStatus=400")
    }

    func testDecodesPlainFastAPIDetail() throws {
        let data = Data(#"{"detail":"Request rejected."}"#.utf8)
        let response = try JSONDecoder().decode(SafeServerErrorResponse.self, from: data)
        XCTAssertEqual(response.readableMessage, "Request rejected.")
        XCTAssertNil(response.status)
        XCTAssertNil(response.reason)
        XCTAssertNil(response.upstreamStatus)
    }
}
