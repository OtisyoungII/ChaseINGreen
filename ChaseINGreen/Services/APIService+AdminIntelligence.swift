import Foundation

extension APIService {
    func fetchTradeIntelligence(
        accessToken: String,
        demo: Bool
    ) async throws -> TradeIntelligenceResponse {
        let path = "/admin/dashboard/intelligence?demo=\(demo ? "true" : "false")"
        let data = try await sendRequest(
            path: path,
            method: "GET",
            accessToken: accessToken,
            label: "fetchTradeIntelligence"
        )
        return try JSONDecoder().decode(TradeIntelligenceResponse.self, from: data)
    }
}
