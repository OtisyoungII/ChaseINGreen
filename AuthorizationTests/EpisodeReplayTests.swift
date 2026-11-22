import XCTest
@testable import ChaseINGreenAuthorization

final class EpisodeReplayTests: XCTestCase {
    let zero = Date(timeIntervalSince1970: 0)
    func model(side: String = "long") -> EpisodeReplay {
        let candle = ReplayCandle(id:"one",start:zero,end:zero.addingTimeInterval(60),available_at:zero.addingTimeInterval(61),open:100,high:102,low:99,close:101)
        let after = ReplayCandle(id:"after",start:zero.addingTimeInterval(120),end:zero.addingTimeInterval(180),available_at:zero.addingTimeInterval(181),open:101,high:104,low:100,close:103)
        let markers = [ReplayMarker(id:"entry",at:zero.addingTimeInterval(70),action:"ENTRY",price:101,reason:"Recorded fill"),
                       ReplayMarker(id:"stop",at:zero.addingTimeInterval(90),action:"STOP CHANGE",price:100,reason:"Recorded stop"),
                       ReplayMarker(id:"exit",at:zero.addingTimeInterval(120),action:"EXIT",price:102,reason:"Recorded exit")]
        let variant = ReplayVariant(id:"recorded",label:"Original",mode:"RECORDED_SHADOW",method:"Retained",evidence_hash:"window",
            frames:[ReplayFrame(at:zero.addingTimeInterval(70),numbers:["mark":101],details:["action":"ENTRY"])],markers:markers,scorecard:[:])
        return EpisodeReplay(version:1,episode_id:"ep",symbol:"TEST",venue:"aqua",side:side,evidence_hash:"hash",execution_authorized:false,start_at:zero,end_at:zero.addingTimeInterval(181),candles:[candle,after],variants:[variant],missing_evidence:[],truncated:false)
    }
    func testFutureCandleHiddenUntilActuallyAvailable() {
        let replay=model()
        XCTAssertTrue(replay.visibleCandles(at:zero.addingTimeInterval(60)).isEmpty)
        XCTAssertEqual(replay.visibleCandles(at:zero.addingTimeInterval(61)).count,1)
        XCTAssertEqual(replay.visibleCandles(at:zero.addingTimeInterval(180)).count,1)
    }
    func testDecisionAlignmentAndNoFutureInspectorState() {
        let variant=model().variants[0]
        XCTAssertNil(variant.frame(at:zero.addingTimeInterval(69)))
        XCTAssertEqual(variant.frame(at:zero.addingTimeInterval(70))?.details["action"],"ENTRY")
        XCTAssertEqual(variant.markers(at:zero.addingTimeInterval(89)).map(\.action),["ENTRY"])
        XCTAssertEqual(variant.markers(at:zero.addingTimeInterval(90)).map(\.action),["ENTRY","STOP CHANGE"])
        XCTAssertEqual(variant.markers(at:zero.addingTimeInterval(120)).last?.action,"EXIT")
    }
    func testPlaybackContinuesAfterExitForBothSides() {
        for side in ["long","short"] {
            let replay=model(side:side)
            XCTAssertTrue(replay.safeToDisplay)
            XCTAssertEqual(replay.visibleCandles(at:replay.end_at).count,2)
            XCTAssertGreaterThan(replay.end_at,replay.variants[0].markers.last!.at)
        }
    }
    func testClockPauseStepSeekResetAndSpeeds() {
        var clock=EpisodeReplayClock(points:(0..<100).map { zero.addingTimeInterval(Double($0)) })
        clock.play();clock.advance(seconds:2);XCTAssertEqual(clock.index,2)
        clock.pause();clock.advance(seconds:3);XCTAssertEqual(clock.index,2)
        clock.step(1);XCTAssertEqual(clock.index,3)
        clock.step(-1);XCTAssertEqual(clock.index,2)
        clock.setSpeed(5);clock.play();clock.advance(seconds:2);XCTAssertEqual(clock.index,12)
        clock.setSpeed(99);XCTAssertEqual(clock.speed,5)
        clock.seek(500);XCTAssertTrue(clock.ended);XCTAssertFalse(clock.isPlaying)
        clock.reset();XCTAssertEqual(clock.index,0);XCTAssertFalse(clock.isPlaying)
    }
    func testLongSparseEpisodeNeverRunsPastBounds() {
        var clock=EpisodeReplayClock(points:(0..<3000).map { zero.addingTimeInterval(Double($0)*86400) })
        clock.setSpeed(25);clock.play();clock.advance(seconds:100000)
        XCTAssertEqual(clock.index,2999);XCTAssertFalse(clock.isPlaying)
        clock.seek(-100);XCTAssertEqual(clock.index,0)
        clock.seek(.nan);XCTAssertEqual(clock.index,0)
    }
    func testOriginalCounterfactualLabelsCannotBeConfused() {
        let original=model().variants[0]
        let replay=ReplayVariant(id:"new",label:"Current",mode:"COUNTERFACTUAL",method:"Sparse gross replay",evidence_hash:"window",frames:[],markers:[],scorecard:[:])
        XCTAssertFalse(original.isCounterfactual);XCTAssertTrue(replay.isCounterfactual)
        XCTAssertNotEqual(original.badge,replay.badge)
    }
    func testMissingEvidenceAndHoldAreNotFabricated() {
        let marker=ReplayMarker(id:"hold",at:zero,action:"HOLD",price:nil,reason:"Wait")
        XCTAssertFalse(marker.visibleMaterial)
        XCTAssertNil(model().variants[0].frame(at:zero))
        var clock=EpisodeReplayClock(points:[]);clock.play();XCTAssertFalse(clock.isPlaying)
    }
    func testAdminSecretAuthorizationFailsClosed() {
        XCTAssertFalse(EpisodeReplayAccess.permits(nil))
        for admin in [false,true] {
            for banned in [false,true] {
                let p=SessionCapabilityProfile(plan:"secret",isGold:true,isSecret:true,isAdmin:admin,isBanned:banned)
                XCTAssertEqual(EpisodeReplayAccess.permits(p),admin && !banned)
            }
        }
    }
}
