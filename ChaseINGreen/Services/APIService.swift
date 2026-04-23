//
//  APIService.swift
//  ChaseINGreen
//
//  Created by Otis Young on 4/16/26.
//

import Foundation

final class APIService {
    static let shared = APIService()

    private let baseURL: String

    private init() {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
              !url.isEmpty else {
            fatalError("Missing APIBaseURL in Info.plist")
        }

        self.baseURL = url
        print("🛰️ APIService baseURL = \(baseURL)")
    }

    func fetchHealth(accessToken: String? = nil) async throws -> SetupHealthResponse {
        guard let url = URL(string: "\(baseURL)/health") else {
            throw URLError(.badURL)
        }

        print("➡️ GET \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            print("🔐 fetchHealth using bearer token")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        let decoded = try JSONDecoder().decode(SetupHealthResponse.self, from: data)
        print("✅ fetchHealth success status = \(decoded.status)")
        return decoded
    }

    func fetchSetup(for ticker: String, accessToken: String? = nil) async throws -> SetupResponse {
        guard let url = URL(string: "\(baseURL)/setups/\(ticker.uppercased())") else {
            throw URLError(.badURL)
        }

        print("➡️ GET \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            print("🔐 fetchSetup using bearer token")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        let decoded = try JSONDecoder().decode(SetupResponse.self, from: data)
        print("✅ fetchSetup success ticker = \(decoded.ticker), status = \(decoded.status)")
        return decoded
    }

    func createTrade(
        _ payload: LoggedTradeCreateRequest,
        accessToken: String? = nil
    ) async throws -> LoggedTradeResponse {
        guard let url = URL(string: "\(baseURL)/trades") else {
            throw URLError(.badURL)
        }

        print("➡️ POST \(url.absoluteString)")
        print("📦 createTrade payload symbol = \(payload.symbol), direction = \(payload.direction), entry = \(payload.entryPrice)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            print("🔐 createTrade using bearer token")
        }

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        let decoded = try JSONDecoder().decode(LoggedTradeResponse.self, from: data)
        print("✅ createTrade success id = \(decoded.id.uuidString), symbol = \(decoded.symbol)")
        return decoded
    }

    func fetchOpenTrades(accessToken: String? = nil) async throws -> [LoggedTradeResponse] {
        guard let url = URL(string: "\(baseURL)/trades/open") else {
            throw URLError(.badURL)
        }

        print("➡️ GET \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            print("🔐 fetchOpenTrades using bearer token")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        let decoded = try JSONDecoder().decode([LoggedTradeResponse].self, from: data)
        print("✅ fetchOpenTrades success count = \(decoded.count)")
        return decoded
    }

    func fetchQuote(for symbol: String, accessToken: String? = nil) async throws -> QuoteResponse {
        guard let url = URL(string: "\(baseURL)/quotes/\(symbol.uppercased())") else {
            throw URLError(.badURL)
        }

        print("➡️ GET \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            print("🔐 fetchQuote using bearer token")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        let decoded = try JSONDecoder().decode(QuoteResponse.self, from: data)
        print("✅ fetchQuote success symbol = \(decoded.symbol), price = \(decoded.price ?? -1)")
        return decoded
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Response was not HTTPURLResponse")
            throw URLError(.badServerResponse)
        }

        print("⬅️ Status code = \(httpResponse.statusCode)")

        if let body = String(data: data, encoding: .utf8), !body.isEmpty {
            print("📥 Response body = \(body)")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "APIService",
                code: httpResponse.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"
                ]
            )
        }
    }
}
