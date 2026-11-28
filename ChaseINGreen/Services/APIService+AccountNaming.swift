import Foundation

extension APIService {
    func renameBrokerAccount(accountId: UUID, displayName: String, accessToken: String) async throws -> BrokerAccountResponse {
        let body = try JSONEncoder().encode(["display_name": displayName])
        let data = try await sendRequest(path: "/broker-accounts/\(accountId.uuidString)/display-name",
                                        method: "PATCH", accessToken: accessToken, body: body,
                                        label: "renameBrokerAccount")
        return try JSONDecoder().decode(BrokerAccountResponse.self, from: data)
    }
}
