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
    private struct CachedQuote {
        let quote: QuoteResponse
        let savedAt: Date
    }

    private var quoteCache: [String: CachedQuote] = [:]
    private let quoteCacheSeconds: TimeInterval = 45

    private init() {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
              !url.isEmpty else {
            fatalError("Missing APIBaseURL in Info.plist")
        }

        self.baseURL = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        print("🛰️ APIService baseURL = \(baseURL)")
    }

    func fetchAdminDashboard(accessToken: String) async throws -> AdminDashboardResponse {
        let data = try await sendRequest(
            path: "/admin/dashboard",
            method: "GET",
            accessToken: accessToken,
            label: "fetchAdminDashboard"
        )

        return try decoder.decode(AdminDashboardResponse.self, from: data)
    }

    func fetchAdminUsers(accessToken: String) async throws -> [AdminUserResponse] {
        let data = try await sendRequest(
            path: "/admin/users",
            method: "GET",
            accessToken: accessToken,
            label: "fetchAdminUsers"
        )

        return try decoder.decode([AdminUserResponse].self, from: data)
    }
    func fetchCurrentUser(accessToken: String) async throws -> CurrentUserResponse {
        let data = try await sendRequest(
            path: "/me",
            method: "GET",
            accessToken: accessToken,
            label: "fetchCurrentUser"
        )

        return try decoder.decode(CurrentUserResponse.self, from: data)
    }

    func updateAdminUser(
        userId: UUID,
        payload: AdminUserUpdateRequest,
        accessToken: String
    ) async throws -> AdminUserResponse {
        let body = try encoder.encode(payload)

        let data = try await sendRequest(
            path: "/admin/users/\(userId.uuidString)",
            method: "PATCH",
            accessToken: accessToken,
            body: body,
            label: "updateAdminUser"
        )

        return try decoder.decode(AdminUserResponse.self, from: data)
    }
    func updateWatchlist(
        watchlistId: UUID,
        payload: WatchlistUpdateRequest,
        accessToken: String
    ) async throws -> WatchlistResponse {
        let body = try encoder.encode(payload)

        let data = try await sendRequest(
            path: "/watchlists/\(watchlistId.uuidString)",
            method: "PATCH",
            accessToken: accessToken,
            body: body,
            label: "updateWatchlist"
        )

        return try decoder.decode(WatchlistResponse.self, from: data)
    }

    func fetchWatchlists(accessToken: String) async throws -> [WatchlistResponse] {
        let data = try await sendRequest(
            path: "/watchlists",
            method: "GET",
            accessToken: accessToken,
            label: "fetchWatchlists"
        )

        return try decoder.decode([WatchlistResponse].self, from: data)
    }

    func createWatchlist(
        _ payload: WatchlistCreateRequest,
        accessToken: String
    ) async throws -> WatchlistResponse {
        let body = try encoder.encode(payload)

        let data = try await sendRequest(
            path: "/watchlists",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "createWatchlist"
        )

        return try decoder.decode(WatchlistResponse.self, from: data)
    }
    
    
    func deleteWatchlist(
        watchlistId: UUID,
        accessToken: String
    ) async throws {
        _ = try await sendRequest(
            path: "/watchlists/\(watchlistId.uuidString.lowercased())",
            method: "DELETE",
            accessToken: accessToken,
            label: "deleteWatchlist"
        )
    }
    
    
    func fetchHealth(accessToken: String? = nil) async throws -> SetupHealthResponse {
        let data = try await sendRequest(path: "/health", method: "GET", accessToken: accessToken, label: "fetchHealth")
        return try decoder.decode(SetupHealthResponse.self, from: data)
    }

    func fetchSetup(for ticker: String, accessToken: String? = nil) async throws -> SetupResponse {
        let data = try await sendRequest(path: "/setups/\(ticker.uppercased())", method: "GET", accessToken: accessToken, label: "fetchSetup")
        return try decoder.decode(SetupResponse.self, from: data)
    }

    func updateTrade(
        tradeId: UUID,
        symbol: String? = nil,
        direction: String? = nil,
        entryPrice: Double? = nil,
        openedAt: String? = nil,
        currentPrice: Double? = nil,
        stopLoss: Double? = nil,
        clearStopLoss: Bool = false,
        takeProfit: Double? = nil,
        clearTakeProfit: Bool = false,
        quantity: Double? = nil,
        accountSize: Double? = nil,
        platform: String? = nil,
        brokerAccountId: String? = nil,
        brokerAccountName: String? = nil,
        brokerAccountNumberLast4: String? = nil,
        accountGroupKey: String? = nil,
        parentTradeGroupId: String? = nil,
        maxDailyLossAllowed: Double? = nil,
        maxTotalLossAllowed: Double? = nil,
        payoutTarget: Double? = nil,
        notes: String? = nil,
        accessToken: String? = nil
    ) async throws -> LoggedTradeResponse {
        let payload = LoggedTradeUpdateRequest(
            symbol: symbol,
            direction: direction,
            entryPrice: entryPrice,
            openedAt: openedAt,
            currentPrice: currentPrice,
            stopLoss: stopLoss,
            clearStopLoss: clearStopLoss,
            takeProfit: takeProfit,
            clearTakeProfit: clearTakeProfit,
            quantity: quantity,
            accountSize: accountSize,
            platform: platform,
            brokerAccountId: brokerAccountId,
            brokerAccountName: brokerAccountName,
            brokerAccountNumberLast4: brokerAccountNumberLast4,
            accountGroupKey: accountGroupKey,
            parentTradeGroupId: parentTradeGroupId,
            maxDailyLossAllowed: maxDailyLossAllowed,
            maxTotalLossAllowed: maxTotalLossAllowed,
            payoutTarget: payoutTarget,
            notes: notes
        )

        let body = try encoder.encode(payload)

        let data = try await sendRequest(
            path: "/trades/\(tradeId.uuidString)",
            method: "PATCH",
            accessToken: accessToken,
            body: body,
            label: "updateTrade"
        )

        return try decoder.decode(LoggedTradeResponse.self, from: data)
    }

    func updateBrokerPrice(
        tradeId: UUID,
        currentPrice: Double,
        notes: String? = nil,
        accessToken: String? = nil
    ) async throws -> LoggedTradeResponse {
        let body = try encoder.encode(
            BrokerPriceUpdateRequest(
                currentPrice: currentPrice,
                notes: notes
            )
        )

        let data = try await sendRequest(
            path: "/trades/\(tradeId.uuidString)/broker-price",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "updateBrokerPrice"
        )

        return try decoder.decode(LoggedTradeResponse.self, from: data)
    }
    func fetchBrokerAccounts(accessToken: String) async throws -> [BrokerAccountResponse] {
        let data = try await sendRequest(
            path: "/broker-accounts",
            method: "GET",
            accessToken: accessToken,
            label: "fetchBrokerAccounts"
        )

        return try decoder.decode([BrokerAccountResponse].self, from: data)
    }

    func manualSyncBrokerAccount(
        _ payload: BrokerAccountUpsertRequest,
        accessToken: String
    ) async throws -> BrokerAccountResponse {
        let body = try encoder.encode(payload)

        let data = try await sendRequest(
            path: "/broker-accounts/manual-sync",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "manualSyncBrokerAccount"
        )

        return try decoder.decode(BrokerAccountResponse.self, from: data)
    }

    func deleteBrokerAccount(
        accountId: UUID,
        accessToken: String
    ) async throws {
        _ = try await sendRequest(
            path: "/broker-accounts/\(accountId.uuidString)",
            method: "DELETE",
            accessToken: accessToken,
            label: "deleteBrokerAccount"
        )
    }

    func reduceTrade(
        tradeId: UUID,
        newQuantity: Double,
        currentPrice: Double? = nil,
        notes: String? = nil,
        accessToken: String? = nil
    ) async throws -> LoggedTradeResponse {
        let body = try encoder.encode(
            TradeReduceRequest(
                newQuantity: newQuantity,
                currentPrice: currentPrice,
                notes: notes
            )
        )

        let data = try await sendRequest(
            path: "/trades/\(tradeId.uuidString)/reduce",
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
        let body = try encoder.encode(
            TradeAddRequest(
                addQuantity: addQuantity,
                currentPrice: currentPrice,
                notes: notes
            )
        )

        let data = try await sendRequest(
            path: "/trades/\(tradeId.uuidString)/add",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "addToTrade"
        )

        return try decoder.decode(LoggedTradeResponse.self, from: data)
    }

    func closeTrade(
        tradeId: UUID,
        exitPrice: Double?,
        closeReason: String? = "manual_close",
        notes: String? = nil,
        exitPriceConfirmed: Bool = false,
        closeSource: String? = "user",
        closeConfidence: String? = "unconfirmed",
        accessToken: String? = nil
    ) async throws -> LoggedTradeResponse {
        let body = try encoder.encode(
            TradeCloseRequest(
                exitPrice: exitPrice,
                closeReason: closeReason,
                closeSource: closeSource,
                closeConfidence: closeConfidence,
                exitPriceConfirmed: exitPriceConfirmed,
                notes: notes
            )
        )

        let data = try await sendRequest(
            path: "/trades/\(tradeId.uuidString)/close",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "closeTrade"
        )

        return try decoder.decode(LoggedTradeResponse.self, from: data)
    }
    func createTrade(_ payload: LoggedTradeCreateRequest, accessToken: String? = nil) async throws -> LoggedTradeResponse {
        let body = try encoder.encode(payload)
        let data = try await sendRequest(path: "/trades", method: "POST", accessToken: accessToken, body: body, label: "createTrade")
        return try decoder.decode(LoggedTradeResponse.self, from: data)
    }

    func createTradeLog(_ payload: TradeLogCreateRequest, accessToken: String? = nil) async throws -> TradeToolsLogResponse {
        let body = try encoder.encode(payload)
        let data = try await sendRequest(path: "/trade-tools/log", method: "POST", accessToken: accessToken, body: body, label: "createTradeLog")
        return try decoder.decode(TradeToolsLogResponse.self, from: data)
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

    func fetchTradeStats(accessToken: String? = nil) async throws -> TradeStatsSummaryResponse {
        let data = try await sendRequest(
            path: "/trade-stats/summary",
            method: "GET",
            accessToken: accessToken,
            label: "fetchTradeStats"
        )

        return try decoder.decode(TradeStatsSummaryResponse.self, from: data)
    }
    
    

    func fetchQuote(for symbol: String, accessToken: String? = nil, forceRefresh: Bool = false) async throws -> QuoteResponse {
        let cleanedSymbol = symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        if !forceRefresh,
           let cached = quoteCache[cleanedSymbol],
           Date().timeIntervalSince(cached.savedAt) < quoteCacheSeconds {
            print("📦 fetchQuote using iOS cache for \(cleanedSymbol)")
            return cached.quote
        }

        let encodedSymbol = cleanedSymbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedSymbol

        let data = try await sendRequest(
            path: "/quotes/\(encodedSymbol)",
            method: "GET",
            accessToken: accessToken,
            label: "fetchQuote"
        )

        let quote = try decoder.decode(QuoteResponse.self, from: data)
        quoteCache[cleanedSymbol] = CachedQuote(quote: quote, savedAt: Date())

        return quote
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
    struct EmptyResponse: Codable {}
    struct CurrentUserResponse: Codable {
        let email: String? 
        let plan: String?
        let isAdmin: Bool

        enum CodingKeys: String, CodingKey {
            case email
            case plan
            case isAdmin = "is_admin"
        }
    }
}

private struct BrokerPriceBatchUpdateRequest: Codable {
    let symbol: String
    let currentPrice: Double
    let platform: String?
    let accountGroupKey: String?
    let brokerAccountId: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case currentPrice = "current_price"
        case platform
        case accountGroupKey = "account_group_key"
        case brokerAccountId = "broker_account_id"
        case notes
    }
}

private struct ServerErrorResponse: Codable {
    let detail: String?

    var readableMessage: String? {
        detail
    }
}
