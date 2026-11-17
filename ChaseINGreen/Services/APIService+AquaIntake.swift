import Foundation

extension APIService {
    private func aquaIntakeSession() async throws -> String {
        let token = try await AuthSessionCoordinator.shared.validAccessToken()
        let user = try await fetchCurrentUser(accessToken: token, forceRefresh: true)
        guard !user.isBanned, user.isAdmin || user.isSecret else { throw URLError(.userAuthenticationRequired) }
        return token
    }
    func aquaIntakes() async throws -> [AquaAPIIntake] {
        struct Envelope: Decodable { let intakes: [AquaAPIIntake] }
        let token = try await aquaIntakeSession()
        let data = try await sendRequest(path: "/match-trader/readonly/intakes", method: "GET", accessToken: token,
            label: "aquaIntakeStatus", allowsAuthRefresh: false)
        return try JSONDecoder().decode(Envelope.self, from: data).intakes
    }
    func saveAquaAPIKey(_ key: String, intakeID: UUID) async throws -> AquaAPIIntake {
        let token = try await aquaIntakeSession()
        let body = try JSONEncoder().encode(["intake_id": intakeID.uuidString, "token": key])
        let data = try await sendRequest(path: "/match-trader/readonly/connect", method: "POST", accessToken: token,
            body: body, label: "aquaSecureIntake", allowsAuthRefresh: false)
        return try JSONDecoder().decode(AquaAPIIntake.self, from: data)
    }
    func aquaIntakeAction(_ id: UUID, disconnect: Bool) async throws -> AquaAPIIntake {
        let token = try await aquaIntakeSession()
        let action = disconnect ? "disconnect" : "validate"
        let data = try await sendRequest(path: "/match-trader/readonly/intakes/\(id.uuidString)/\(action)",
            method: "POST", accessToken: token, label: "aquaIntakeAction", timeoutInterval: 90, allowsAuthRefresh: false)
        return try JSONDecoder().decode(AquaAPIIntake.self, from: data)
    }
}
