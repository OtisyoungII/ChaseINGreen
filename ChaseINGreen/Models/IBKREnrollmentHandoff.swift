import Foundation

/// Only non-Auth0 metadata and the scoped machine credential belong in this protocol.
struct IBKREnrollmentDescription: Codable, Equatable, Sendable {
    let connection_name: String
    let agent_label: String
    let ownership_type: String

    func validate() throws {
        guard (1...120).contains(connection_name.count), (1...120).contains(agent_label.count),
              ["personal", "business"].contains(ownership_type) else {
            throw IBKREnrollmentError.invalidReceiver
        }
    }
}

struct IBKRMachineEnrollment: Decodable, Sendable {
    let connection_id: String
    let agent_token: String

    func validate() throws {
        guard UUID(uuidString: connection_id) != nil,
              agent_token.range(of: "^cig_ibkr_[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil else {
            throw IBKREnrollmentError.uncertainEnrollment
        }
    }
}

struct IBKRHandoffPayload: Encodable, Sendable {
    let connection_id: String
    let agent_token: String
    let nonce: String
}

struct IBKRLocalReceiver: Sendable {
    let port: Int
    let nonce: String

    init(_ text: String) throws {
        guard let parts = URLComponents(string: text), parts.scheme == "http",
              parts.host == "127.0.0.1", parts.user == nil, parts.password == nil,
              parts.query == nil, parts.path == "/ibkr-enrollment",
              let port = parts.port, (1024...65535).contains(port),
              let nonce = parts.fragment,
              nonce.range(of: "^[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil,
              text == "http://127.0.0.1:\(port)/ibkr-enrollment#\(nonce)" else {
            throw IBKREnrollmentError.invalidReceiver
        }
        self.port = port
        self.nonce = nonce
    }

    func request(credential: IBKRMachineEnrollment? = nil) throws -> URLRequest {
        let path = credential == nil ? "prepare" : "complete"
        let url = URL(string: "http://127.0.0.1:\(port)/\(path)")!
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let credential {
            try credential.validate()
            request.httpBody = try JSONEncoder().encode(IBKRHandoffPayload(
                connection_id: credential.connection_id, agent_token: credential.agent_token, nonce: nonce
            ))
        } else {
            request.httpBody = try JSONEncoder().encode(["nonce": nonce])
        }
        return request
    }
}

enum IBKREnrollmentError: Error, LocalizedError {
    case invalidReceiver, ownerRequired, unsupportedPlatform, busy, uncertainEnrollment, deliveryPending, finished

    var errorDescription: String? {
        switch self {
        case .invalidReceiver: return "Receiver unavailable or invalid. Start the Mac helper and use its exact local URL."
        case .ownerRequired: return "Permanent-owner enrollment authorization is unavailable."
        case .unsupportedPlatform: return "Local enrollment requires a Debug build in Simulator on this Mac or the Mac app."
        case .busy: return "Enrollment is already in progress."
        case .uncertainEnrollment: return "Enrollment may have reached the backend. Check its result before starting another enrollment."
        case .deliveryPending: return "Connection created; delivery is unconfirmed. Check the helper output first. Retry delivery here with a running receiver; do not create another connection."
        case .finished: return "Enrollment was delivered. Check the Mac helper output."
        }
    }
}
