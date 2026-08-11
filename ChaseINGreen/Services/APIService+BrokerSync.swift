//
//  APIService+BrokerSync.swift
//  ChaseINGreen
//
//  By: Otis Young II
// --------------------------------------------------------------
// PURPOSE
// --------------------------------------------------------------
// ✅ Broker login and synchronization API calls
// ✅ Broker connection health for Bat Cave status lights
// ✅ Aqua Funding login through its Match-Trader backend adapter
// ✅ Match-Trader account, position, and full synchronization
// ✅ IBKR health, account, position, and full synchronization
//
// IMPORTANT RULES
// --------------------------------------------------------------
// ✅ Swift never sends a Match-Trader server URL
// ✅ Swift never sends a Match-Trader broker ID
// ✅ Swift never sends co-auth cookies
// ✅ Swift never sends refresh cookies
// ✅ Swift never sends tradingApiToken values
// ✅ Match-Trader sessions remain backend-side
// ✅ Each broker keeps its own authentication architecture
// ✅ No live orders are placed here
// --------------------------------------------------------------

import Foundation

private final class MatchTraderAPICache: @unchecked Sendable {
    static let shared = MatchTraderAPICache()

    private struct Timed<Value> {
        let value: Value
        let savedAt: Date
    }

    private let lock = NSLock()
    private var health: [String: Timed<MatchTraderAuthHealthResponse>] = [:]
    private var positions: [String: Timed<MatchTraderPositionsResponse>] = [:]
    private var instruments: [String: Timed<MatchTraderInstrumentsResponse>] = [:]
    private var quotes: [String: Timed<MatchTraderLiveQuoteResponse>] = [:]

    private func fresh<Value>(
        _ item: Timed<Value>?,
        lifetime: TimeInterval
    ) -> Value? {
        guard let item,
              Date().timeIntervalSince(item.savedAt) < lifetime else {
            return nil
        }
        return item.value
    }

    private func ownerKey(accessToken: String) -> String {
        APIRefreshKey.ownerScope(accessToken: accessToken)
    }

    private func scopedKey(
        accessToken: String,
        value: String
    ) -> String {
        "\(ownerKey(accessToken: accessToken)):\(value)"
    }

    func cachedHealth(
        accessToken: String
    ) -> MatchTraderAuthHealthResponse? {
        let key = ownerKey(accessToken: accessToken)
        lock.lock()
        defer { lock.unlock() }
        return fresh(health[key], lifetime: 120)
    }

    func saveHealth(
        _ value: MatchTraderAuthHealthResponse,
        accessToken: String
    ) {
        let key = ownerKey(accessToken: accessToken)
        lock.lock()
        health[key] = Timed(value: value, savedAt: Date())
        lock.unlock()
    }

    func cachedPositions(
        accountId: String?,
        accessToken: String
    ) -> MatchTraderPositionsResponse? {
        let accountKey = accountId?.lowercased() ?? "all"
        let key = scopedKey(
            accessToken: accessToken,
            value: accountKey
        )
        lock.lock()
        defer { lock.unlock() }
        return fresh(positions[key], lifetime: 90)
    }

    func savePositions(
        _ value: MatchTraderPositionsResponse,
        accountId: String?,
        accessToken: String
    ) {
        let accountKey = accountId?.lowercased() ?? "all"
        let key = scopedKey(
            accessToken: accessToken,
            value: accountKey
        )
        lock.lock()
        positions[key] = Timed(value: value, savedAt: Date())
        lock.unlock()
    }

    func cachedInstruments(
        accountId: String,
        accessToken: String
    ) -> MatchTraderInstrumentsResponse? {
        let key = scopedKey(
            accessToken: accessToken,
            value: accountId.lowercased()
        )
        lock.lock()
        defer { lock.unlock() }
        return fresh(
            instruments[key],
            lifetime: 600
        )
    }

    func saveInstruments(
        _ value: MatchTraderInstrumentsResponse,
        accountId: String,
        accessToken: String
    ) {
        let key = scopedKey(
            accessToken: accessToken,
            value: accountId.lowercased()
        )
        lock.lock()
        instruments[key] =
            Timed(value: value, savedAt: Date())
        lock.unlock()
    }

    func cachedSessionOpen(
        accountId: String,
        symbol: String,
        accessToken: String
    ) -> Bool? {
        guard let response = cachedInstruments(
            accountId: accountId,
            accessToken: accessToken
        ) else {
            return nil
        }

        return response.instruments?.first(where: {
            $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame
        })?.sessionOpen
    }

