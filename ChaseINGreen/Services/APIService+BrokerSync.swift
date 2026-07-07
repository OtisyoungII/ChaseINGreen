//
//  APIService+BrokerSync.swift
//  ChaseINGreen
//
//  By: Otis Young II
// --------------------------------------------------------------
// ✅ Broker login/sync API calls
// ✅ Match-Trader account + position + full sync
// ✅ IBKR health + account + position + full sync
// ✅ No live orders placed here
// --------------------------------------------------------------

import Foundation

extension APIService {

    // MARK: - Match-Trader Sync

    func syncMatchTraderAccounts(
        _ payload: MatchTraderSyncRequest,
        accessToken: String
    ) async throws -> BrokerSyncResponse {
        let body = try JSONEncoder().encode(payload)

        let data = try await sendRequest(
            path: "/match-trader/accounts/sync",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "syncMatchTraderAccounts"
        )

        return try JSONDecoder().decode(BrokerSyncResponse.self, from: data)
    }

    func syncMatchTraderPositions(
        _ payload: MatchTraderSyncRequest,
        accessToken: String
    ) async throws -> BrokerSyncResponse {
        let body = try JSONEncoder().encode(payload)

        let data = try await sendRequest(
            path: "/match-trader/positions/sync",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "syncMatchTraderPositions"
        )

        return try JSONDecoder().decode(BrokerSyncResponse.self, from: data)
    }

    func fullSyncMatchTrader(
        _ payload: MatchTraderSyncRequest,
        accessToken: String
    ) async throws -> BrokerSyncResponse {
        let body = try JSONEncoder().encode(payload)

        let data = try await sendRequest(
            path: "/match-trader/sync",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "fullSyncMatchTrader"
        )

        return try JSONDecoder().decode(BrokerSyncResponse.self, from: data)
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

        return try JSONDecoder().decode(IBKRHealthResponse.self, from: data)
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

        return try JSONDecoder().decode(BrokerSyncResponse.self, from: data)
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

        return try JSONDecoder().decode(BrokerSyncResponse.self, from: data)
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

        return try JSONDecoder().decode(BrokerSyncResponse.self, from: data)
    }
}
