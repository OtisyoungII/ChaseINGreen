import Foundation

private final class RobinhoodNoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

extension APIService {
    /// Existing authenticated credential intake. Ephemeral transport prevents caches;
    /// rejecting redirects prevents a credential body being sent to another origin.
    @MainActor func saveRobinhoodConnection(body: Data) async throws -> Data {
        guard let base = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
              let url = URL(string: base.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/crypto-brokers/robinhood/connections"),
              url.scheme == "https", url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else {
            throw RobinhoodOnboardingError.secureTransportRequired
        }
        let token = try await AuthSessionCoordinator.shared.validAccessToken()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body
        request.timeoutInterval = 30
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration, delegate: RobinhoodNoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel(); request.httpBody = nil }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            // No response body, credential, signature, token or arbitrary error in logs/UI.
            throw URLError(.badServerResponse)
        }
        return data
    }
}