    func cachedQuote(
        accountId: String,
        symbol: String,
        accessToken: String
    ) -> MatchTraderLiveQuoteResponse? {
        let key = scopedKey(
            accessToken: accessToken,
            value: "\(accountId.lowercased()):\(symbol.uppercased())"
        )
        lock.lock()
        defer { lock.unlock() }
        return fresh(quotes[key], lifetime: 12)
    }

    func saveQuote(
        _ value: MatchTraderLiveQuoteResponse,
        accountId: String,
        symbol: String,
        accessToken: String
    ) {
        let key = scopedKey(
            accessToken: accessToken,
            value: "\(accountId.lowercased()):\(symbol.uppercased())"
        )
        lock.lock()
        quotes[key] = Timed(value: value, savedAt: Date())
        lock.unlock()
    }

    func invalidate(
        accessToken: String,
        accountId: String? = nil
    ) {
        let owner = ownerKey(accessToken: accessToken)
        lock.lock()
        defer { lock.unlock() }

        if let accountId {
            let clean = accountId.lowercased()
            positions.removeValue(forKey: "\(owner):\(clean)")
            positions.removeValue(forKey: "\(owner):all")
            quotes = quotes.filter {
                !$0.key.hasPrefix("\(owner):\(clean):")
            }
        } else {
            health.removeValue(forKey: owner)
            positions = positions.filter {
                !$0.key.hasPrefix("\(owner):")
            }
            instruments = instruments.filter {
                !$0.key.hasPrefix("\(owner):")
            }
            quotes = quotes.filter {
                !$0.key.hasPrefix("\(owner):")
            }
        }
    }
}

extension APIService {

    func clearMatchTraderLocalCache(
        accessToken: String
    ) {
        MatchTraderAPICache.shared.invalidate(
            accessToken: accessToken
        )
    }

    // MARK: - Broker Connection Health

    func fetchBrokerConnectionHealth(
        accessToken: String
    ) async throws -> BrokerConnectionHealthResponse {
        let data = try await sendRequest(
            path: "/broker-connections/health",
            method: "GET",
            accessToken: accessToken,
            label: "fetchBrokerConnectionHealth"
        )

        return try decode(
            BrokerConnectionHealthResponse.self,
            from: data,
            label: "fetchBrokerConnectionHealth"
        )
    }

    // MARK: - Aqua Funding / Match-Trader Login

    func loginMatchTrader(
        _ payload: MatchTraderLoginRequest,
        accessToken: String
    ) async throws -> MatchTraderLoginResponse {
        let body = try encode(
            payload,
            label: "loginMatchTrader"
        )

        let data = try await sendRequest(
            path: "/match-trader/auth/login",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "loginMatchTrader"
        )

        let response = try decode(
            MatchTraderLoginResponse.self,
            from: data,
            label: "loginMatchTrader"
        )
        MatchTraderAPICache.shared.invalidate(
            accessToken: accessToken
        )
        return response
    }

    func fetchMatchTraderAuthHealth(
        accessToken: String,
        forceRefresh: Bool = false
    ) async throws -> MatchTraderAuthHealthResponse {
        if !forceRefresh,
           let cached = MatchTraderAPICache.shared.cachedHealth(
                accessToken: accessToken
           ) {
            return cached
        }

        let data = try await sendRequest(
            path: "/match-trader/auth/health",
            method: "GET",
            accessToken: accessToken,
            label: "fetchMatchTraderAuthHealth"
        )

        let response = try decode(
            MatchTraderAuthHealthResponse.self,
            from: data,
            label: "fetchMatchTraderAuthHealth"
        )
        MatchTraderAPICache.shared.saveHealth(
            response,
            accessToken: accessToken
        )
        return response
    }

    func discoverMatchTraderAccounts(
        connectionId: String?,
        accessToken: String
    ) async throws -> MatchTraderLoginResponse {
        let body = try encode(
            MatchTraderRefreshRequest(
                connectionId: connectionId,
                discoverAccounts: true
            ),
            label: "discoverMatchTraderAccounts"
        )

        let data = try await sendRequest(
            path: "/match-trader/auth/refresh",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "discoverMatchTraderAccounts"
        )

        let response = try decode(
            MatchTraderLoginResponse.self,
            from: data,
            label: "discoverMatchTraderAccounts"
        )
        MatchTraderAPICache.shared.invalidate(
            accessToken: accessToken
        )
        return response
    }

    // MARK: - Match-Trader Backend Session Sync

