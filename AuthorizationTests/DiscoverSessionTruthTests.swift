import Foundation
import XCTest
@testable import ChaseINGreenAuthorization

final class DiscoverSessionTruthTests: XCTestCase {
    private func fixture() throws -> ScreenerGeneration {
        let url = Bundle.module.url(forResource: "discover_session_thesis_contract", withExtension: "json", subdirectory: "Fixtures")!
        return try XCTUnwrap(try ScreenerResponse.decode(Data(contentsOf: url)).generation)
    }
    func testRankedCoverageCountsAndFilters() throws {
        let generation = try fixture()
        let now = try XCTUnwrap(screenerDate(generation.evaluatedAt))
        let ranked = generation.candidates.filter { $0.isRanked(at: now, generationStale: false) }
        XCTAssertEqual(ranked.count, 6)
        XCTAssertEqual(generation.scannedCount, 9)
        XCTAssertEqual(generation.evaluatedCount, 6)
        XCTAssertEqual(generation.candidates.filter { $0.qualification == "not_evaluated" }.count, 3)
        for direction in ["LONG", "SHORT", "BOTH"] {
            for asset in ["ALL", "STOCK", "INDEX", "FUTURE", "COMMODITY", "CRYPTO"] {
                let filtered = generation.filtered(asset: asset, direction: direction)
                XCTAssertTrue(filtered.allSatisfy { asset == "ALL" || $0.instrument.assetClass == asset })
                XCTAssertTrue(filtered.allSatisfy { direction == "BOTH" || $0.direction == direction })
                XCTAssertLessThanOrEqual(filtered.filter { $0.isRanked(at: now, generationStale: false) }.count, ranked.count)
            }
        }
    }
    func testComponentsThesisAndReadOnlyChartProvenance() throws {
        let generation = try fixture()
        let candidate = try XCTUnwrap(generation.candidates.first { $0.score != nil })
        let parts = try XCTUnwrap(candidate.scoreComponents)
        XCTAssertEqual(parts["technical_structure"]?.maximum, 40)
        XCTAssertEqual(parts["momentum"]?.maximum, 35)
        XCTAssertEqual(parts["directional_movement"]?.maximum, 25)
        XCTAssertEqual(parts.values.reduce(0) { $0 + $1.contribution }, try XCTUnwrap(candidate.score), accuracy: 0.005)
        let thesis = try XCTUnwrap(candidate.thesis)
        XCTAssertTrue(thesis.whyThis.contains("EMA momentum"))
        XCTAssertTrue(thesis.whyNow.contains("completed 15m"))
        XCTAssertTrue(thesis.confirmation.contains("20-bar boundary"))
        XCTAssertFalse(thesis.invalidation.isEmpty)
        XCTAssertTrue(thesis.timingRisk.contains("EMA20"))
        let snapshot = DiscoverSnapshot(generation: generation, candidate: candidate)
        XCTAssertEqual(snapshot.generationId, generation.generationId)
        XCTAssertEqual(snapshot.evaluatedAt, generation.evaluatedAt)
        XCTAssertEqual(snapshot.expiresAt, generation.expiresAt)
        XCTAssertEqual(snapshot.candidate.instrument.navigationSymbol, candidate.instrument.navigationSymbol)
        XCTAssertEqual(snapshot.candidate.thesis?.confirmation, thesis.confirmation)
        XCTAssertEqual(snapshot.candidate.observation?.observedAt, candidate.observation?.observedAt)
        XCTAssertFalse(snapshot.candidate.executionAuthority)
    }
    func testStaleCannotRemainRankedOrClaimCurrentConfirmation() throws {
        let generation = try fixture()
        let now = try XCTUnwrap(screenerDate(generation.evaluatedAt))
        for candidate in generation.candidates {
            XCTAssertFalse(candidate.isRanked(at: .distantFuture, generationStale: false))
            XCTAssertFalse(candidate.isRanked(at: now, generationStale: true))
            let stale = candidate.displayReasons(stale: true).joined()
            XCTAssertFalse(stale.contains("Bullish"))
            XCTAssertFalse(stale.contains("Bearish"))
            XCTAssertFalse(stale.contains("breakout"))
        }
        XCTAssertTrue(generation.candidates.filter { $0.qualification == "not_evaluated" }.allSatisfy { $0.direction == "UNKNOWN" })
    }
    @MainActor func testNavigationExitAndReplacementCancelChildren() async {
        let lifetime = DiscoverRequestLifetime()
        var published = false
        var cancellations = 0
        let child = Task {
            do {
                try await Task.sleep(for: .seconds(30))
                try Task.checkCancellation()
                published = true
            } catch { cancellations += 1 }
        }
        lifetime.add(child)
        XCTAssertEqual(lifetime.count, 1)
        lifetime.cancel()
        await child.value
        XCTAssertFalse(published)
        XCTAssertEqual(cancellations, 1)
        XCTAssertEqual(lifetime.count, 0)
        let replacement = Task<Void, Never> { _ = try? await Task.sleep(for: .seconds(30)) }
        lifetime.add(replacement)
        lifetime.cancel()
        await replacement.value
        XCTAssertTrue(replacement.isCancelled)
        XCTAssertEqual(lifetime.count, 0)
    }
}
