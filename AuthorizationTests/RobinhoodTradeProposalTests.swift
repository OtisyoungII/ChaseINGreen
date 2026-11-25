import XCTest
@testable import ChaseINGreenAuthorization

final class RobinhoodTradeProposalTests: XCTestCase {
    private func proposal(authorized: Bool = false, canConfirm: Bool = false, blockers: [String] = [], state: String = "previewed") throws -> RobinhoodTradeProposal {
        let data: [String: Any] = ["id":"fixture", "proposal_hash":String(repeating:"a",count:64),"account_suffix":"4897","symbol":"BTC/USD","side":"BUY","quantity":"0.01","order_type":"market","estimated_notional":"1","estimated_fee":"0.01","market_reference":"100","risk_note":"Unprotected","protection":"PROTECTION_UNAVAILABLE","blockers":blockers,"state":state,"market_at":"2026-11-25T19:00:00Z","expires_at":"2026-11-25T19:00:15Z","reasoning":"Owner prepared, not a market recommendation","execution_authorized":authorized,"can_confirm":canConfirm]
        return try JSONDecoder().decode(RobinhoodTradeProposal.self,from:JSONSerialization.data(withJSONObject:data))
    }
    func testApprovalAndFreshnessFailClosed() throws {
        let at=RobinhoodTradeProposal.date("2026-11-25T19:00:05Z")!
        XCTAssertFalse(try proposal().permitsConfirmation(at:at))
        XCTAssertFalse(try proposal(authorized:false,canConfirm:true).permitsConfirmation(at:at))
        XCTAssertFalse(try proposal(authorized:true,canConfirm:true,blockers:["INSUFFICIENT_BUYING_POWER"]).permitsConfirmation(at:at))
        XCTAssertFalse(try proposal(authorized:true,canConfirm:true,state:"unknown_broker_state").permitsConfirmation(at:at))
        XCTAssertTrue(try proposal(authorized:true,canConfirm:true).permitsConfirmation(at:at))
        XCTAssertFalse(try proposal(authorized:true,canConfirm:true).permitsConfirmation(at:at.addingTimeInterval(10)))
    }
    func testNoProtectionClaimOrEquitiesSubstitution() throws {
        let p=try proposal();XCTAssertEqual(p.protection,"PROTECTION_UNAVAILABLE")
        XCTAssertTrue(RobinhoodTradeProposal.blockerText("INSUFFICIENT_BUYING_POWER").contains("Stock holdings"))
        XCTAssertTrue(RobinhoodTradeProposal.blockerText("FIRST_LIVE_TEST_NOT_AUTHORIZED").contains("No order"))
    }
    func testConfirmationTransportNeverAutomaticallyRetries() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source=try String(contentsOf:root.appendingPathComponent("ChaseINGreen/Views/RobinhoodConfirmTradeView.swift"),encoding:.utf8)
        XCTAssertTrue(source.contains("allowsAuthRefresh: false"))
        XCTAssertTrue(source.contains("!confirmAttempted"))
        XCTAssertTrue(source.contains("Toggle(\"Attached stop\", isOn: .constant(false)).disabled(true)"))
        XCTAssertTrue(source.contains("proposal_hash"))
    }
}