    func syncMatchTraderAccounts(
        _ payload: MatchTraderSyncRequest,
        accessToken: String
    ) async throws -> BrokerSyncResponse {
        let body = try encode(
            payload,
            label: "syncMatchTraderAccounts"
        )

        let data = try await sendRequest(
            path: "/match-trader/accounts/sync",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "syncMatchTraderAccounts"
        )

        return try decode(
            BrokerSyncResponse.self,
            from: data,
            label: "syncMatchTraderAccounts"
        )
    }

    func syncMatchTraderPositions(
        _ payload: MatchTraderSyncRequest,
        accessToken: String
    ) async throws -> BrokerSyncResponse {
        let body = try encode(
            payload,
            label: "syncMatchTraderPositions"
        )

        let data = try await sendRequest(
            path: "/match-trader/positions/sync",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "syncMatchTraderPositions"
        )

        return try decode(
            BrokerSyncResponse.self,
            from: data,
            label: "syncMatchTraderPositions"
        )
    }

    func fetchMatchTraderPositions(
        _ payload: MatchTraderSyncRequest,
        accessToken: String,
        forceRefresh: Bool = false
    ) async throws -> MatchTraderPositionsResponse {
        if !forceRefresh,
           let cached = MatchTraderAPICache.shared.cachedPositions(
                accountId: payload.accountId,
                accessToken: accessToken
           ) {
            return cached
        }

        let body = try encode(
            payload,
            label: "fetchMatchTraderPositions"
        )

        let data = try await sendRequest(
            path: "/match-trader/positions",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "fetchMatchTraderPositions"
        )

        let response = try decode(
            MatchTraderPositionsResponse.self,
            from: data,
            label: "fetchMatchTraderPositions"
        )
        MatchTraderAPICache.shared.savePositions(
            response,
            accountId: payload.accountId,
            accessToken: accessToken
        )
        return response
    }

    func fetchMatchTraderInstruments(
        accountId: String,
        accessToken: String,
        forceRefresh: Bool = false
    ) async throws -> MatchTraderInstrumentsResponse {
        if !forceRefresh,
           let cached = MatchTraderAPICache.shared.cachedInstruments(
                accountId: accountId,
                accessToken: accessToken
           ) {
            return cached
        }

        let body = try encode(
            MatchTraderSyncRequest(
                broker: "Aqua Funding",
                accountId: accountId,
                symbols: []
            ),
            label: "fetchMatchTraderInstruments"
        )

        let data = try await sendRequest(
            path: "/match-trader/instruments",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "fetchMatchTraderInstruments"
        )

        let response = try decode(
            MatchTraderInstrumentsResponse.self,
            from: data,
            label: "fetchMatchTraderInstruments"
        )
        MatchTraderAPICache.shared.saveInstruments(
            response,
            accountId: accountId,
            accessToken: accessToken
        )
        return response
    }

    func cachedMatchTraderSessionOpen(
        accountId: String,
        symbol: String,
        accessToken: String
    ) -> Bool? {
        MatchTraderAPICache.shared.cachedSessionOpen(
            accountId: accountId,
            symbol: symbol,
            accessToken: accessToken
        )
    }

    func fetchMatchTraderQuote(
        accountId: String,
        symbol: String,
        accessToken: String,
        forceRefresh: Bool = false
    ) async throws -> MatchTraderLiveQuoteResponse {
        if !forceRefresh,
           let cached = MatchTraderAPICache.shared.cachedQuote(
                accountId: accountId,
                symbol: symbol,
                accessToken: accessToken
           ) {
            return cached
        }

        let body = try encode(
            MatchTraderLiveQuoteRequest(
                broker: "Aqua Funding",
                accountId: accountId,
                symbol: symbol
            ),
            label: "fetchMatchTraderQuote"
        )

        let data = try await sendRequest(
            path: "/match-trader/quote",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "fetchMatchTraderQuote"
        )

        let response = try decode(
            MatchTraderLiveQuoteResponse.self,
            from: data,
            label: "fetchMatchTraderQuote"
        )
        MatchTraderAPICache.shared.saveQuote(
            response,
            accountId: accountId,
            symbol: symbol,
            accessToken: accessToken
        )
        return response
    }

    func manageMatchTraderPosition(
        _ payload: MatchTraderPositionManagementRequest,
        accessToken: String
    ) async throws -> MatchTraderPositionManagementResponse {
        let body = try encode(
            payload,
            label: "manageMatchTraderPosition"
        )

        let data = try await sendRequest(
            path: "/match-trader/positions/manage",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "manageMatchTraderPosition"
        )

        let response = try decode(
            MatchTraderPositionManagementResponse.self,
            from: data,
            label: "manageMatchTraderPosition"
        )
        MatchTraderAPICache.shared.invalidate(
            accessToken: accessToken,
            accountId: payload.accountId
        )
        return response
    }

