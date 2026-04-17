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
    }

    func fetchHealth(accessToken: String? = nil) async throws -> SetupHealthResponse {
        guard let url = URL(string: "\(baseURL)/health") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response)

        return try JSONDecoder().decode(SetupHealthResponse.self, from: data)
    }

    func fetchSetup(for ticker: String, accessToken: String? = nil) async throws -> SetupResponse {
        guard let url = URL(string: "\(baseURL)/setups/\(ticker.uppercased())") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response)

        return try JSONDecoder().decode(SetupResponse.self, from: data)
    }

    func createTrade(
        _ payload: LoggedTradeCreateRequest,
        accessToken: String? = nil
    ) async throws -> LoggedTradeResponse {
        guard let url = URL(string: "\(baseURL)/trades") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response)

        return try JSONDecoder().decode(LoggedTradeResponse.self, from: data)
    }

    func fetchOpenTrades(accessToken: String? = nil) async throws -> [LoggedTradeResponse] {
        guard let url = URL(string: "\(baseURL)/trades/open") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response)

        return try JSONDecoder().decode([LoggedTradeResponse].self, from: data)
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
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
