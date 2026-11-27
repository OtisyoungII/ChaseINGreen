import XCTest
@testable import ChaseINGreenAuthorization

final class BrokerWorkspaceIntentTests: XCTestCase {
    func testSeatRotationCannotRequestDataOrChangeProviderContext() {
        var state = BrokerWorkspaceIntent()
        for _ in 0..<100 { XCTAssertEqual(state.seatSelected(), .none) }
        XCTAssertNil(state.account)
        XCTAssertNil(state.instrument)
        XCTAssertNil(state.timeframe)
        XCTAssertEqual(state.revision, 0)
    }
    func testExplicitIntentLayers() {
        var state = BrokerWorkspaceIntent()
        XCTAssertEqual(state.workspaceVisible(), .none)
        XCTAssertEqual(state.selectInstrument("BTC"), .none)
        XCTAssertEqual(state.selectTimeframe("1m"), .none)
        XCTAssertEqual(state.entered(account: "a"), .account)
        XCTAssertEqual(state.workspaceVisible(), .instruments)
        XCTAssertEqual(state.selectInstrument("BTC"), .context)
        XCTAssertNil(state.timeframe)
        XCTAssertEqual(state.selectTimeframe("15m"), .candles)
        XCTAssertEqual(state.selectTimeframe("15m"), .none)
    }
    func testRapidSwitchInvalidatesPriorResponse() {
        var state = BrokerWorkspaceIntent()
        _ = state.entered(account: "a"); _ = state.selectInstrument("BTC"); _ = state.selectTimeframe("1m")
        let old = state.revision
        _ = state.entered(account: "b")
        XCTAssertFalse(state.accepts(account: "a", revision: old))
        XCTAssertNil(state.instrument); XCTAssertNil(state.timeframe)
        _ = state.selectInstrument("ETH"); _ = state.selectTimeframe("4h")
        let current = state.revision
        XCTAssertTrue(state.accepts(account: "b", revision: current))
        _ = state.selectInstrument("LTC")
        XCTAssertFalse(state.accepts(account: "b", revision: current))
        XCTAssertNil(state.timeframe)
    }
    func testSeatDoesNotInvalidateRetainedMarketContext() {
        var state = BrokerWorkspaceIntent()
        _ = state.entered(account: "a"); _ = state.selectInstrument("BTC"); _ = state.selectTimeframe("1h")
        let old = state
        _ = state.seatSelected()
        XCTAssertEqual(state, old)
    }
}

final class BrokerWorkspaceWiringTests: XCTestCase {
    func testRotationHasNoNetworkAndDeepReadsStayOutOfRoom() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let room = try String(contentsOf: root.appendingPathComponent("ChaseINGreen/Views/BatCave/BrokerRoomView.swift"), encoding: .utf8)
        let rotation = room.components(separatedBy: "private func rotate(_ step: Int)")[1].components(separatedBy: "private func animate")[0]
        for forbidden in ["APIService", "Task", "load(", "authenticate", "sync", "execute"] { XCTAssertFalse(rotation.contains(forbidden)) }
        XCTAssertFalse(room.contains("fetchMarketCandles"))
        XCTAssertFalse(room.contains("fetchKrakenInstruments"))
        let workspace = try String(contentsOf: root.appendingPathComponent("ChaseINGreen/Views/BatCave/BrokerTradingSurface.swift"), encoding: .utf8)
        XCTAssertTrue(workspace.contains(".onScrollVisibilityChange"))
        XCTAssertTrue(workspace.contains("guard visible, !prepared"))
        XCTAssertTrue(workspace.contains(".task(id: chartKey)"))
        XCTAssertTrue(workspace.contains("chartKey == key"))
        XCTAssertTrue(workspace.contains("Task.isCancelled"))
        XCTAssertTrue(workspace.contains("intent.accepts(account:"))
        XCTAssertEqual(workspace.components(separatedBy: "fetchMarketCandles(").count - 1, 1)
        XCTAssertFalse(workspace.contains("previewKrakenExecution"))
        XCTAssertFalse(workspace.contains("/refresh\""))
    }
}