    func openMatchTraderMarketPosition(
        _ payload: MatchTraderMarketEntryRequest,
        accessToken: String
    ) async throws -> MatchTraderMarketEntryResponse {
        let body = try encode(
            payload,
            label: "openMatchTraderMarketPosition"
        )

        let data = try await sendRequest(
            path: "/match-trader/positions/open",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "openMatchTraderMarketPosition"
        )

        let response = try decode(
            MatchTraderMarketEntryResponse.self,
            from: data,
            label: "openMatchTraderMarketPosition"
        )
        MatchTraderAPICache.shared.invalidate(
            accessToken: accessToken,
            accountId: payload.accountId
        )
        return response
    }

    func clearAllBackendTrades(
        accessToken: String
    ) async throws -> BackendTradeClearResponse {
        let body = try encode(
            BackendTradeClearRequest(
                confirmation: "CLEAR ALL BACKEND TRADES"
            ),
            label: "clearAllBackendTrades"
        )

        let data = try await sendRequest(
            path: "/trades/clear-backend-trades",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "clearAllBackendTrades"
        )

        return try decode(
            BackendTradeClearResponse.self,
            from: data,
            label: "clearAllBackendTrades"
        )
    }

    func fullSyncMatchTrader(
        _ payload: MatchTraderSyncRequest,
        accessToken: String
    ) async throws -> BrokerSyncResponse {
        let body = try encode(
            payload,
            label: "fullSyncMatchTrader"
        )

        let data = try await sendRequest(
            path: "/match-trader/sync",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "fullSyncMatchTrader"
        )

        return try decode(
            BrokerSyncResponse.self,
            from: data,
            label: "fullSyncMatchTrader"
        )
    }

    // MARK: - IBKR Sync

    func fetchIBKRHealth(
        accessToken: String
    ) async throws -> IBKRHealthResponse {
        let data = try await sendRequest(
            path: "/ibkr/health",
            method: "GET",
            accessToken: accessToken,
            label: "fetchIBKRHealth"
        )

        return try decode(
            IBKRHealthResponse.self,
            from: data,
            label: "fetchIBKRHealth"
        )
    }

    func syncIBKRAccounts(
        accessToken: String
    ) async throws -> BrokerSyncResponse {
        let data = try await sendRequest(
            path: "/ibkr/accounts/sync",
            method: "POST",
            accessToken: accessToken,
            label: "syncIBKRAccounts"
        )

        return try decode(
            BrokerSyncResponse.self,
            from: data,
            label: "syncIBKRAccounts"
        )
    }

    func syncIBKRPositions(
        accessToken: String
    ) async throws -> BrokerSyncResponse {
        let data = try await sendRequest(
            path: "/ibkr/positions/sync",
            method: "POST",
            accessToken: accessToken,
            label: "syncIBKRPositions"
        )

        return try decode(
            BrokerSyncResponse.self,
            from: data,
            label: "syncIBKRPositions"
        )
    }

    func fullSyncIBKR(
        accessToken: String
    ) async throws -> BrokerSyncResponse {
        let data = try await sendRequest(
            path: "/ibkr/sync",
            method: "POST",
            accessToken: accessToken,
            label: "fullSyncIBKR"
        )

        return try decode(
            BrokerSyncResponse.self,
            from: data,
            label: "fullSyncIBKR"
        )
    }

    // MARK: - Local Encoding

    private func encode<T: Encodable>(
        _ value: T,
        label: String
    ) throws -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            throw BrokerSyncAPIError.encodingFailed(
                label: label,
                underlying: error
            )
        }
    }

    // MARK: - Local Decoding

    private func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        label: String
    ) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            let responseBody = String(
                data: data,
                encoding: .utf8
            ) ?? "Unreadable response body"

            throw BrokerSyncAPIError.decodingFailed(
                label: label,
                responseBody: responseBody,
                underlying: error
            )
        }
    }
}

// MARK: - Broker Sync API Errors

private enum BrokerSyncAPIError: LocalizedError {
    case encodingFailed(
        label: String,
        underlying: Error
    )

    case decodingFailed(
        label: String,
        responseBody: String,
        underlying: Error
    )

    var errorDescription: String? {
        switch self {
        case .encodingFailed(
            let label,
            let underlying
        ):
            return "\(label) could not encode the request: \(underlying.localizedDescription)"

        case .decodingFailed(
            let label,
            let responseBody,
            let underlying
        ):
            return """
            \(label) could not decode the backend response.
            Decoder error: \(underlying.localizedDescription)
            Response body: \(responseBody)
            """
        }
    }
}
