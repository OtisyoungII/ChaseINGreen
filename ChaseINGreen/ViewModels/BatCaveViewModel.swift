//
//  BatCaveViewModel.swift
//  ChaseINGreen
//
//  By: Otis Young II
// --------------------------------------------------------------
// ✅ Loads unified portfolio
// ✅ Loads selected account workspace
// ✅ Loads Portfolio AI
// ✅ Supports switching between brokers/accounts
// ✅ Designed for Bat Cave dashboard
// --------------------------------------------------------------

import Foundation
import Observation

@MainActor
@Observable
final class BatCaveViewModel {

    // MARK: - Data

    var portfolio: UnifiedPortfolioResponse?
    var selection: AccountSelectionResponse?
    var portfolioAI: PortfolioAIResponse?

    // MARK: - Current Selection

    var selectedBroker: String?
    var selectedAccountId: String?
    var selectedAccountGroup: String?

    var selectedSymbol: String = "AAPL"

    // MARK: - UI

    var isLoading = false
    var errorMessage: String?

    // MARK: - Initial Load

    func load(accessToken: String) async {

        isLoading = true
        errorMessage = nil

        do {

            async let portfolioRequest =
                APIService.shared.fetchUnifiedPortfolio(
                    accessToken: accessToken
                )

            async let selectionRequest =
                APIService.shared.selectAccountWorkspace(
                    broker: selectedBroker,
                    accountId: selectedAccountId,
                    accountGroup: selectedAccountGroup,
                    selectionMode: nil,
                    accessToken: accessToken
                )

            async let aiRequest =
                APIService.shared.fetchPortfolioAI(
                    symbol: selectedSymbol,
                    broker: selectedBroker,
                    accountId: selectedAccountId,
                    accountGroup: selectedAccountGroup,
                    selectionMode: nil,
                    accessToken: accessToken
                )

            portfolio = try await portfolioRequest
            selection = try await selectionRequest
            portfolioAI = try await aiRequest

        } catch {

            errorMessage = error.localizedDescription

            print("❌ Bat Cave Load Error")
            print(error)
        }

        isLoading = false
    }

    // MARK: - Refresh

    func refresh(accessToken: String) async {
        await load(accessToken: accessToken)
    }

    // MARK: - Select Everything

    func selectAllAccounts(
        accessToken: String
    ) async {

        selectedBroker = nil
        selectedAccountId = nil
        selectedAccountGroup = nil

        await load(accessToken: accessToken)
    }

    // MARK: - Select Broker

    func selectBroker(
        _ broker: String,
        accessToken: String
    ) async {

        selectedBroker = broker
        selectedAccountId = nil
        selectedAccountGroup = nil

        await load(accessToken: accessToken)
    }

    // MARK: - Select Account

    func selectAccount(
        _ account: UnifiedPortfolioAccount,
        accessToken: String
    ) async {

        selectedBroker = account.broker
        selectedAccountId = account.accountId
        selectedAccountGroup = account.accountGroup

        await load(accessToken: accessToken)
    }

    // MARK: - Change Symbol

    func changeSymbol(
        _ symbol: String,
        accessToken: String
    ) async {

        selectedSymbol = symbol.uppercased()

        await load(accessToken: accessToken)
    }

    // MARK: - Convenience

    var accounts: [UnifiedPortfolioAccount] {
        portfolio?.accounts ?? []
    }

    var totalEquity: String {
        portfolio?.canonicalTruth?.display("equity") ?? "Unavailable"
    }

    var totalBuyingPower: String {
        portfolio?.canonicalTruth?.display("buying_power") ?? "Unavailable"
    }

    var totalCash: String {
        portfolio?.canonicalTruth?.display("cash_balance") ?? "Unavailable"
    }

    var totalPnL: String {
        portfolio?.canonicalTruth?.display("total_pnl") ?? "Unavailable"
    }

    var portfolioHeadline: String {
        portfolio == nil ? "Portfolio unavailable" : "Current portfolio"
    }

    var portfolioSummary: String {
        "Unavailable totals need current, complete account evidence."
    }

    var portfolioTone: String {
        portfolio?.portfolioTone ?? "gray"
    }

    var aiHeadline: String {
        portfolioAI?.headline ?? ""
    }

    var aiSummary: String {
        portfolioAI?.summary ?? ""
    }

    var warnings: [String] {
        portfolioAI?.warnings ?? []
    }

    var actions: [String] {
        portfolioAI?.actions ?? []
    }

    var opportunities: [String] {
        portfolioAI?.opportunities ?? []
    }
}
