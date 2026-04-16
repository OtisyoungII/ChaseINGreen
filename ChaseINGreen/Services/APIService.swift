//
//  APIService.swift
//  ChaseINGreen
//
//  Created by Otis Young on 4/16/26.
//

import Foundation

final class APIService {
    static let shared = APIService()

    // Replace with your live backend base URL
    private let baseURL = "https://fcbd1044a461.ngrok-free.app"

    private init() {}

    func fetchHealth(accessToken: String? = nil) async throws -> HealthResponse {
        guard let url = URL(string: "\(baseURL)/health") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(HealthResponse.self, from: data)
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

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(SetupResponse.self, from: data)
    }
}
