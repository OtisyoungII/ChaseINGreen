import Foundation

@main
enum ChartWorkbenchCoreTests {
    static func main() throws {
        try patternTransport()
        try authorityPresentation()
        streamSafety()
        viewportAndGeometry()
        indicators()
        entitlementsAndAuthority()
        print("ChartWorkbenchCoreTests: 45 assertions passed")
    }

    static func authorityPresentation() throws {
        let observational = try presentationFixture(
            lifecycleAuthority: "observational"
        )
        let degraded = try presentationFixture(
            dataStatus: "degraded",
            lifecycleAuthority: "authoritative_closed_available"
        )
        let unavailable = try presentationFixture(
            dataStatus: "unavailable",
            lifecycleAuthority: "authoritative_closed_available"
        )
        let authoritative = try presentationFixture(
            lifecycleAuthority: "authoritative_closed_available"
        )
        let provisional = try presentationFixture(
            finality: "provisional",
            lifecycleAuthority: "authoritative_closed_available"
        )

        assert(!observational.patterns[0].isAuthoritativePresentation)
        assert(!degraded.patterns[0].isAuthoritativePresentation)
        assert(!unavailable.patterns[0].isAuthoritativePresentation)
        assert(authoritative.patterns[0].isAuthoritativePresentation)
        assert(!provisional.patterns[0].isAuthoritativePresentation)

        for response in [observational, degraded, unavailable, authoritative, provisional] {
            assert(response.decisionAuthority == false)
            assert(response.patterns[0].decisionAuthority == false)
            assert(response.annotations[0].decisionAuthority == false)
        }

        let authoritativeIDs = PatternPresentationAuthority.authoritativePatternIDs(
            in: authoritative.patterns
        )
        assert(PatternPresentationAuthority.isAuthoritative(
            authoritative.annotations[0], authoritativePatternIDs: authoritativeIDs
        ))
        assert(!PatternPresentationAuthority.isAuthoritative(
            observational.annotations[0],
            authoritativePatternIDs: PatternPresentationAuthority.authoritativePatternIDs(
                in: observational.patterns
            )
        ))
    }

    static func presentationFixture(
        finality: String = "closed",
        dataStatus: String = "available",
        lifecycleAuthority: String
    ) throws -> MarketPatternResponse {
        let json = """
        {"schema_version":"market_pattern_response_v1","symbol":"TEST","timeframe":"15m","status":"available",
        "stream_identity":{"provider":"fixture","symbol":"TEST","requested_timeframe":"15m","effective_timeframe":"15m"},
        "patterns":[{"pattern_id":"p1","pattern_namespace":"structure_pattern","pattern_type":"double_top",
        "state":"confirmed","finality":"\(finality)","data_status":"\(dataStatus)","decision_authority":false,
        "lifecycle_event_authority":"\(lifecycleAuthority)","lifecycle_event_notification_eligible":false,"transition":"accepted"}],
        "annotations":[{"annotation_id":"a1","annotation_type":"horizontal_level","semantic_role":"resistance",
        "label":"Resistance","pattern_id":"p1","pattern_state":"confirmed","source_candle_ids":[],
        "finality":"\(finality)","price":100,"decision_authority":false}],
        "decision_authority":false,"reason_codes":[]}
        """
        return try JSONDecoder().decode(MarketPatternResponse.self, from: Data(json.utf8))
    }

    static func patternTransport() throws {
        let json = """
        {"schema_version":"market_pattern_response_v1","symbol":"TEST","timeframe":"15m","status":"available",
        "stream_identity":{"provider":"fixture","symbol":"TEST","requested_timeframe":"15m","effective_timeframe":"15m"},
        "patterns":[{"pattern_id":"p1","pattern_namespace":"structure_pattern","pattern_type":"future_pattern",
        "state":"confirmed","finality":"closed","data_status":"available","decision_authority":false,
        "lifecycle_event_authority":"authoritative_closed_available","lifecycle_event_notification_eligible":true,"transition":"accepted"}],
        "annotations":[{"annotation_id":"a1","annotation_type":"future_shape","semantic_role":"future","semantic_roles":["future"],
        "label":"Future","labels":["Future"],"pattern_id":"p1","pattern_state":"confirmed","source_candle_ids":[],
        "finality":"closed","decision_authority":false}],"decision_authority":false,"reason_codes":[]}
        """
        let response = try JSONDecoder().decode(MarketPatternResponse.self, from: Data(json.utf8))
        assert(response.patterns.first?.patternType == "future_pattern")
        if case .unknown("future_shape") = response.annotations[0].annotationType {} else { assertionFailure() }
        assert(response.decisionAuthority == false)
        assert(response.patterns[0].decisionAuthority == false)
        assert(response.patterns[0].isAuthoritativePresentation)
    }

