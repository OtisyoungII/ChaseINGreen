import XCTest
@testable import ChaseINGreenAuthorization

final class AquaAPIIntakeTests: XCTestCase {
    private func status(_ state: String, retained: Bool = true) throws -> AquaAPIIntake {
        let data = Data("""
        {"intake_id":"00000000-0000-0000-0000-000000000001","state":"\(state)","updated_at":"2026-11-17T00:00:00Z","credential_retained":\(retained),"observation_active":false,"trade_authorized":false,"capabilities":{}}
        """.utf8)
        return try JSONDecoder().decode(AquaAPIIntake.self, from: data)
    }
    func testOnlyExplicitRecoverableStatesOfferValidation() throws {
        for state in ["RECEIVED", "PROVIDER_UNAVAILABLE", "UNKNOWN_FAILURE", "PERSISTENCE_FAILED", "RECOVERY_REQUIRED"] {
            XCTAssertTrue(try status(state).canValidate)
            XCTAssertFalse(try status(state, retained: false).canValidate)
        }
        for state in ["VALIDATING", "DISCONNECTED", "PROVIDER_AUTH_FAILED", "PERMISSION_FAILED"] {
            XCTAssertFalse(try status(state).canValidate)
        }
    }
    func testBindingDoesNotClaimLiveObservation() throws {
        let value = try status("BOUND", retained: false)
        XCTAssertTrue(value.canValidate)
        XCTAssertFalse(value.observation_active)
        XCTAssertFalse(value.trade_authorized)
        XCTAssertTrue(value.explanation.contains("separate step"))
    }
}
