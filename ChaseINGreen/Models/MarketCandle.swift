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

    var id: Date { timestamp }

    enum CodingKeys: String, CodingKey {
        case timestamp
        case open
        case high
        case low
        case close
    }

    init(
        timestamp: Date,
        open: Double,
        high: Double,
        low: Double,
        close: Double
    ) {
        self.timestamp = timestamp
        self.open = open
        self.high = high
        self.low = low
        self.close = close
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

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

        if let parsedDate = formatterWithFraction.date(from: rawTimestamp) {
            timestamp = parsedDate
        } else if let parsedDate = formatterNoFraction.date(from: rawTimestamp) {
            timestamp = parsedDate
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .timestamp,
                in: container,
                debugDescription: "Invalid candle timestamp: \(rawTimestamp)"
            )
        }

        open = try container.decode(Double.self, forKey: .open)
        high = try container.decode(Double.self, forKey: .high)
        low = try container.decode(Double.self, forKey: .low)
        close = try container.decode(Double.self, forKey: .close)
    }
}
