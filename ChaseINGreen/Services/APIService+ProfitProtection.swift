import Foundation

extension APIService {
    func fetchProfitProtectionRecommendation(
        trade: LoggedTradeResponse,
        accessToken: String
    ) async throws -> ProfitProtectionRecommendationResponse {
        let request = ProfitProtectionRecommendationRequest(
            tradeId: trade.id,
            currentPrice: trade.currentPrice,
            currentPnl: trade.openPnl,
            peakProfit: nil
        )
        let data = try await sendRequest(
            path: "/profit-protection/recommendation",
            method: "POST",
            accessToken: accessToken,
            body: try JSONEncoder().encode(request),
            label: "fetchProfitProtectionRecommendation"
        )
        return try JSONDecoder().decode(ProfitProtectionRecommendationResponse.self, from: data)
    }

    func recordProfitProtectionResponse(
        eventId: UUID,
        response: String,
        accessToken: String
    ) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["response": response])
        _ = try await sendRequest(
            path: "/profit-protection/\(eventId.uuidString)/response",
            method: "POST",
            accessToken: accessToken,
            body: body,
            label: "recordProfitProtectionResponse"
        )
    }

    func fetchProfitProtectionAdminStatistics(accessToken: String) async throws -> ProfitProtectionAdminStatistics {
        let data = try await sendRequest(
            path: "/profit-protection/admin/statistics",
            method: "GET",
            accessToken: accessToken,
            label: "fetchProfitProtectionAdminStatistics"
        )
        return try JSONDecoder().decode(ProfitProtectionAdminStatistics.self, from: data)
    }
}
