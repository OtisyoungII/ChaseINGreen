import XCTest
@testable import ChaseINGreenAuthorization

final class AcceptedValuationTests: XCTestCase {
    let observed = Date(timeIntervalSince1970: 1_790_000_000)
    func value() -> AcceptedValuation {
        AcceptedValuation(version: 1, valuationId: "observation-1", instrument: "ABTC", price: 8.09,
            provider: "yahoo", observedAt: ISO8601DateFormatter().string(from: observed),
            receivedAt: ISO8601DateFormatter().string(from: observed), netPnl: 1.62)
    }
    func testForegroundAgesBeforeResponse() {
        XCTAssertEqual(value().state(at: observed.addingTimeInterval(30)), "fresh")
        XCTAssertEqual(value().state(at: observed.addingTimeInterval(121)), "stale")
    }
    func testRestartDecodingDoesNotRenewObservation() throws {
        let decoded = try JSONDecoder().decode(AcceptedValuation.self, from: JSONEncoder().encode(value()))
        XCTAssertEqual(decoded.valuationId, value().valuationId)
        XCTAssertEqual(decoded.state(at: observed.addingTimeInterval(300)), "stale")
    }
    func testMissingTimeDoesNotUseReceipt() {
        var mark = value(); mark.observedAt = nil
        XCTAssertEqual(mark.state(at: observed), "unknown")
    }
    func testFutureAndDailyBarNeverLive() {
        XCTAssertEqual(value().state(at: observed.addingTimeInterval(-1)), "unknown")
        var mark = value(); mark.observationKind = "daily_bar"
        XCTAssertEqual(mark.state(at: observed.addingTimeInterval(1)), "stale")
    }
    func testRowAndGroupUseIdenticalValue() {
        let row = value()
        XCTAssertEqual(AcceptedValuation.groupPrice([row, row]), row.price)
        XCTAssertEqual(row.netPnl, 1.62)
    }
    func testDifferentInstrumentsCannotHaveOneGroupPrice() {
        var doge = value(); doge.instrument = "DOGE-USD"
        XCTAssertNil(AcceptedValuation.groupPrice([value(), doge]))
    }
    func testSelectedTickerCannotChangePositionValuation() {
        let position = value()
        var selected = value(); selected.instrument = "DOGE-USD"; selected.price = 0.08
        XCTAssertEqual(AcceptedValuation.groupPrice([position]), 8.09)
        XCTAssertNotEqual(selected.price, position.price)
    }
    func testProviderFailureAndOfflineHaveDistinctLabels() {
        var mark = value(); mark.availability = "provider_unavailable"
        XCTAssertEqual(mark.state(at: observed), "stale")
        XCTAssertTrue(mark.label(at: observed).contains("Provider temporarily unavailable"))
        XCTAssertTrue(mark.label(at: observed, offline: true).contains("Offline"))
    }
    func testAvailabilityReasonsAreDistinct() {
        let states: [ValuationAvailability] = [.loading,.entitlement,.manualField,.unsupportedField,.missingObservation,.stale,.offline,.providerUnavailable,.missingInput,.notApplicable,.retryableUnknown]
        XCTAssertEqual(Set(states.map(\.label)).count, states.count)
    }
}

extension AcceptedValuationTests {
    func testKnownCacheCannotBeReplacedByUnknownObservation() {
        XCTAssertEqual(MarketQuoteCacheReplacementPolicy.decision(existingPrice: 8.09, existingObservedAt: observed,
            incomingPrice: 999, incomingObservedAt: nil), .retainExistingNewer)
    }
    func testStructuredEntitlementAndMissingObservationStates() throws {
        for state in ["entitlement", "missing_observation", "missing_input", "provider_unavailable"] {
            let data = Data("{\"detail\":{\"state\":\"\(state)\"}}".utf8)
            let response = try JSONDecoder().decode(SafeServerErrorResponse.self, from: data)
            XCTAssertEqual(response.availability, state)
            XCTAssertEqual(response.readableMessage, ValuationAvailability(rawValue: state)?.label)
        }
    }
}

extension AcceptedValuationTests {
    func testOfflineServerAndUnknownFailuresStayDistinct() {
        XCTAssertEqual(ValuationAvailability.failure(URLError(.notConnectedToInternet)), .offline)
        XCTAssertEqual(ValuationAvailability.failure(NSError(domain: "APIService", code: 503)), .providerUnavailable)
        XCTAssertEqual(ValuationAvailability.failure(URLError(.timedOut)), .retryableUnknown)
        XCTAssertEqual(ValuationAvailability.failure(NSError(domain: "APIService", code: 403,
            userInfo: ["availability_state": "entitlement"])), .entitlement)
    }
}
