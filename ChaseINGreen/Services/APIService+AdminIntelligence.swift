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

    func fetchMLLearningLab(accessToken: String, demo: Bool) async throws -> MLLearningLabResponse {
        let data = try await sendRequest(
            path: "/admin/dashboard/intelligence/ml-lab?demo=\(demo ? "true" : "false")",
            method: "GET",
            accessToken: accessToken,
            label: "fetchMLLearningLab"
        )
        return try JSONDecoder().decode(MLLearningLabResponse.self, from: data)
    }

    func startMLTraining(accessToken: String) async throws -> MLTrainingRunResponse {
        let data = try await sendRequest(
            path: "/admin/dashboard/intelligence/train",
            method: "POST",
            accessToken: accessToken,
            label: "startMLTraining"
        )
        return try JSONDecoder().decode(MLTrainingRunResponse.self, from: data)
    }
}
