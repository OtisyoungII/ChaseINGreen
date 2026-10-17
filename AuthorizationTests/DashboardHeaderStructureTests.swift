import Foundation
import XCTest

/// The Linux/macOS policy package cannot exercise iOS SwiftUI metadata decoding.
/// Guard the concrete boundary implicated by physical SIGSEGV reports; device
/// cold-launch and login acceptance remain authoritative.
final class DashboardHeaderStructureTests: XCTestCase {
    func testWorkspaceNavigationDoesNotExpandIntoHeaderTuple() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("ChaseINGreen/Views/DashboardView.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains("private var headerWorkspaceLink: DashboardWorkspaceHeaderLink {"))
        XCTAssertTrue(source.contains("private struct DashboardWorkspaceHeaderLink: View {"))
        let start = try XCTUnwrap(source.range(of: "private var headerSection: some View {"))
        let end = try XCTUnwrap(source.range(of: "private var headerIdentitySection:", range: start.upperBound..<source.endIndex))
        let header = String(source[start.lowerBound..<end.lowerBound])
        for child in ["headerIdentitySection", "headerStatusSection", "headerAdminLink", "headerWorkspaceLink", "headerStatsSection", "headerQuickEntryButton", "headerBrokerAccountsLink"] {
            XCTAssertTrue(header.contains(child), "Production header must retain \(child)")
        }
        let componentStart = try XCTUnwrap(source.range(of: "private struct DashboardWorkspaceHeaderLink: View {"))
        let componentEnd = try XCTUnwrap(source.range(of: "private var headerStatsSection:", range: componentStart.upperBound..<source.endIndex))
        let component = String(source[componentStart.lowerBound..<componentEnd.lowerBound])
        XCTAssertTrue(component.contains("if isSecretOrAdmin {"))
        XCTAssertTrue(component.contains("TradingWorkspaceView("))
        XCTAssertFalse(component.contains("AnyView"))
    }
}
