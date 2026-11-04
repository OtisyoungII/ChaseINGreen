import XCTest
@testable import ChaseINGreenAuthorization

final class ProductAnalyticsPolicyTests: XCTestCase {
    func testCoarseNativeMetadata() {
        let m = ProductAnalyticsPolicy.metadata(platform: "ipados", deviceClass: "tablet",
            osVersion: "27.0", appVersion: "1.1", build: "15", language: "es")
        XCTAssertEqual(m["platform"], "ipados")
        XCTAssertEqual(m["build"], "15")
        XCTAssertEqual(m["language"], "es")
        XCTAssertEqual(m.count, 8)
    }
    func testUnknownAndSensitiveStringsNeverBecomeVersions() {
        let m = ProductAnalyticsPolicy.metadata(platform: "future", deviceClass: "exact-model",
            osVersion: "token=secret", appVersion: nil, build: "user@example.com", language: nil)
        XCTAssertEqual(m["platform"], "unknown")
        XCTAssertEqual(m["device_class"], "unknown")
        XCTAssertEqual(m["build"], "not_collected")
        XCTAssertEqual(m["os_version"], "not_collected")
    }
}

extension ProductAnalyticsPolicyTests {
    func testActualBackendReportContractDecodes() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "product_intelligence_contract",
            withExtension: "json", subdirectory: "Fixtures"))
        let report = try JSONDecoder().decode(ProductIntelligenceResponse.self, from: Data(contentsOf: url))
        XCTAssertEqual(report.overview.active_accounts, 0)
        XCTAssertNil(report.brokers["ibkr"]?.average_latency_ms)
        XCTAssertEqual(report.brokers["ibkr"]?.valuation_observations, 0)
        XCTAssertFalse(report.limitations.isEmpty)
    }
}
