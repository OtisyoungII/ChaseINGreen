import XCTest
@testable import ChaseINGreenAuthorization

final class AdminOperationsTests: XCTestCase {
    let at = Date(timeIntervalSince1970: 1_700_000_000)
    var timestamp: String { ISO8601DateFormatter().string(from: at) }

    func testRefreshIsBoundedAndFutureOrMalformedTimeFailsClosed() {
        XCTAssertEqual(OperationsPresentation.refreshSeconds, 30)
        XCTAssertFalse(OperationsPresentation.currentSnapshot("bad", now: at))
        XCTAssertFalse(OperationsPresentation.currentSnapshot(timestamp, now: at.addingTimeInterval(-1)))
        XCTAssertTrue(OperationsPresentation.currentSnapshot(timestamp, now: at.addingTimeInterval(35)))
        XCTAssertFalse(OperationsPresentation.currentSnapshot(timestamp, now: at.addingTimeInterval(36)))
    }
    func testStaleScreenNeverKeepsLiveLabel() {
        for status in ["LIVE", "AVAILABLE", "FRESH"] {
            XCTAssertEqual(OperationsPresentation.permittedStatus(status, snapshotTime: timestamp, now: at.addingTimeInterval(36)), "STALE")
        }
        for status in ["UNKNOWN", "UNSUPPORTED", "RECONCILE REQUIRED", "NOT CONFIGURED"] {
            XCTAssertEqual(OperationsPresentation.permittedStatus(status, snapshotTime: timestamp, now: at.addingTimeInterval(36)), status)
        }
    }
    func testMissingEconomicsAreNotZeroAndFractionalQuantitySurvives() throws {
        let data = Data(#"{"name":"equity","value":null,"state":"UNKNOWN","observed_at":null,"unit":null}"#.utf8)
        let missing = try JSONDecoder().decode(OperationsMetric.self, from: data)
        XCTAssertNil(missing.value)
        XCTAssertEqual(missing.formatted, "UNKNOWN")
        let small = OperationsMetric(name: "BTC", value: 0.000123, state: "STALE", observed_at: timestamp, unit: "asset units")
        XCTAssertNotEqual(small.formatted, "0")
        XCTAssertEqual(OperationsMetric(name: "equity", value: 0, state: "LIVE", observed_at: timestamp, unit: "USD").formatted, "0")
    }
    func testObservationAgeDoesNotInventTimestamp() {
        XCTAssertEqual(OperationsPresentation.age(nil, now: at), "UNKNOWN")
        XCTAssertEqual(OperationsPresentation.age(timestamp, now: at.addingTimeInterval(60)), "60s")
    }
    func testStaleRankIsHidden() throws {
        let json = #"{"id":"x","label":"WTI","symbol":"CL=F","provider":"yahoo","provider_symbol":"CL=F","status":"LIVE","direction":"short","setup":"candidate","note":"research proxy","configured":true,"observed":true,"rank":1,"score":72,"price":60,"reasons":[],"metrics":[]}"#
        let row = try JSONDecoder().decode(OperationsMarket.self, from: Data(json.utf8))
        XCTAssertNil(row.execution_symbol)
        XCTAssertTrue(OperationsPresentation.ranking(row, snapshotTime: timestamp, now: at).contains("Rank 1"))
        XCTAssertEqual(OperationsPresentation.ranking(row, snapshotTime: timestamp, now: at.addingTimeInterval(36)), "STALE · Rank — · Score —")
    }
    func testRecordedSimulationIsExplicit() throws {
        let json = #"{"id":"x","at":"2026-01-01T00:00:00Z","type":"shadow_execution_transition","source":"EXISTING SHADOW LEDGER — SIMULATED","instrument":"BTC-USD","new_state":"WAITING_FOR_ENTRY","reasons":[],"simulated":true,"plan":null,"steps":[{"kind":"WAITING_FOR_ENTRY","reasons":["equity_unknown"],"metrics":[]}]}"#
        let event = try JSONDecoder().decode(OperationsEvent.self, from: Data(json.utf8))
        XCTAssertTrue(event.simulated)
        XCTAssertNil(event.plan)
        XCTAssertEqual(event.steps.first?.reasons, ["equity_unknown"])
    }
}

extension AdminOperationsTests {
    func testObservationHeartbeatAndMarketSuccessRemainDistinct() throws {
        let json = #"{"mode":"OBSERVING","epoch":"test-epoch","retention_note":"TEST FIXTURE","scheduler_heartbeat":"2026-11-12T12:00:00Z","cycle_started":"2026-11-12T12:00:00Z","cycle_completed":"2026-11-12T12:00:01Z","last_success":null,"next_cycle":"2026-11-12T12:01:01Z","cycle_id":"test-cycle","reason":null,"duration_seconds":1,"requests":1,"concurrency":1,"event_retention":256,"rows":[],"events":[],"trading_enabled":false}"#
        let value = try JSONDecoder().decode(OperationsObservation.self, from: Data(json.utf8))
        XCTAssertNotNil(value.scheduler_heartbeat)
        XCTAssertNil(value.last_success)
        XCTAssertFalse(value.trading_enabled)
        XCTAssertEqual(value.concurrency, 1)
    }
    func testSuccessfulObservationAgesToStaleOnScreen() {
        XCTAssertEqual(OperationsPresentation.permittedStatus("SUCCESS", snapshotTime: timestamp, now: at.addingTimeInterval(36)), "STALE")
        XCTAssertEqual(OperationsPresentation.permittedStatus("RATE_LIMITED", snapshotTime: timestamp, now: at), "RATE_LIMITED")
    }
    func testTimeframeRolesAreReceivedNotInferred() throws {
        let json = #"{"timeframe":"1m","role":"timing","status":"STALE_DATA","observed_at":"2026-11-12T12:00:00Z","reason":null,"bar_count":80,"state":{"direction":"mixed","choppy":true,"compressed":true}}"#
        let frame = try JSONDecoder().decode(OperationsTimeframe.self, from: Data(json.utf8))
        XCTAssertEqual(frame.role, "timing")
        XCTAssertEqual(frame.status, "STALE_DATA")
        XCTAssertNil(frame.state?.ema_slope)
        XCTAssertEqual(frame.state?.choppy, true)
    }
}

extension AdminOperationsTests {
    func testSourceCoverageKeepsUnqualifiedIdentityAndUnknownEconomics() throws {
        let json = #"{"canonical":"GOLD","coverage":"NOT_OBSERVED","match_access":"MATCH_TRADER_ACCESS_NOT_ESTABLISHED","source_epoch":"epoch","active_provider":null,"trading_eligible":false,"sources":[{"provider":"match_trader","role":"UNAVAILABLE","classification":"UNKNOWN","access_state":"MATCH_TRADER_ACCESS_NOT_ESTABLISHED","quote_basis":"UNKNOWN","native_symbol":null,"contract_identity":null,"supported_timeframes":[],"derived_timeframes":[],"observation_eligible":false,"trading_eligible":false}],"quality":{}}"#
        let row = try JSONDecoder().decode(OperationsSourceRegistry.self, from: Data(json.utf8))
        XCTAssertEqual(row.canonical, "GOLD")
        XCTAssertNil(row.active_provider)
        XCTAssertNil(row.sources[0].native_symbol)
        XCTAssertNil(row.quality.quote_age)
        XCTAssertNil(row.quality.bid)
        XCTAssertFalse(row.trading_eligible)
    }
    func testSourceQuoteAndTradeTimesAreIndependent() throws {
        let json = #"{"trade_timestamp":"2026-11-12T14:09:15Z","quote_timestamp":null,"trade_age":4.9,"quote_age":null,"request_latency_ms":308.33,"freshness_class":"FAST"}"#
        let row = try JSONDecoder().decode(OperationsSourceQuality.self, from: Data(json.utf8))
        XCTAssertNil(row.quote_timestamp)
        XCTAssertNil(row.quote_age)
        XCTAssertEqual(row.trade_age, 4.9)
        XCTAssertEqual(row.request_latency_ms, 308.33)
    }
}

extension AdminOperationsTests {
    func testBrokerEvidenceDoesNotTurnOrderIntoFillOrUnknownIntoZero() throws {
        let json = #"{"id":"e","broker":"ibkr","account":"a","connection":"c","event_type":"BROKER_ORDER_OBSERVED","freshness":"STALE","symbol":"XAIR","quantity":null,"price":null,"origin":"UNKNOWN","protection":"UNKNOWN","warnings":[],"execution_enabled":false}"#
        let event = try JSONDecoder().decode(BrokerOperationsEvent.self, from: Data(json.utf8))
        XCTAssertEqual(event.event_type, "BROKER_ORDER_OBSERVED")
        XCTAssertNil(event.quantity)
        XCTAssertNil(event.price)
        XCTAssertFalse(event.execution_enabled)
        XCTAssertEqual(event.protection, "UNKNOWN")
    }
}

extension AdminOperationsTests {
    func testUnknownPatternNeverDefaultsToDoubleTop() {
        XCTAssertNotEqual(CustomerPresentation.patternType(nil).title, "Double Top")
        XCTAssertNotEqual(CustomerPresentation.patternType("no_setup").title, "Double Top")
        XCTAssertEqual(CustomerPresentation.patternType("double_bottom").title, "Double Bottom")
    }
}

extension AdminOperationsTests {
    func testIBKRContractIdentityAndUnknownMarkTime() throws {
        let data = Data(#"[{"native_account":"U21161141","conid":"233674866","symbol":"CHTR","quantity":1.4,"state":"UNKNOWN","protection":"UNVERIFIED","average_cost":115.574,"provider_mark":138.42837525,"unrealized_pnl":32},{"native_account":"U21665747","conid":"233674866","symbol":"CHTR","quantity":1,"state":"UNKNOWN","protection":"UNVERIFIED"}]"#.utf8)
        let rows = try JSONDecoder().decode([OperationsHolding].self, from: data)
        XCTAssertNotEqual(rows[0].id, rows[1].id)
        XCTAssertEqual(rows[0].quantity, 1.4)
        XCTAssertEqual(rows[0].unrealized_pnl, 32)
        XCTAssertNil(rows[0].provider_at)
        XCTAssertNil(rows[1].provider_mark)
    }
}
