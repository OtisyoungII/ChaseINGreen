import Foundation

extension APIService {
    func fetchAdminOperations(accessToken: String) async throws -> AdminOperationsSnapshot {
        let data = try await sendRequest(path: "/admin/auto-trader/snapshot", method: "GET",
                                        accessToken: accessToken, label: "adminOperationsSnapshot")
        return try JSONDecoder().decode(AdminOperationsSnapshot.self, from: data)
    }
    func fetchAdminOperationsEvents(accessToken: String, cursor: String) async throws -> OperationsFeed {
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "limit", value: "30"), URLQueryItem(name: "cursor", value: cursor)]
        let data = try await sendRequest(path: "/admin/auto-trader/events?" + (components.percentEncodedQuery ?? ""),
                                        method: "GET", accessToken: accessToken, label: "adminOperationsEvents")
        return try JSONDecoder().decode(OperationsFeed.self, from: data)
    }
    func saveAdminWatch(accessToken: String, revision: Int, items: [OperationsWatch]) async throws {
        struct Item: Encodable { let id: String; let enabled: Bool; let priority: Int }
        struct Body: Encodable { let revision: Int; let instruments: [Item] }
        let body = try JSONEncoder().encode(Body(revision: revision, instruments: items.map {
            Item(id: $0.id, enabled: $0.enabled, priority: $0.priority)
        }))
        _ = try await sendRequest(path: "/admin/auto-trader/watch-universe", method: "PUT",
                                  accessToken: accessToken, body: body, label: "adminObservationPreferences")
    }
}

extension APIService {
    func fetchBrokerOperationsEvidence(accessToken: String, cursor: [String]?) async throws -> BrokerOperationsEvidence {
        var components = URLComponents()
        var query = [URLQueryItem(name: "limit", value: "30")]
        if let cursor {
            let data = try JSONEncoder().encode(cursor)
            query.append(URLQueryItem(name: "cursor", value: String(decoding: data, as: UTF8.self)))
        }
        components.queryItems = query
        let data = try await sendRequest(path: "/admin/auto-trader/broker-evidence?" + (components.percentEncodedQuery ?? ""),
                                         method: "GET", accessToken: accessToken, label: "brokerEvidence")
        return try JSONDecoder().decode(BrokerOperationsEvidence.self, from: data)
    }
}

extension APIService {
    func fetchTraderObservations(accessToken: String) async throws -> TraderObservations {
        let data = try await sendRequest(path: "/admin/auto-trader/trade-observations", method: "GET", accessToken: accessToken, label: "tradeObservations")
        return try JSONDecoder().decode(TraderObservations.self, from: data)
    }
    func recordTraderIntent(accessToken: String, observationID: String, intent: String, requestID: UUID) async throws {
        struct Body: Encodable { let observation_id, request_id, intent: String }
        let body = try JSONEncoder().encode(Body(observation_id: observationID, request_id: requestID.uuidString, intent: intent))
        _ = try await sendRequest(path: "/admin/auto-trader/control-intents", method: "POST", accessToken: accessToken, body: body, label: "auditControlIntent")
    }
}
