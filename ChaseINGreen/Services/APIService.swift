//
//  APIService.swift
//  ChaseINGreen
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
        let url = try makeURL(path: "/health")
        let data = try await sendRequest(url: url, method: "GET", accessToken: accessToken, label: "fetchHealth")
        let decoded = try JSONDecoder().decode(SetupHealthResponse.self, from: data)
        print("✅ fetchHealth success status = \(decoded.status)")
        return decoded
    }

    func fetchSetup(for ticker: String, accessToken: String? = nil) async throws -> SetupResponse {
        let url = try makeURL(path: "/setups/\(ticker.uppercased())")
        let data = try await sendRequest(url: url, method: "GET", accessToken: accessToken, label: "fetchSetup")
        let decoded = try JSONDecoder().decode(SetupResponse.self, from: data)
        print("✅ fetchSetup success ticker = \(decoded.ticker), status = \(decoded.status)")
        return decoded
    }

    func createTrade(_ payload: LoggedTradeCreateRequest, accessToken: String? = nil) async throws -> LoggedTradeResponse {
        let url = try makeURL(path: "/trades")
        let body = try JSONEncoder().encode(payload)

        let data = try await sendRequest(
            url: url,
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "createTrade"
        )

        let decoded = try JSONDecoder().decode(LoggedTradeResponse.self, from: data)
        print("✅ createTrade success id = \(decoded.id.uuidString), symbol = \(decoded.symbol)")
        return decoded
    }

    func fetchOpenTrades(accessToken: String? = nil) async throws -> [LoggedTradeResponse] {
        let url = try makeURL(path: "/trades/open")
        let data = try await sendRequest(url: url, method: "GET", accessToken: accessToken, label: "fetchOpenTrades")
        let decoded = try JSONDecoder().decode([LoggedTradeResponse].self, from: data)
        print("✅ fetchOpenTrades success count = \(decoded.count)")
        return decoded
    }

    func fetchQuote(for symbol: String, accessToken: String? = nil) async throws -> QuoteResponse {
        let encodedSymbol = symbol.uppercased().addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol.uppercased()
        let url = try makeURL(path: "/quotes/\(encodedSymbol)")

        let data = try await sendRequest(url: url, method: "GET", accessToken: accessToken, label: "fetchQuote")
        let decoded = try JSONDecoder().decode(QuoteResponse.self, from: data)
        print("✅ fetchQuote success symbol = \(decoded.symbol), price = \(decoded.price ?? -1)")
        return decoded
    }

    func fetchTradeAlert(_ payload: TradeAlertRequest, accessToken: String? = nil) async throws -> TradeAlertResponse {
        let url = try makeURL(path: "/trade-alerts/")
        let body = try JSONEncoder().encode(payload)

        let data = try await sendRequest(
            url: url,
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "fetchTradeAlert"
        )

        let decoded = try JSONDecoder().decode(TradeAlertResponse.self, from: data)
        print("✅ fetchTradeAlert success type = \(decoded.alertType), title = \(decoded.title)")
        return decoded
    }

    private func makeURL(path: String) throws -> URL {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw URLError(.badURL)
        }
        return url
    }

    private func sendRequest(
        url: URL,
        method: String,
        accessToken: String?,
        body: Data? = nil,
        label: String
    ) async throws -> Data {
        print("➡️ \(method) \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = method

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            print("🔐 \(label) using bearer token")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
        return data
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