    static func streamSafety() {
        let identity = PatternStreamIdentity(provider: "fixture", symbol: "TEST",
            requestedTimeframe: "15m", effectiveTimeframe: "15m")
        let response = MarketPatternResponse(schemaVersion: "v1", symbol: "TEST", timeframe: "15m",
            status: "available", streamIdentity: identity, patterns: [], annotations: [],
            decisionAuthority: false, reasonCodes: [])
        assert(PatternStreamExpectation(symbol: "TEST", requestedTimeframe: "15m",
            effectiveTimeframe: "15m", provider: "fixture").accepts(response))
        assert(!PatternStreamExpectation(symbol: "OTHER", requestedTimeframe: "15m",
            effectiveTimeframe: "15m", provider: "fixture").accepts(response))
        assert(!PatternStreamExpectation(symbol: "TEST", requestedTimeframe: "5m",
            effectiveTimeframe: "15m", provider: "fixture").accepts(response))
        assert(!PatternStreamExpectation(symbol: "TEST", requestedTimeframe: "15m",
            effectiveTimeframe: "15m", provider: "other").accepts(response))
    }

    static func viewportAndGeometry() {
        var viewport = ChartViewport(visibleCount: 20, trailingOffset: 0)
        assert(viewport.range(loadedCount: 80) == 60..<80)
        viewport.pan(candles: 10, loadedCount: 80)
        assert(viewport.range(loadedCount: 80) == 50..<70)
        viewport.zoom(scale: 2, loadedCount: 80)
        assert(viewport.visibleCount == 12)
        assert(viewport.range(loadedCount: 80) == 58..<70)
        assert(ChartGeometry.y(price: 50, minimum: 0, maximum: 100, top: 10, height: 200) == 110)
        assert(ChartGeometry.x(index: 1, count: 3, left: 10, width: 200) == 110)
    }

    static func indicators() {
        let ema = QuantIndicatorEngine.emaSeries([1, 2, 3, 4], period: 3)
        assert(ema[0] == nil && ema[2] == 2.25 && ema[3] == 3.125)
        let bands = QuantIndicatorEngine.bollinger([1, 2, 3], period: 3, deviations: 2)
        assert(abs((bands.middle[2] ?? 0) - 2) < 0.000001)
        assert(abs((bands.upper[2] ?? 0) - 3.632993161855452) < 0.000001)
        assert(QuantIndicatorEngine.rsi(Array(1...15).map(Double.init), period: 14) == 100)
        let sequence = Array(1...40).map(Double.init)
        let macdA = QuantIndicatorEngine.macd(sequence), macdB = QuantIndicatorEngine.macd(sequence)
        assert(macdA?.line == macdB?.line && macdA?.signal == macdB?.signal)

        let first = candle(0, 2, 3, 1, 2, volume: 10, kind: "traded_volume", session: "s")
        let second = candle(1, 4, 5, 3, 4, volume: 30, kind: "traded_volume", session: "s")
        let vwap = QuantIndicatorEngine.sessionVWAP([first, second])
        assert(vwap[0] == 2 && vwap[1] == 3.5)
        assert(QuantIndicatorEngine.sessionVWAP([
            candle(0, 2, 3, 1, 2, volume: 10, kind: "tick_count", session: "s")
        ]).allSatisfy { $0 == nil })
    }

    static func entitlementsAndAuthority() {
        let free = SessionCapabilityProfile(plan: "free", isGold: false, isSecret: false, isAdmin: false, isBanned: false)
        let gold = SessionCapabilityProfile(plan: "gold", isGold: true, isSecret: false, isAdmin: false, isBanned: false)
        let secret = SessionCapabilityProfile(plan: "secret", isGold: true, isSecret: true, isAdmin: false, isBanned: false)
        let admin = SessionCapabilityProfile(plan: "admin", isGold: true, isSecret: false, isAdmin: true, isBanned: false)
        assert(!free.canUseQuantChartWorkbench && !gold.canUseQuantChartWorkbench)
        assert(secret.canUseQuantChartWorkbench && admin.canUseQuantChartWorkbench)
        let evidence = QuantitativeEvidence(metricID: "rsi", timeframe: "15m", value: 50,
            series: [], state: nil, units: "index", provider: "fixture", sourceTimeframe: "15m",
            effectiveTimeframe: "15m", finality: "closed", freshnessAgeSeconds: nil,
            dataConfidence: 90, analysisConfidence: nil, decisionConfidence: nil,
            calibrationStatus: "production_definition", context: [:], decisionAuthority: false)
        assert(evidence.decisionAuthority == false)
    }

    static func candle(_ minute: Int, _ open: Double, _ high: Double, _ low: Double, _ close: Double,
                       volume: Double?, kind: String?, session: String?) -> MarketCandle {
        MarketCandle(timestamp: Date(timeIntervalSince1970: Double(minute * 60)), open: open,
            high: high, low: low, close: close, volume: volume, candleID: "c\(minute)",
            finality: "closed", dataStatus: "available", provider: "fixture", symbol: "TEST",
            sourceTimeframe: "1m", effectiveTimeframe: "1m", volumeKind: kind, sessionID: session,
            confidence: 90)
    }
}
