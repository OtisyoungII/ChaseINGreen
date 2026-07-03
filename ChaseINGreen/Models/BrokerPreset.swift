//
//  BrokerPreset.swift
//  ChaseINGreen
//

import Foundation

// MARK: - Broker Account Class

enum BrokerAccountClass: String, CaseIterable, Identifiable {
    case propFirm = "prop_firm"
    case brokerage = "brokerage"
    case crypto = "crypto"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .propFirm: return "Prop Firm"
        case .brokerage: return "Brokerage"
        case .crypto: return "Crypto Exchange"
        }
    }
}

// MARK: - Cash / Margin Type

enum BrokerCashMarginType: String, CaseIterable, Identifiable {
    case cash = "Cash"
    case margin = "Margin"
    case paper = "Paper"

    var id: String { rawValue }

    static func from(_ raw: String?) -> BrokerCashMarginType {
        let cleaned = (raw ?? "")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.contains("margin") {
            return .margin
        }

        if cleaned.contains("paper") {
            return .paper
        }

        return .cash
    }
}

// MARK: - Broker Preset

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

    var apiValue: String {
        switch self {
        case .aquaFunding: return "aqua_funded"
        case .tradeThePool: return "trade_the_pool"
        case .ibkr: return "ibkr"
        case .fidelity: return "fidelity"
        case .robinhood: return "robinhood"
        case .webull: return "webull"
        case .coinbase: return "coinbase"
        case .kraken: return "kraken"
        case .cryptoDotCom: return "crypto_com"
        }
    }

    var accountClass: BrokerAccountClass {
        switch self {
        case .aquaFunding, .tradeThePool:
            return .propFirm
        case .coinbase, .kraken, .cryptoDotCom:
            return .crypto
        case .ibkr, .fidelity, .robinhood, .webull:
            return .brokerage
        }
    }

    var accountType: String {
        accountClass.rawValue
    }

    var isPropFirm: Bool {
        accountClass == .propFirm
    }

    var isBrokerage: Bool {
        accountClass == .brokerage
    }

    var isCryptoExchange: Bool {
        accountClass == .crypto
    }

    var defaultAccountMode: String {
        switch accountClass {
        case .propFirm: return "prop"
        case .brokerage: return "live"
        case .crypto: return "crypto"
        }
    }

    var defaultAccountType: String {
        switch accountClass {
        case .propFirm: return "prop_firm"
        case .brokerage: return "Cash"
        case .crypto: return "Exchange"
        }
    }

    var integrationStatus: String {
        switch self {
        case .aquaFunding:
            return "Prop firm / Match-Trader bridge"
        case .tradeThePool:
            return "Prop firm / manual bridge"
        case .ibkr:
            return "Brokerage API available"
        case .webull:
            return "Brokerage OpenAPI available"
        case .fidelity:
            return "Brokerage APIs limited / partner-based"
        case .robinhood:
            return "Brokerage / crypto API support varies"
        case .coinbase:
            return "Crypto Advanced Trade API available"
        case .kraken:
            return "Crypto REST/WebSocket API available"
        case .cryptoDotCom:
            return "Crypto Exchange REST/WebSocket API available"
        }
    }

    var supportsBrokerSync: Bool {
        switch self {
        case .aquaFunding, .ibkr, .webull, .coinbase, .kraken, .cryptoDotCom, .robinhood:
            return true
        case .tradeThePool, .fidelity:
            return false
        }
    }

    static func from(_ raw: String?) -> BrokerPreset? {
        guard let raw else { return nil }

        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        switch cleaned {
        case "aqua", "aqua_funded", "aquafunded", "aqua_funding":
            return .aquaFunding
        case "trade_the_pool", "tradethepool", "ttp":
            return .tradeThePool
        case "ibkr", "interactive_brokers", "interactive_brokers_llc":
            return .ibkr
        case "fidelity":
            return .fidelity
        case "robinhood":
            return .robinhood
        case "webull":
            return .webull
        case "coinbase":
            return .coinbase
        case "kraken":
            return .kraken
        case "crypto.com", "crypto_com", "cryptocom":
            return .cryptoDotCom
        default:
            return allCases.first {
                $0.rawValue.lowercased() == raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
        }
    }
}

// MARK: - Prop Firm Preset

enum PropFirmPreset: String, CaseIterable, Identifiable {
    case aquaFunding = "Aqua Funding"
    case tradeThePool = "Trade The Pool"
    case topstep = "Topstep"
    case apexTraderFunding = "Apex Trader Funding"
    case myFundedFutures = "MyFundedFutures"
    case fundedNext = "FundedNext"
    case ftmo = "FTMO"
    case the5ers = "The5ers"
    case other = "Other"

    var id: String { rawValue }
    var displayName: String { rawValue }

    static var currentlySupported: [PropFirmPreset] {
        [.aquaFunding, .tradeThePool]
    }

    static func from(_ raw: String?) -> PropFirmPreset {
        guard let raw else { return .other }

        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        switch cleaned {
        case "aqua", "aqua_funded", "aquafunded", "aqua_funding":
            return .aquaFunding
        case "trade_the_pool", "tradethepool", "ttp":
            return .tradeThePool
        case "topstep":
            return .topstep
        case "apex_trader_funding", "apex":
            return .apexTraderFunding
        case "myfundedfutures", "my_funded_futures":
            return .myFundedFutures
        case "fundednext", "funded_next":
            return .fundedNext
        case "ftmo":
            return .ftmo
        case "the5ers", "the_5ers":
            return .the5ers
        default:
            return .other
        }
    }
}

// MARK: - Prop Account Model Preset

enum PropAccountModelPreset: String, CaseIterable, Identifiable {
    case instant = "Instant"
    case flex = "Flex"
    case oneStep = "1 Step"
    case twoStep = "2 Step"
    case threeStep = "3 Step"
    case evaluation = "Evaluation"
    case funded = "Funded"
    case personal = "Personal"
    case paper = "Paper"
    case other = "Other"

    var id: String { rawValue }
    var displayName: String { rawValue }
}
