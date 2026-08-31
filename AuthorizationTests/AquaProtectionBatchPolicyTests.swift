import XCTest
@testable import ChaseINGreenAuthorization

final class AquaProtectionBatchPolicyTests: XCTestCase {
    func testOnePositionRunsOnce() async {
        let results = await AquaProtectionBatchPolicy.runSerial(
            captured: ["one"]
        ) { "protected:\($0)" }
        XCTAssertEqual(results, ["protected:one"])
    }

    func testThreeSameSymbolPositionsRemainThreeOperations() async {
        let targets = ["BTC-A-1", "BTC-A-2", "BTC-B-1"]
        let results = await AquaProtectionBatchPolicy.runSerial(
            captured: targets
        ) { $0 }
        XCTAssertEqual(results, targets)
    }

    func testCapturedPortfolioIsUnaffectedByLaterSelectionChange() async {
        var liveSelection = ["BTC"]
        let captured = ["BTC", "GOLD", "SILVER"]
        let results = await AquaProtectionBatchPolicy.runSerial(
            captured: captured
        ) { target in
            liveSelection = [target]
            return target
        }
        XCTAssertEqual(results, captured)
        XCTAssertEqual(liveSelection, ["SILVER"])
    }

    func testFirstAndMiddleFailuresDoNotStopLaterTargets() async {
        let firstFailure = await AquaProtectionBatchPolicy.runSerial(
            captured: [1, 2, 3]
        ) { $0 == 1 ? AquaProtectionResultState.failed : .protected }
        XCTAssertEqual(firstFailure, [.failed, .protected, .protected])

        let middleFailure = await AquaProtectionBatchPolicy.runSerial(
            captured: [1, 2, 3]
        ) { $0 == 2 ? AquaProtectionResultState.failed : .protected }
        XCTAssertEqual(middleFailure, [.protected, .failed, .protected])
    }

    func testVerificationPendingDoesNotStopLaterTargets() async {
        let results = await AquaProtectionBatchPolicy.runSerial(
            captured: [1, 2, 3]
        ) { $0 == 2 ? AquaProtectionResultState.verificationPending : .protected }
        XCTAssertEqual(results, [.protected, .verificationPending, .protected])
    }

    func testDifferentSymbolsReceiveIndependentStops() {
        let btc = AquaProtectionBatchPolicy.stopPrice(
            for: .init(currentPrice: 60_000, openPrice: nil, side: "BUY"),
            percent: 1
        )
        let gold = AquaProtectionBatchPolicy.stopPrice(
            for: .init(currentPrice: 2_500, openPrice: nil, side: "SELL"),
            percent: 1
        )
        XCTAssertEqual(btc, 59_400)
        XCTAssertEqual(gold, 2_525)
    }

    func testUnknownSideOrPriceCannotFabricateStop() {
        XCTAssertNil(AquaProtectionBatchPolicy.stopPrice(
            for: .init(currentPrice: 100, openPrice: nil, side: nil),
            percent: 1
        ))
        XCTAssertNil(AquaProtectionBatchPolicy.stopPrice(
            for: .init(currentPrice: nil, openPrice: nil, side: "BUY"),
            percent: 1
        ))
    }

    func testCanonicalIdentityDedupesOnlyExactPosition() {
        let identities = [
            AquaProtectionTargetIdentity(provider: "match_trader", connectionID: "one", accountID: "A", positionID: "1"),
            AquaProtectionTargetIdentity(provider: "match_trader", connectionID: "one", accountID: "A", positionID: "1"),
            AquaProtectionTargetIdentity(provider: "match_trader", connectionID: "one", accountID: "B", positionID: "1"),
            AquaProtectionTargetIdentity(provider: "match_trader", connectionID: "one", accountID: "A", positionID: "2"),
        ]
        XCTAssertEqual(
            AquaProtectionBatchPolicy.uniqueIndices(for: identities),
            [0, 2, 3]
        )
    }

    func testDifferentTickersNeverDedupeTogether() {
        let identities = [
            AquaProtectionTargetIdentity(provider: "match_trader", connectionID: "one", accountID: "A", positionID: "BTC-1"),
            AquaProtectionTargetIdentity(provider: "match_trader", connectionID: "one", accountID: "A", positionID: "GOLD-1"),
            AquaProtectionTargetIdentity(provider: "match_trader", connectionID: "one", accountID: "A", positionID: "SILVER-1"),
        ]
        XCTAssertEqual(
            AquaProtectionBatchPolicy.uniqueIndices(for: identities),
            [0, 1, 2]
        )
    }

    func testScopesRemainExplicitAndDistinct() {
        XCTAssertEqual(
            AquaProtectionScope.allCases,
            [.position, .symbol, .portfolio]
        )
    }

    func testSummaryCountsEveryCapturedResult() {
        let summary = AquaProtectionBatchSummary(states: [
            .protected, .protected, .failed, .verificationPending,
        ])
        XCTAssertEqual(summary, .init(states: [
            .protected, .protected, .failed, .verificationPending,
        ]))
        XCTAssertEqual(summary.total, 4)
        XCTAssertEqual(summary.protected, 2)
        XCTAssertEqual(summary.failed, 1)
        XCTAssertEqual(summary.verificationPending, 1)
    }
}
