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

extension APIService {

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

        return try decode(
            MatchTraderLoginResponse.self,
            from: data,
            label: "loginMatchTrader"
        )
    }

    func fetchMatchTraderAuthHealth(
        accessToken: String
    ) async throws -> MatchTraderAuthHealthResponse {
        let data = try await sendRequest(
            path: "/match-trader/auth/health",
            method: "GET",
            accessToken: accessToken,
            label: "fetchMatchTraderAuthHealth"
        )

        return try decode(
            MatchTraderAuthHealthResponse.self,
            from: data,
            label: "fetchMatchTraderAuthHealth"
        )
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
        accessToken: String
    ) async throws -> MatchTraderPositionsResponse {
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

        return try decode(
            MatchTraderPositionsResponse.self,
            from: data,
            label: "fetchMatchTraderPositions"
        )
    }

    func fetchMatchTraderInstruments(
        accountId: String,
        accessToken: String
    ) async throws -> MatchTraderInstrumentsResponse {
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

        return try decode(
            MatchTraderInstrumentsResponse.self,
            from: data,
            label: "fetchMatchTraderInstruments"
        )
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

        return try decode(
            MatchTraderPositionManagementResponse.self,
            from: data,
            label: "manageMatchTraderPosition"
        )
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

        return try decode(
            MatchTraderMarketEntryResponse.self,
            from: data,
            label: "openMatchTraderMarketPosition"
        )
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
