//
//  APIService.swift
//  ChaseINGreen
//  by: Otis Young
//

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

        self.baseURL = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        print("🛰️ APIService baseURL = \(baseURL)")
    }

    func fetchHealth(accessToken: String? = nil) async throws -> SetupHealthResponse {
        let data = try await sendRequest(path: "/health", method: "GET", accessToken: accessToken, label: "fetchHealth")
        return try decoder.decode(SetupHealthResponse.self, from: data)
    }

    func fetchSetup(for ticker: String, accessToken: String? = nil) async throws -> SetupResponse {
        let data = try await sendRequest(path: "/setups/\(ticker.uppercased())", method: "GET", accessToken: accessToken, label: "fetchSetup")
        return try decoder.decode(SetupResponse.self, from: data)
    }

    func createTrade(_ payload: LoggedTradeCreateRequest, accessToken: String? = nil) async throws -> LoggedTradeResponse {
        let body = try encoder.encode(payload)
        let data = try await sendRequest(path: "/trades", method: "POST", accessToken: accessToken, body: body, label: "createTrade")
        return try decoder.decode(LoggedTradeResponse.self, from: data)
    }

    func fetchOpenTrades(accessToken: String? = nil) async throws -> [LoggedTradeResponse] {
        let data = try await sendRequest(path: "/trades/open", method: "GET", accessToken: accessToken, label: "fetchOpenTrades")
        return try decoder.decode([LoggedTradeResponse].self, from: data)
    }

    func fetchRecentTrades(limit: Int = 50, accessToken: String? = nil) async throws -> [LoggedTradeResponse] {
        let safeLimit = max(1, min(limit, 250))
        let data = try await sendRequest(path: "/trades/recent?limit=\(safeLimit)", method: "GET", accessToken: accessToken, label: "fetchRecentTrades")
        return try decoder.decode([LoggedTradeResponse].self, from: data)
    }

    func fetchClosedTrades(limit: Int = 50, accessToken: String? = nil) async throws -> [LoggedTradeResponse] {
        let safeLimit = max(1, min(limit, 250))
        let data = try await sendRequest(path: "/trades/closed?limit=\(safeLimit)", method: "GET", accessToken: accessToken, label: "fetchClosedTrades")
        return try decoder.decode([LoggedTradeResponse].self, from: data)
    }

    func updateTrade(
        tradeId: UUID,
        currentPrice: Double? = nil,
        stopLoss: Double? = nil,
        clearStopLoss: Bool = false,
        takeProfit: Double? = nil,
        clearTakeProfit: Bool = false,
        quantity: Double? = nil,
        accountSize: Double? = nil,
        platform: String? = nil,
        notes: String? = nil,
        accessToken: String? = nil
    ) async throws -> LoggedTradeResponse {
        let payload = LoggedTradeUpdateRequest(
            currentPrice: currentPrice,
            stopLoss: stopLoss,
            clearStopLoss: clearStopLoss,
            takeProfit: takeProfit,
            clearTakeProfit: clearTakeProfit,
            quantity: quantity,
            accountSize: accountSize,
            platform: platform,
            notes: notes
        )

        let body = try encoder.encode(payload)
        let data = try await sendRequest(path: "/trades/\(tradeId.uuidString)", method: "PATCH", accessToken: accessToken, body: body, label: "updateTrade")
        return try decoder.decode(LoggedTradeResponse.self, from: data)
    }

    func updateBrokerPrice(
        tradeId: UUID,
        currentPrice: Double,
        notes: String? = nil,
        accessToken: String? = nil
    ) async throws -> LoggedTradeResponse {
        let body = try encoder.encode(BrokerPriceUpdateRequest(currentPrice: currentPrice, notes: notes))
        let data = try await sendRequest(path: "/trades/\(tradeId.uuidString)/broker-price", method: "POST", accessToken: accessToken, body: body, label: "updateBrokerPrice")
        return try decoder.decode(LoggedTradeResponse.self, from: data)
    }

    func closeTrade(
        tradeId: UUID,
        exitPrice: Double?,
        closeReason: String? = "manual_close",
        notes: String? = nil,
        accessToken: String? = nil
    ) async throws -> LoggedTradeResponse {
        let body = try encoder.encode(
            TradeCloseRequest(exitPrice: exitPrice, closeReason: closeReason, notes: notes)
        )

        let data = try await sendRequest(path: "/trades/\(tradeId.uuidString)/close", method: "POST", accessToken: accessToken, body: body, label: "closeTrade")
        return try decoder.decode(LoggedTradeResponse.self, from: data)
    }

    func markStopLossHit(
        tradeId: UUID,
        exitPrice: Double?,
        notes: String? = nil,
        accessToken: String? = nil
    ) async throws -> LoggedTradeResponse {
        let body = try encoder.encode(StopLossHitRequest(exitPrice: exitPrice, notes: notes))
        let data = try await sendRequest(path: "/trades/\(tradeId.uuidString)/stop-hit", method: "POST", accessToken: accessToken, body: body, label: "markStopLossHit")
        return try decoder.decode(LoggedTradeResponse.self, from: data)
    }

    func markTakeProfitHit(
        tradeId: UUID,
        exitPrice: Double?,
        notes: String? = nil,
        accessToken: String? = nil
    ) async throws -> LoggedTradeResponse {
        let body = try encoder.encode(TakeProfitHitRequest(exitPrice: exitPrice, notes: notes))
        let data = try await sendRequest(path: "/trades/\(tradeId.uuidString)/take-profit-hit", method: "POST", accessToken: accessToken, body: body, label: "markTakeProfitHit")
        return try decoder.decode(LoggedTradeResponse.self, from: data)
    }

    func reduceTrade(
        tradeId: UUID,
        newQuantity: Double,
        currentPrice: Double? = nil,
        notes: String? = nil,
        accessToken: String? = nil
    ) async throws -> LoggedTradeResponse {
        let body = try encoder.encode(
            TradeReduceRequest(newQuantity: newQuantity, currentPrice: currentPrice, notes: notes)
        )

        let data = try await sendRequest(path: "/trades/\(tradeId.uuidString)/reduce", method: "POST", accessToken: accessToken, body: body, label: "reduceTrade")
        return try decoder.decode(LoggedTradeResponse.self, from: data)
    }

    func addToTrade(
        tradeId: UUID,
        addQuantity: Double,
        currentPrice: Double? = nil,
        notes: String? = nil,
        accessToken: String? = nil
    ) async throws -> LoggedTradeResponse {
        let body = try encoder.encode(
            TradeAddRequest(addQuantity: addQuantity, currentPrice: currentPrice, notes: notes)
        )

        let data = try await sendRequest(path: "/trades/\(tradeId.uuidString)/add", method: "POST", accessToken: accessToken, body: body, label: "addToTrade")
        return try decoder.decode(LoggedTradeResponse.self, from: data)
    }

    func fetchQuote(for symbol: String, accessToken: String? = nil) async throws -> QuoteResponse {
        let encodedSymbol = symbol.uppercased().addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol.uppercased()
        let data = try await sendRequest(path: "/quotes/\(encodedSymbol)", method: "GET", accessToken: accessToken, label: "fetchQuote")
        return try decoder.decode(QuoteResponse.self, from: data)
    }

    func fetchTradeAlert(_ payload: TradeAlertRequest, accessToken: String? = nil) async throws -> TradeAlertResponse {
        let body = try encoder.encode(payload)
        let data = try await sendRequest(path: "/trade-alerts/", method: "POST", accessToken: accessToken, body: body, label: "fetchTradeAlert")
        return try decoder.decode(TradeAlertResponse.self, from: data)
    }

    private func makeURL(path: String) throws -> URL {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw URLError(.badURL)
        }
        return url
    }

    private func sendRequest(
        path: String,
        method: String,
        accessToken: String?,
        body: Data? = nil,
        label: String
    ) async throws -> Data {
        let url = try makeURL(path: path)

        print("➡️ \(method) \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")

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
            let message = extractServerErrorMessage(from: data)
                ?? "Server returned status code \(httpResponse.statusCode)"

            throw NSError(
                domain: "APIService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }

    private func extractServerErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if let decoded = try? decoder.decode(ServerErrorResponse.self, from: data) {
            return decoded.readableMessage
        }

        return String(data: data, encoding: .utf8)
    }
}

private struct ServerErrorResponse: Codable {
    let detail: String?

    var readableMessage: String? {
        detail
    }
}
