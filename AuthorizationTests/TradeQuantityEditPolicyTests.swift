import XCTest
@testable import ChaseINGreenAuthorization

final class TradeQuantityEditPolicyTests: XCTestCase {
    func testUnchangedStaleSnapshotDoesNotRestoreClosedQuantity() throws {
        struct Patch: Encodable { let quantity: Double?; let notes: String }
        let patch = Patch(quantity: TradeQuantityEditPolicy.changedQuantity(edited: 3, initial: 3), notes: "Other edit")
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(patch)) as! [String: Any]
        XCTAssertNil(object["quantity"])
        XCTAssertEqual(object["notes"] as? String, "Other edit")
    }
    func testIntentionalChangesReachServerValidation() {
        XCTAssertEqual(TradeQuantityEditPolicy.changedQuantity(edited: 3, initial: 2), 3)
        XCTAssertEqual(TradeQuantityEditPolicy.changedQuantity(edited: 1, initial: 2), 1)
        XCTAssertNil(TradeQuantityEditPolicy.changedQuantity(edited: nil, initial: nil))
    }
}
