import XCTest
@testable import ChaseINGreenAuthorization

final class WorkspaceLayoutPolicyTests: XCTestCase {
    func testPhoneAndNarrowWindowUseOneColumn() {
        for width: CGFloat in [0, 240, 288, 343, 398, 600, 695] {
            XCTAssertEqual(WorkspaceLayoutPolicy.columns(availableWidth: width, accessibilityText: false), 1)
            XCTAssertEqual(WorkspaceLayoutPolicy.cardWidth(availableWidth: width, accessibilityText: false), width)
        }
    }

    func testBreakpointComesFromTwoReadableCardsAndSpacing() {
        let boundary = 2 * WorkspaceLayoutPolicy.minimumCardWidth + WorkspaceLayoutPolicy.spacing
        XCTAssertEqual(WorkspaceLayoutPolicy.columns(availableWidth: boundary - 1, accessibilityText: false), 1)
        XCTAssertEqual(WorkspaceLayoutPolicy.columns(availableWidth: boundary, accessibilityText: false), 2)
        XCTAssertEqual(WorkspaceLayoutPolicy.cardWidth(availableWidth: boundary, accessibilityText: false), 340)
    }

    func testExpandedAndSplitTransitionsNeverOverflow() {
        for width: CGFloat in [343, 1100, 480, 800, 343, 1200, 240] {
            let count = WorkspaceLayoutPolicy.columns(availableWidth: width, accessibilityText: false)
            let card = WorkspaceLayoutPolicy.cardWidth(availableWidth: width, accessibilityText: false)
            XCTAssertEqual(CGFloat(count) * card + CGFloat(count - 1) * 16, width, accuracy: 0.001)
        }
    }

    func testAccessibilityTypeKeepsSingleReadableColumn() {
        XCTAssertEqual(WorkspaceLayoutPolicy.columns(availableWidth: 1400, accessibilityText: true), 1)
    }

    func testUnspecifiedAndInvalidWidthsAreSafe() {
        for width: CGFloat in [.infinity, .nan, -10] {
            XCTAssertEqual(WorkspaceLayoutPolicy.columns(availableWidth: width, accessibilityText: false), 1)
            XCTAssertTrue(WorkspaceLayoutPolicy.cardWidth(availableWidth: width, accessibilityText: false).isFinite)
        }
    }
}
