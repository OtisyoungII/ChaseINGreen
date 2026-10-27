import Foundation

extension APIService {
    func fetchOpportunityScreener(accessToken: String) async throws -> ScreenerResponse {
        let data = try await sendRequest(path: "/opportunity-screener", method: "GET",
            accessToken: accessToken, label: "fetchOpportunityScreener")
        return try ScreenerResponse.decode(data)
    }
}
