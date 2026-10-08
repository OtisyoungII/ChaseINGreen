import Foundation

extension APIService {
    func fetchMarketPatterns(
        for symbol: String,
        timeframe: String,
        provider: String?,
        accessToken: String
    ) async throws -> MarketPatternResponse {
        let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        let encodedTimeframe = timeframe.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? timeframe
        var query = ["timeframe=\(encodedTimeframe)"]
        if let provider, !provider.isEmpty,
           let encoded = provider.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            query.append("provider=\(encoded)")
        }
        let data = try await sendRequest(
            path: "/market/patterns/\(encodedSymbol)?\(query.joined(separator: "&"))",
            method: "GET",
            accessToken: accessToken,
            label: "fetchMarketPatterns"
        )
        return try JSONDecoder().decode(MarketPatternResponse.self, from: data)
    }
}
