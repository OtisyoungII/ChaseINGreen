import XCTest
@testable import ChaseINGreenAuthorization

final class DecisionReplayAvailabilityTests: XCTestCase {
    private func episode(candles: [ReplayCandle] = []) -> EpisodeReplay {
        let t=Date(timeIntervalSince1970:0)
        let frames=[ReplayFrame(at:t,numbers:[:],details:["status":"PLAN_RECORDED"]),
            ReplayFrame(at:t.addingTimeInterval(10),numbers:["entry":100,"mark":100,"quantity":1],details:["action":"ENTRY"]),
            ReplayFrame(at:t.addingTimeInterval(20),numbers:["mark":105,"stop":102,"mfe":5],details:["action":"TIGHTEN_PROTECTION"]),
            ReplayFrame(at:t.addingTimeInterval(30),numbers:["mark":103,"quantity":0,"realized_pnl":3],details:["action":"EXIT"])]
        let markers=zip(["ENTRY","TIGHTEN PROTECTION","EXIT"],[10.0,20,30]).map { action,time in
            ReplayMarker(id:action,at:t.addingTimeInterval(time),action:action,price:100,reason:"Retained decision") }
        return EpisodeReplay(version:1,episode_id:"episode",symbol:"TEST",venue:"aqua",side:"short",evidence_hash:"frozen",execution_authorized:false,start_at:t,end_at:t.addingTimeInterval(30),candles:candles,
            variants:[ReplayVariant(id:"recorded",label:"Original",mode:"RECORDED_SHADOW",method:"Recorded",evidence_hash:nil,frames:frames,markers:markers,scorecard:["gross_pnl":"3"])],missing_evidence:[],truncated:false)
    }
    func testMissingOHLCStillHasDecisionReplayAndPlayback() {
        let e=episode();XCTAssertTrue(e.playbackAvailable);XCTAssertEqual(e.presentationMode,"DECISION REPLAY")
        XCTAssertTrue(e.visibleCandles(at:e.end_at).isEmpty)
        XCTAssertTrue(ReplayChartEvidence.candles(e,at:e.end_at).isEmpty)
        XCTAssertTrue(ReplayChartEvidence.indicators([]).macd.isEmpty)
    }
    func testNoCandlePlaybackRevealsEntryManagementExitAndStateCausally() {
        let e=episode(),v=e.variants[0];var clock=EpisodeReplayClock(points:e.timeline)
        XCTAssertTrue(v.markers(at:clock.cursor).isEmpty)
        clock.play();clock.advance(seconds:2)
        XCTAssertEqual(v.markers(at:clock.cursor).map(\.action),["ENTRY"])
        XCTAssertEqual(v.frame(at:clock.cursor)?.numbers["mark"],100)
        clock.pause();let cursor=clock.cursor;clock.advance(seconds:3);XCTAssertEqual(cursor,clock.cursor)
        clock.step(1);XCTAssertEqual(v.markers(at:clock.cursor).last?.action,"TIGHTEN PROTECTION")
        clock.setSpeed(25);clock.play();clock.advance(seconds:1)
        XCTAssertEqual(v.markers(at:clock.cursor).last?.action,"EXIT")
        XCTAssertEqual(v.frame(at:clock.cursor)?.numbers["realized_pnl"],3)
        clock.reset();XCTAssertTrue(v.markers(at:clock.cursor).isEmpty)
    }
    func testValidCandleAutomaticallySelectsFullMarketWithoutBlockingIndicators() {
        let t=Date(timeIntervalSince1970:0)
        let e=episode(candles:[ReplayCandle(id:"bar",start:t,end:t.addingTimeInterval(10),available_at:t.addingTimeInterval(11),open:100,high:105,low:99,close:102)])
        XCTAssertEqual(e.presentationMode,"FULL MARKET REPLAY");XCTAssertTrue(e.playbackAvailable)
        XCTAssertTrue(e.visibleCandles(at:t.addingTimeInterval(10)).isEmpty)
        let bars=ReplayChartEvidence.candles(e,at:t.addingTimeInterval(11));XCTAssertEqual(bars.count,1)
        XCTAssertNil(QuantIndicatorEngine.emaSeries(bars.map(\.close),period:200).first!)
        XCTAssertNil(ReplayChartEvidence.indicators(bars).macd.first!)
        XCTAssertTrue(e.playbackAvailable)
        XCTAssertEqual(e.variants[0].markers(at:e.end_at).last?.action,"EXIT")
        // Missing post-exit candles does not disable the retained entry/management/exit.
        XCTAssertEqual(e.visibleCandles(at:e.end_at).count,1)
    }

    func testOptionalProductionRetainedExcerptsWithoutOHLC() throws {
        guard let path=ProcessInfo.processInfo.environment["CHASE_REPLAY_ACCEPTANCE_FIXTURE"] else {
            throw XCTSkip("Supply a read-only retained excerpt for production-data validation")
        }
        let episodes=try EpisodeReplay.decoder().decode([EpisodeReplay].self,from:Data(contentsOf:URL(fileURLWithPath:path)))
        XCTAssertEqual(Set(episodes.map(\.symbol)),Set(["ETHUSD","BCHUSD","LTCUSD"]))
        for episode in episodes {
            XCTAssertEqual(episode.presentationMode,"DECISION REPLAY")
            XCTAssertTrue(episode.playbackAvailable)
            XCTAssertTrue(episode.candles.isEmpty)
            var clock=EpisodeReplayClock(points:episode.timeline)
            clock.play();clock.advance(seconds:1000)
            XCTAssertTrue(clock.ended)
            XCTAssertNotNil(episode.variants[0].frame(at:clock.cursor))
            XCTAssertTrue(episode.variants[0].markers(at:clock.cursor).contains { $0.action == "EXIT" })
            clock.reset();XCTAssertTrue(episode.variants[0].markers(at:clock.cursor).isEmpty)
        }
    }
}
