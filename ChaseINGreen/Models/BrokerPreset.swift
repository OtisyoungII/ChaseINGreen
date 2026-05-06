//
//  BrokerPreset.swift
//  ChaseINGreen
//

import Foundation

enum BrokerPreset: String, CaseIterable, Identifiable {
    case aquaFunding = "Aqua Funding"
    case tradeThePool = "Trade The Pool"
    case ibkr = "IBKR"
    case fidelity = "Fidelity"
    case robinhood = "Robinhood"
    case webull = "Webull"
    case coinbase = "Coinbase"
    case kraken = "Kraken"
    case cryptoDotCom = "Crypto.com"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var accountType: String {
        switch self {
        case .aquaFunding, .tradeThePool:
            return "prop_firm"
        case .coinbase, .kraken, .cryptoDotCom:
            return "crypto"
        case .ibkr, .fidelity, .robinhood, .webull:
            return "brokerage"
        }
    }

    var integrationStatus: String {
        switch self {
        case .ibkr:
            return "API available"
        case .webull:
            return "OpenAPI available"
        case .coinbase:
            return "Advanced Trade API available"
        case .kraken:
            return "REST/WebSocket API available"
        case .cryptoDotCom:
            return "Exchange REST/WebSocket API available"
        case .robinhood:
            return "Crypto API available"
        case .fidelity:
            return "Limited/partner APIs"
        case .aquaFunding, .tradeThePool:
            return "Manual / platform bridge"
        }
    }

    var supportsBrokerSync: Bool {
        switch self {
        case .ibkr, .webull, .coinbase, .kraken, .cryptoDotCom, .robinhood:
            return true
        case .aquaFunding, .tradeThePool, .fidelity:
            return false
        }
    }

    static func from(_ raw: String?) -> BrokerPreset? {
        guard let raw else { return nil }

        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return allCases.first {
            $0.rawValue.lowercased() == cleaned
        }
    }
}
