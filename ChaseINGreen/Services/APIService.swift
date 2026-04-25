//
//  APIService.swift
//  ChaseINGreen
//  by : Otis Young

import Foundation

final class APIService {
    static let shared = APIService()

    private let baseURL: String
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

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
        return try decoder.decode(SetupHealthResponse.self, from: data)
    }

    func fetchSetup(for ticker: String, accessToken: String? = nil) async throws -> SetupResponse {
        let url = try makeURL(path: "/setups/\(ticker.uppercased())")
        let data = try await sendRequest(url: url, method: "GET", accessToken: accessToken, label: "fetchSetup")
        return try decoder.decode(SetupResponse.self, from: data)
    }

    func createTrade(_ payload: LoggedTradeCreateRequest, accessToken: String? = nil) async throws -> LoggedTradeResponse {
        let url = try makeURL(path: "/trades")
        let body = try encoder.encode(payload)

        let data = try await sendRequest(
            url: url,
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "createTrade"
        )

        return try decoder.decode(LoggedTradeResponse.self, from: data)
    }

    func fetchOpenTrades(accessToken: String? = nil) async throws -> [LoggedTradeResponse] {
        let url = try makeURL(path: "/trades/open")
        let data = try await sendRequest(url: url, method: "GET", accessToken: accessToken, label: "fetchOpenTrades")
        return try decoder.decode([LoggedTradeResponse].self, from: data)
    }

    func fetchRecentTrades(limit: Int = 50, accessToken: String? = nil) async throws -> [LoggedTradeResponse] {
        let url = try makeURL(path: "/trades/recent?limit=\(limit)")
        let data = try await sendRequest(url: url, method: "GET", accessToken: accessToken, label: "fetchRecentTrades")
        return try decoder.decode([LoggedTradeResponse].self, from: data)
    }

    func fetchClosedTrades(limit: Int = 50, accessToken: String? = nil) async throws -> [LoggedTradeResponse] {
        let url = try makeURL(path: "/trades/closed?limit=\(limit)")
        let data = try await sendRequest(url: url, method: "GET", accessToken: accessToken, label: "fetchClosedTrades")
        return try decoder.decode([LoggedTradeResponse].self, from: data)
    }

    func updateBrokerPrice(
        tradeId: UUID,
        currentPrice: Double,
        notes: String? = nil,
        accessToken: String? = nil
    ) async throws -> LoggedTradeResponse {
        let url = try makeURL(path: "/trades/\(tradeId.uuidString)/broker-price")
        let body = try encoder.encode(BrokerPriceUpdateRequest(currentPrice: currentPrice, notes: notes))

        let data = try await sendRequest(
            url: url,
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "updateBrokerPrice"
        )

        return try decoder.decode(LoggedTradeResponse.self, from: data)
    }

    func closeTrade(
        tradeId: UUID,
        exitPrice: Double?,
        notes: String? = nil,
        accessToken: String? = nil
    ) async throws -> LoggedTradeResponse {
        let url = try makeURL(path: "/trades/\(tradeId.uuidString)/close")
        let body = try encoder.encode(TradeCloseRequest(exitPrice: exitPrice, notes: notes))

        let data = try await sendRequest(
            url: url,
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "closeTrade"
        )

        return try decoder.decode(LoggedTradeResponse.self, from: data)
    }

    func reduceTrade(
        tradeId: UUID,
        newQuantity: Double,
        currentPrice: Double? = nil,
        notes: String? = nil,
        accessToken: String? = nil
    ) async throws -> LoggedTradeResponse {
        let url = try makeURL(path: "/trades/\(tradeId.uuidString)/reduce")
        let body = try encoder.encode(
            TradeReduceRequest(
                newQuantity: newQuantity,
                currentPrice: currentPrice,
                notes: notes
            )
        )

        let data = try await sendRequest(
            url: url,
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "reduceTrade"
        )

        return try decoder.decode(LoggedTradeResponse.self, from: data)
    }

    func addToTrade(
        tradeId: UUID,
        addQuantity: Double,
        currentPrice: Double? = nil,
        notes: String? = nil,
        accessToken: String? = nil
    ) async throws -> LoggedTradeResponse {
        let url = try makeURL(path: "/trades/\(tradeId.uuidString)/add")
        let body = try encoder.encode(
            TradeAddRequest(
                addQuantity: addQuantity,
                currentPrice: currentPrice,
                notes: notes
            )
        )

        let data = try await sendRequest(
            url: url,
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "addToTrade"
        )

        return try decoder.decode(LoggedTradeResponse.self, from: data)
    }

    func fetchQuote(for symbol: String, accessToken: String? = nil) async throws -> QuoteResponse {
        let encodedSymbol = symbol.uppercased().addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol.uppercased()
        let url = try makeURL(path: "/quotes/\(encodedSymbol)")

        let data = try await sendRequest(url: url, method: "GET", accessToken: accessToken, label: "fetchQuote")
        return try decoder.decode(QuoteResponse.self, from: data)
    }

    func fetchTradeAlert(_ payload: TradeAlertRequest, accessToken: String? = nil) async throws -> TradeAlertResponse {
        let url = try makeURL(path: "/trade-alerts/")
        let body = try encoder.encode(payload)

        let data = try await sendRequest(
            url: url,
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "fetchTradeAlert"
        )

        return try decoder.decode(TradeAlertResponse.self, from: data)
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
