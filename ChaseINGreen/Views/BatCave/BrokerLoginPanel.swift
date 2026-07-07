//
//  BrokerLoginPanel.swift
//  ChaseINGreen
//
//  By: Otis Young II
// --------------------------------------------------------------
// ✅ Bat Cave broker login/sync panel
// ✅ IBKR health + full sync
// ✅ Match-Trader token sync
// ✅ Syncs accounts + positions into backend truth
// ✅ No live orders placed here
// --------------------------------------------------------------

import SwiftUI

struct BrokerLoginPanel: View {

    @Bindable var vm: BatCaveViewModel
    let accessToken: String

    @State private var serverURL = ""
    @State private var matchToken = ""
    @State private var refreshToken = ""
    @State private var broker = "Aqua Funding"
    @State private var accountId = ""
    @State private var accountName = ""
    @State private var startingBalance = ""
    @State private var dailyDrawdown = ""
    @State private var maxDrawdown = ""

    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            ibkrSection

            Divider()

            matchTraderSection

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var header: some View {
        Label("Broker Login & Sync", systemImage: "link.circle.fill")
            .font(.title2.bold())
    }

    private var ibkrSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("IBKR")
                .font(.headline)

            HStack {
                brokerButton("Check IBKR") {
                    let health = try await APIService.shared.fetchIBKRHealth(accessToken: accessToken)
                    statusMessage = health.message ?? "IBKR status checked."
                }

                brokerButton("Full Sync") {
                    let result = try await APIService.shared.fullSyncIBKR(accessToken: accessToken)
                    statusMessage = result.summary ?? "IBKR full sync complete."
                    await vm.refresh(accessToken: accessToken)
                }
            }
        }
    }

    private var matchTraderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Match-Trader / Aqua / TTP")
                .font(.headline)

            input("Server URL", text: $serverURL)
            input("Access Token", text: $matchToken)
            input("Refresh Token Optional", text: $refreshToken)
            input("Broker", text: $broker)
            input("Account ID Optional", text: $accountId)
            input("Account Name Optional", text: $accountName)
            input("Starting Balance Optional", text: $startingBalance)
            input("Daily Drawdown Optional", text: $dailyDrawdown)
            input("Max Drawdown Optional", text: $maxDrawdown)

            HStack {
                brokerButton("Sync Accounts") {
                    let result = try await APIService.shared.syncMatchTraderAccounts(payload, accessToken: accessToken)
                    statusMessage = result.summary ?? "Match-Trader accounts synced."
                    await vm.refresh(accessToken: accessToken)
                }

                brokerButton("Sync Positions") {
                    let result = try await APIService.shared.syncMatchTraderPositions(payload, accessToken: accessToken)
                    statusMessage = result.summary ?? "Match-Trader positions synced."
                    await vm.refresh(accessToken: accessToken)
                }
            }

            brokerButton("Full Match-Trader Sync") {
                let result = try await APIService.shared.fullSyncMatchTrader(payload, accessToken: accessToken)
                statusMessage = result.summary ?? result.headline ?? "Match-Trader full sync complete."
                await vm.refresh(accessToken: accessToken)
            }
        }
    }

    private var payload: MatchTraderSyncRequest {
        MatchTraderSyncRequest(
            serverURL: serverURL,
            accessToken: matchToken,
            refreshToken: refreshToken.isEmpty ? nil : refreshToken,
            tokenType: "Bearer",
            expiresAt: nil,
            broker: broker,
            accountLabel: accountName.isEmpty ? nil : accountName,
            accountId: accountId.isEmpty ? nil : accountId,
            accountName: accountName.isEmpty ? nil : accountName,
            startingBalance: Double(startingBalance),
            dailyDrawdownLimit: Double(dailyDrawdown),
            maxDrawdownLimit: Double(maxDrawdown),
            symbols: [vm.selectedSymbol.uppercased()]
        )
    }

    private func input(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding()
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func brokerButton(
        _ title: String,
        action: @escaping () async throws -> Void
    ) -> some View {
        Button {
            Task {
                await run(action)
            }
        } label: {
            Text(isWorking ? "Working..." : title)
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.softGold.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
    }

    private func run(_ action: () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        statusMessage = nil

        do {
            try await action()
        } catch {
            errorMessage = error.localizedDescription
        }

        isWorking = false
    }
}
