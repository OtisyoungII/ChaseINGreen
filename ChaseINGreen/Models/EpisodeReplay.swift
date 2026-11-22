import Foundation

struct ReplayEpisodeList: Decodable {
    let execution_authorized: Bool
    let truncated: Bool
    let episodes: [ReplayEpisodeSummary]
}
struct ReplayEpisodeSummary: Decodable, Identifiable {
    let id, symbol, side, venue, mode: String
    let at: Date
}
struct EpisodeReplay: Decodable {
    let version: Int
    let episode_id, symbol, venue, side, evidence_hash: String
    let execution_authorized: Bool
    let start_at, end_at: Date
    let candles: [ReplayCandle]
    let variants: [ReplayVariant]
    let missing_evidence: [String]
    let truncated: Bool

    var presentationMode: String { candles.isEmpty ? "DECISION REPLAY" : "FULL MARKET REPLAY" }
    var hasDecisionEvidence: Bool { variants.contains { !$0.frames.isEmpty || !$0.markers.isEmpty } }
    var playbackAvailable: Bool { safeToDisplay && (hasDecisionEvidence || !candles.isEmpty) }

    var safeToDisplay: Bool {
        version == 1 && !execution_authorized && !evidence_hash.isEmpty && start_at <= end_at &&
        variants.first?.mode == "RECORDED_SHADOW" && variants.allSatisfy {
            $0.mode == "RECORDED_SHADOW" || ($0.mode == "COUNTERFACTUAL" &&
                $0.evidence_hash != nil && $0.evidence_hash == variants.first?.evidence_hash)
        } && candles.allSatisfy { $0.start < $0.end && $0.end <= $0.available_at &&
            [$0.open, $0.high, $0.low, $0.close].allSatisfy { $0.isFinite && $0 > 0 } &&
            $0.low <= min($0.open, $0.close) && $0.high >= max($0.open, $0.close) }
    }
    var timeline: [Date] {
        Array(Set([start_at.addingTimeInterval(-1), end_at] + candles.map(\.available_at) +
            variants.flatMap { $0.frames.map(\.at) + $0.markers.map(\.at) })).sorted()
    }
    func visibleCandles(at cursor: Date) -> [ReplayCandle] {
        candles.filter { $0.available_at <= cursor }.sorted { $0.end < $1.end }
    }
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: value) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid evidence timestamp"))
            }
            return date
        }
        return decoder
    }
}
struct ReplayCandle: Decodable, Identifiable {
    let id: String
    let start, end, available_at: Date
    let open, high, low, close: Double
}
struct ReplayFrame: Decodable {
    let at: Date
    let numbers: [String: Double]
    let details: [String: String]
}
struct ReplayMarker: Decodable, Identifiable {
    let id: String
    let at: Date
    let action: String
    let price: Double?
    let reason: String
    var visibleMaterial: Bool { !["HOLD", "MFE", "MAE"].contains(action) }
    var icon: String {
        switch action {
        case "ENTRY": return "arrow.down.to.line"
        case "EXIT": return "flag.checkered"
        case "STOP CHANGE", "TIGHTEN PROTECTION": return "shield.lefthalf.filled"
        case "PARTIAL", "REDUCE": return "arrow.down.right"
        default: return "diamond.fill"
        }
    }
}
struct ReplayVariant: Decodable, Identifiable {
    let id, label, mode, method: String
    let evidence_hash: String?
    let frames: [ReplayFrame]
    let markers: [ReplayMarker]
    let scorecard: [String: String]
    var isCounterfactual: Bool { mode == "COUNTERFACTUAL" }
    var badge: String { isCounterfactual ? "COUNTERFACTUAL · SIMULATED" : "RECORDED SHADOW DECISIONS" }
    func frame(at cursor: Date) -> ReplayFrame? { frames.filter { $0.at <= cursor }.max { $0.at < $1.at } }
    func markers(at cursor: Date) -> [ReplayMarker] { markers.filter { $0.at <= cursor && $0.visibleMaterial } }
}

/// Local viewing clock. It cannot submit, authorize, or change any trade state.
struct EpisodeReplayClock {
    static let speeds: [Double] = [0.5, 1, 2, 5, 10, 25]
    let points: [Date]
    private(set) var position: Double = 0
    private(set) var speed: Double = 1
    private(set) var isPlaying = false
    var index: Int { min(max(0, Int(position)), max(0, points.count - 1)) }
    var cursor: Date { points.isEmpty ? .distantPast : points[index] }
    var ended: Bool { !points.isEmpty && index == points.count - 1 }
    mutating func play() { if !ended && !points.isEmpty { isPlaying = true } }
    mutating func pause() { isPlaying = false }
    mutating func reset() { position = 0; pause() }
    mutating func setSpeed(_ value: Double) { if Self.speeds.contains(value) { speed = value } }
    mutating func seek(_ index: Double) {
        guard index.isFinite else { return }
        position = min(max(0, index), Double(max(0, points.count - 1))); pause()
    }
    mutating func step(_ delta: Int) { seek(Double(index + delta)) }
    mutating func advance(seconds: Double) {
        guard isPlaying && seconds.isFinite && seconds >= 0 else { return }
        position = min(position + seconds * speed, Double(max(0, points.count - 1)))
        if ended { pause() }
    }
}

enum EpisodeReplayAccess {
    static func permits(_ profile: SessionCapabilityProfile?) -> Bool {
        // Secret alone does not grant access to owner/admin episode history.
        profile.map { $0.isAdmin && !$0.isBanned } ?? false
    }
}
