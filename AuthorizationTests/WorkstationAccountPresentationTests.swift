import XCTest
@testable import ChaseINGreenAuthorization

final class WorkstationAccountPresentationTests: XCTestCase {
    func testHistoricalStatesDoNotCompeteWithActiveAccounts() {
        for status in ["expired", "FAILED", "closed", "archived", "historical", "disconnected", "revoked", "disabled"] {
            XCTAssertFalse(WorkstationAccountPresentation.isPrimary(active: true, status: status))
        }
        XCTAssertFalse(WorkstationAccountPresentation.isPrimary(active: false, status: "active"))
        XCTAssertTrue(WorkstationAccountPresentation.isPrimary(active: true, status: "active"))
    }
    func testUnknownIsNotInventedAsFailureOrAuthorization() {
        XCTAssertTrue(WorkstationAccountPresentation.isPrimary(active: true, status: nil))
    }
}
