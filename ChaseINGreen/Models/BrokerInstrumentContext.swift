import Foundation

struct BrokerInstrumentContext: Equatable {
    let provider: String
    let connectionID: String?
    let providerPair: String?
    let canonicalSymbol: String
    let canonicalAsset: String?
    let displayName: String

    init?(
        provider: String,
        connectionID: String?,
        providerPair: String?,
        canonicalSymbol: String,
        canonicalAsset: String?,
        displayName: String
    ) {
        let cleanProvider = provider.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSymbol = canonicalSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanProvider.isEmpty, cleanProvider.lowercased() != "manual",
              !cleanSymbol.isEmpty else { return nil }
        self.provider = cleanProvider
        self.connectionID = connectionID
        self.providerPair = providerPair
        self.canonicalSymbol = cleanSymbol
        self.canonicalAsset = canonicalAsset
        self.displayName = displayName
    }

    func owns(canonicalSymbol candidate: String) -> Bool {
        canonicalSymbol.uppercased().replacingOccurrences(of: "/", with: "-")
            == candidate.uppercased().replacingOccurrences(of: "/", with: "-")
    }
}
