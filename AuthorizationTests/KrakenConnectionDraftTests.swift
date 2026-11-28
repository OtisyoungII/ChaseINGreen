import XCTest
@testable import ChaseINGreenAuthorization

final class KrakenConnectionDraftTests: XCTestCase {
    @MainActor func testClipboardRoundTripsPreserveAllFieldsUntilTimeout() async {
        let draft = KrakenConnectionDraft()
        let start = Date()
        draft.update(.name, "Kraken Savings", now: start)
        draft.update(.classification, "personal", now: start)
        draft.update(.key, "fixture-key", now: start)
        for seconds in [1.0, 10, 40, 80] {
            draft.expireIfNeeded(now: start.addingTimeInterval(seconds))
            XCTAssertEqual(draft.key, "fixture-key")
        }
        draft.update(.secret, "fixture-secret", now: start.addingTimeInterval(80))
        draft.expireIfNeeded(now: start.addingTimeInterval(100))
        XCTAssertEqual(draft.secret, "fixture-secret")
        XCTAssertEqual(draft.name, "Kraken Savings")
        XCTAssertEqual(draft.classification, "personal")
        XCTAssertTrue(draft.valid)
        draft.clear()
    }
    @MainActor func testClassificationDoesNotRenameOrChangeIdentity() async {
        let draft = KrakenConnectionDraft()
        draft.update(.name, "Kraken Trading")
        draft.update(.key, "fixture-key")
        let revision = draft.revision
        draft.update(.classification, "business")
        XCTAssertEqual(draft.name, "Kraken Trading")
        XCTAssertEqual(draft.key, "fixture-key")
        XCTAssertEqual(draft.revision, revision)
        draft.clear()
    }
    @MainActor func testCancellationLogoutAndSuccessClearCredentials() async {
        let draft = KrakenConnectionDraft()
        for success in [false, true] {
            draft.update(.key, "fixture-key")
            draft.update(.secret, "fixture-secret")
            if success { draft.registrationSucceeded(revision: draft.revision) }
            else { draft.clear() }
            XCTAssertTrue(draft.key.isEmpty)
            XCTAssertTrue(draft.secret.isEmpty)
            XCTAssertTrue(draft.name.isEmpty)
            XCTAssertFalse(draft.valid)
        }
    }
    @MainActor func testSecurityTimeoutAndLateSuccessCannotEraseNewDraft() async {
        let draft = KrakenConnectionDraft()
        let start = Date()
        draft.update(.key, "fixture-old", now: start)
        let old = draft.revision
        draft.expireIfNeeded(now: start.addingTimeInterval(901))
        XCTAssertTrue(draft.expired)
        XCTAssertTrue(draft.key.isEmpty)
        draft.update(.key, "fixture-new")
        draft.registrationSucceeded(revision: old)
        XCTAssertEqual(draft.key, "fixture-new")
        draft.clear()
    }
    @MainActor func testRegistrationRequiresActualInputs() async {
        let draft = KrakenConnectionDraft()
        XCTAssertFalse(draft.valid)
        draft.update(.name, "Kraken Personal")
        draft.update(.key, "fixture")
        draft.update(.secret, "   ")
        XCTAssertFalse(draft.valid)
        draft.update(.secret, "fixture-secret")
        XCTAssertTrue(draft.valid)
        draft.update(.name, String(repeating: "x", count: 151))
        XCTAssertFalse(draft.valid)
        draft.clear()
    }
}
