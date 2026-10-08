//
//  MarketCandle.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/13/26.
//

import Foundation

struct MarketCandle: Codable, Identifiable {
    let timestamp: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double?
    let candleID: String?
    let bucketStart: String?
    let bucketEnd: String?
    let finality: String
    let dataStatus: String
    let provider: String?
    let symbol: String?
    let sourceTimeframe: String?
    let effectiveTimeframe: String?
    let volumeKind: String?
    let sessionID: String?
    let confidence: Int?

    var id: String { candleID ?? String(timestamp.timeIntervalSince1970) }

    enum CodingKeys: String, CodingKey {
        case timestamp
        case open
        case high
        case low
        case close
        case volume
        case candleID = "candle_id"
        case bucketStart = "bucket_start"
        case bucketEnd = "bucket_end"
        case finality
        case dataStatus = "data_status"
        case provider
        case symbol
        case sourceTimeframe = "source_timeframe"
        case effectiveTimeframe = "effective_timeframe"
        case volumeKind = "volume_kind"
        case sessionID = "session_id"
        case confidence
    }

    init(
        timestamp: Date,
        open: Double,
        high: Double,
        low: Double,
        close: Double,
        volume: Double? = nil,
        candleID: String? = nil,
        bucketStart: String? = nil,
        bucketEnd: String? = nil,
        finality: String = "unknown",
        dataStatus: String = "degraded",
        provider: String? = nil,
        symbol: String? = nil,
        sourceTimeframe: String? = nil,
        effectiveTimeframe: String? = nil,
        volumeKind: String? = nil,
        sessionID: String? = nil,
        confidence: Int? = nil
    ) {
        self.timestamp = timestamp
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.candleID = candleID
        self.bucketStart = bucketStart
        self.bucketEnd = bucketEnd
        self.finality = finality
        self.dataStatus = dataStatus
        self.provider = provider
        self.symbol = symbol
        self.sourceTimeframe = sourceTimeframe
        self.effectiveTimeframe = effectiveTimeframe
        self.volumeKind = volumeKind
        self.sessionID = sessionID
        self.confidence = confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let epoch = try? container.decode(Double.self, forKey: .timestamp) {
            timestamp = Date(timeIntervalSince1970: epoch > 10_000_000_000 ? epoch / 1_000 : epoch)
        } else {
            let rawTimestamp = try container.decode(String.self, forKey: .timestamp)

        let formatterWithFraction = ISO8601DateFormatter()
        formatterWithFraction.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        let formatterNoFraction = ISO8601DateFormatter()
        formatterNoFraction.formatOptions = [
            .withInternetDateTime
        ]

            let normalizedTimestamp = rawTimestamp.replacingOccurrences(
                of: " ", with: "T", options: [], range: rawTimestamp.range(of: " ")
            )
            if let parsedDate = formatterWithFraction.date(from: normalizedTimestamp) {
                timestamp = parsedDate
            } else if let parsedDate = formatterNoFraction.date(from: normalizedTimestamp) {
                timestamp = parsedDate
            } else if let epoch = Double(rawTimestamp) {
                timestamp = Date(timeIntervalSince1970: epoch > 10_000_000_000 ? epoch / 1_000 : epoch)
            } else {
                throw DecodingError.dataCorruptedError(
                    forKey: .timestamp,
                    in: container,
                    debugDescription: "Invalid candle timestamp: \(rawTimestamp)"
                )
            }
        }

        open = try container.decode(Double.self, forKey: .open)
        high = try container.decode(Double.self, forKey: .high)
        low = try container.decode(Double.self, forKey: .low)
        close = try container.decode(Double.self, forKey: .close)
        volume = try container.decodeIfPresent(Double.self, forKey: .volume)
        candleID = try container.decodeIfPresent(String.self, forKey: .candleID)
        bucketStart = try container.decodeIfPresent(String.self, forKey: .bucketStart)
        bucketEnd = try container.decodeIfPresent(String.self, forKey: .bucketEnd)
        finality = try container.decodeIfPresent(String.self, forKey: .finality) ?? "unknown"
        dataStatus = try container.decodeIfPresent(String.self, forKey: .dataStatus) ?? "degraded"
        provider = try container.decodeIfPresent(String.self, forKey: .provider)
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
        sourceTimeframe = try container.decodeIfPresent(String.self, forKey: .sourceTimeframe)
        effectiveTimeframe = try container.decodeIfPresent(String.self, forKey: .effectiveTimeframe)
        volumeKind = try container.decodeIfPresent(String.self, forKey: .volumeKind)
        sessionID = try container.decodeIfPresent(String.self, forKey: .sessionID)
        confidence = try container.decodeIfPresent(Int.self, forKey: .confidence)
    }
}
