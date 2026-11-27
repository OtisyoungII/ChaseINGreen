import Foundation

struct BrokerInstrumentContext: Equatable {
    let provider: String
    let accountID: String?
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
        displayName: String,
        accountID: String? = nil
    ) {
        let cleanProvider = provider.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSymbol = canonicalSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanProvider.isEmpty, cleanProvider.lowercased() != "manual",
              !cleanSymbol.isEmpty else { return nil }
        self.accountID = accountID
        self.provider = cleanProvider
        self.connectionID = connectionID
        self.providerPair = providerPair
        self.canonicalSymbol = cleanSymbol
        self.canonicalAsset = canonicalAsset
        self.displayName = displayName
    }

    func cacheKey(principal: String, timeframe: String = "quote") -> String {
        [principal, provider, connectionID ?? "", accountID ?? "", providerPair ?? canonicalSymbol, timeframe]
            .map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
    }

    func owns(canonicalSymbol candidate: String) -> Bool {
        canonicalSymbol.uppercased().replacingOccurrences(of: "/", with: "-")
            == candidate.uppercased().replacingOccurrences(of: "/", with: "-")
    }
}

struct BrokerContextSnapshot: Codable, Equatable {
    struct Position: Codable, Equatable {
        let signedQuantity: Double
        let entryPrice: Double?
        let marketPrice: Double?
        let marketValue: Double?
        let unrealizedPnl: Double?
        enum CodingKeys: String, CodingKey {
            case signedQuantity = "signed_quantity", entryPrice = "entry_price"
            case marketPrice = "market_price", marketValue = "market_value", unrealizedPnl = "unrealized_pnl"
        }
    }
    let broker: String
    let symbol: String
    let connectionId: String?
    let brokerAccountId: String?
    let canonicalAccountId: String?
    let instrumentId: String?
    let positions: [Position]
    let equity: Double?
    let cash: Double?
    let buyingPower: Double?
    let unrealizedPnl: Double?
    let realizedPnl: Double?
    let observedAt: String?
    let freshness: String
    let quoteProvider: String?
    let candleProvider: String?

    var isFresh: Bool { freshness == "fresh" && observedAt != nil }

    enum CodingKeys: String, CodingKey {
        case broker, symbol, positions, equity, cash, freshness
        case connectionId = "connection_id", brokerAccountId = "broker_account_id"
        case canonicalAccountId = "canonical_account_id", instrumentId = "instrument_id"
        case buyingPower = "buying_power", unrealizedPnl = "unrealized_pnl", realizedPnl = "realized_pnl"
        case observedAt = "observed_at", quoteProvider = "quote_provider", candleProvider = "candle_provider"
    }
}

/// Pure intent state: seat selection cannot produce a data request.
struct BrokerWorkspaceIntent: Equatable {
    enum Work: Equatable { case none, account, instruments, context, candles }
    private(set) var account: String?
    private(set) var instrument: String?
    private(set) var timeframe: String?
    private(set) var revision = 0
    mutating func seatSelected() -> Work { .none }
    mutating func entered(account: String) -> Work {
        if self.account != account { self.account = account; instrument = nil; timeframe = nil; revision += 1 }
        return .account
    }
    mutating func workspaceVisible() -> Work { account == nil ? .none : .instruments }
    mutating func selectInstrument(_ id: String) -> Work {
        guard account != nil, instrument != id else { return .none }
        instrument = id; timeframe = nil; revision += 1
        return .context
    }
    mutating func selectTimeframe(_ value: String) -> Work {
        guard instrument != nil, timeframe != value else { return .none }
        timeframe = value; revision += 1
        return .candles
    }
    func accepts(account: String, revision: Int) -> Bool { self.account == account && self.revision == revision }
}
