import Foundation

/// No URL, nonce, response body, or credential is logged by this transport.
private final class IBKRLoopbackSession: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    func send(_ request: URLRequest) async throws -> Data {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.urlCache = nil
        config.connectionProxyDictionary = [:]
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              data.count <= 2048 else { throw IBKREnrollmentError.invalidReceiver }
        return data
    }
}

private actor IBKREnrollmentAttempt {
    private var busy = false
    private var uncertain = false
    private var finished = false
    private var pending: IBKRMachineEnrollment?
    private var description: IBKREnrollmentDescription?

    func complete(receiver: IBKRLocalReceiver, expected: IBKREnrollmentDescription,
                  create: (IBKREnrollmentDescription) async throws -> IBKRMachineEnrollment) async throws -> String {
        guard !busy else { throw IBKREnrollmentError.busy }
        guard !finished else { throw IBKREnrollmentError.finished }
        guard !uncertain else { throw IBKREnrollmentError.uncertainEnrollment }
        busy = true
        defer { busy = false }
        do {
            let data = try await IBKRLoopbackSession().send(receiver.request())
            let actual = try JSONDecoder().decode(IBKREnrollmentDescription.self, from: data)
            try actual.validate()
            guard actual == expected, description == nil || description == actual else {
                throw IBKREnrollmentError.invalidReceiver
            }
        } catch { throw IBKREnrollmentError.invalidReceiver }
        if pending == nil {
            // A lost backend response must never cause an automatic second enrollment.
            uncertain = true
            description = expected
            do {
                let credential = try await create(expected)
                try credential.validate()
                pending = credential
                uncertain = false
            } catch { throw IBKREnrollmentError.uncertainEnrollment }
        }
        guard let credential = pending else { throw IBKREnrollmentError.uncertainEnrollment }
        do {
            let data = try await IBKRLoopbackSession().send(receiver.request(credential: credential))
            let acknowledgement = try JSONDecoder().decode([String: Bool].self, from: data)
            guard acknowledgement["accepted"] == true else { throw IBKREnrollmentError.deliveryPending }
        } catch { throw IBKREnrollmentError.deliveryPending }
        pending = nil
        finished = true
        return credential.connection_id
    }
}

extension APIService {
    private static let ibkrEnrollmentAttempt = IBKREnrollmentAttempt()

    static var supportsLocalIBKREnrollment: Bool {
        #if DEBUG && (targetEnvironment(simulator) || os(macOS))
        return true
        #else
        return false
        #endif
    }

    /// Credentials stay inside the existing coordinator and API layer, never SwiftUI.
    private func ibkrEnrollmentToken() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            AuthSessionCoordinator.shared.restore(minTTL: 300) { result in
                switch result {
                case .success(let credentials): continuation.resume(returning: credentials.accessToken)
                case .failure: continuation.resume(throwing: IBKREnrollmentError.ownerRequired)
                }
            }
        }
    }

    func canEnrollLocalIBKR() async -> Bool {
        guard Self.supportsLocalIBKREnrollment else { return false }
        do {
            let token = try await ibkrEnrollmentToken()
            let data = try await sendRequest(path: "/ibkr/enrollment-access", method: "GET",
                                             accessToken: token, label: "ibkrEnrollmentAccess")
            return try JSONDecoder().decode([String: Bool].self, from: data)["can_enroll"] == true
        } catch { return false }
    }

    func reviewLocalIBKREnrollment(url: String) async throws -> IBKREnrollmentDescription {
        guard await canEnrollLocalIBKR() else { throw IBKREnrollmentError.ownerRequired }
        do {
            let receiver = try IBKRLocalReceiver(url)
            let data = try await IBKRLoopbackSession().send(receiver.request())
            let description = try JSONDecoder().decode(IBKREnrollmentDescription.self, from: data)
            try description.validate()
            return description
        } catch { throw IBKREnrollmentError.invalidReceiver }
    }

    func completeLocalIBKREnrollment(url: String, expected: IBKREnrollmentDescription) async throws -> String {
        guard Self.supportsLocalIBKREnrollment else { throw IBKREnrollmentError.unsupportedPlatform }
        // Recheck server-authorized ownership even when retrying a pending delivery.
        guard await canEnrollLocalIBKR() else { throw IBKREnrollmentError.ownerRequired }
        let receiver = try IBKRLocalReceiver(url)
        return try await Self.ibkrEnrollmentAttempt.complete(receiver: receiver, expected: expected) { description in
            let token = try await self.ibkrEnrollmentToken()
            let data = try await self.sendRequest(path: "/ibkr/connections", method: "POST", accessToken: token,
                                                   body: JSONEncoder().encode(description), label: "ibkrOwnerEnrollment")
            return try JSONDecoder().decode(IBKRMachineEnrollment.self, from: data)
        }
    }
}
