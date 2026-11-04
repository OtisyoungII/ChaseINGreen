import XCTest
@testable import ChaseINGreenAuthorization

final class CanonicalAggregateTruthTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func fact(_ status: String, value: Double? = nil, expired: Bool = false) -> CanonicalAggregateFact {
        let formatter = ISO8601DateFormatter()
        return CanonicalAggregateFact(value: value, status: status, provenance: "broker_confirmed",
            currency: "USD", observedAt: formatter.string(from: now.addingTimeInterval(-10)),
            expiresAt: formatter.string(from: now.addingTimeInterval(expired ? -1 : 110)))
    }

    func testUnknownDoesNotRenderZeroAndAuthoritativeZeroDoes() {
        XCTAssertNil(fact("unknown").currentValue(now: now))
        XCTAssertEqual(fact("unknown").display(now: now), "Unavailable")
        XCTAssertEqual(fact("known_zero", value: 0).currentValue(now: now), 0)
        XCTAssertEqual(fact("known_zero", value: 0).display(now: now), "$0.00")
    }

    func testCachedKnownValueExpiresWithoutResponseRefresh() {
        let value = fact("known", value: 10)
        XCTAssertEqual(value.currentValue(now: now), 10)
        XCTAssertNil(value.currentValue(now: now.addingTimeInterval(111)))
        XCTAssertEqual(value.display(now: now.addingTimeInterval(111)), "Stale — unavailable")
        XCTAssertNil(fact("stale", value: 10).currentValue(now: now))
    }

    func testOldAndNewClientDecodeSameNumericContract() throws {
        var payload: [String: Any] = ["broker": "kraken", "account_id": "business",
            "account_group": "business", "currency": "USD", "risk_tone": "gray", "summary": "fixture"]
        for key in ["balance", "equity", "buying_power", "available_funds", "cash_balance",
                    "daily_pnl", "unrealized_pnl", "realized_pnl", "total_pnl"] {
            payload[key] = 0.0
        }
        let oldData = try JSONSerialization.data(withJSONObject: payload)
        let current = try JSONDecoder().decode(UnifiedPortfolioAccount.self, from: oldData)
        XCTAssertEqual(current.equity, 0) // compatibility only
        XCTAssertNil(current.canonicalTruth) // never display that fallback as canonical zero
        payload["canonical_truth"] = ["version": 1, "fields": ["equity": [
            "value": NSNull(), "status": "unknown", "provenance": "missing_evidence"]]]
        let newData = try JSONSerialization.data(withJSONObject: payload)
        struct LegacyAccount: Decodable { let equity: Double; let balance: Double }
        XCTAssertEqual(try JSONDecoder().decode(LegacyAccount.self, from: newData).equity, 0)
        let upgraded = try JSONDecoder().decode(UnifiedPortfolioAccount.self, from: newData)
        XCTAssertEqual(upgraded.canonicalTruth?.display("equity", now: now), "Unavailable")
        XCTAssertNil(upgraded.canonicalTruth?.value("equity", now: now))
    }

    func testUnknownContractVersionFailsClosed() {
        let truth = CanonicalAggregateTruth(version: 2, fields: ["equity": fact("known", value: 10)])
        XCTAssertNil(truth.value("equity", now: now))
        XCTAssertEqual(truth.display("equity", now: now), "Unavailable")
    }
}
