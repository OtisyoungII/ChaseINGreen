//
//  BrokerManagementPanel.swift
//  ChaseINGreen
//
//  By: Otis Young II
// --------------------------------------------------------------
// ✅ Bat Cave broker management panel
// ✅ Sync money first before Trader OS analysis
// ✅ IBKR stays separate from prop firms
// ✅ Aqua Funding uses its own Aqua / Match-Trader flow
// ✅ Trade The Pool stays separate from Aqua
// ✅ Login fields support Apple saved password/autofill behavior
// ✅ No live orders placed here
// --------------------------------------------------------------

import SwiftUI

struct BrokerManagementPanel: View {

    let selectedSymbol: String
    let accessToken: String
    let onSyncComplete: () async -> Void

    @State private var selectedConnector: BrokerConnectorTab = .ibkr

    @State private var aquaServerURL = ""
    @State private var aquaUsername = ""
    @State private var aquaPassword = ""
    @State private var aquaAccessToken = ""
    @State private var aquaRefreshToken = ""
    @State private var aquaAccountId = ""
    @State private var aquaAccountName = ""
    @State private var aquaStartingBalance = ""
    @State private var aquaDailyDrawdown = ""
    @State private var aquaMaxDrawdown = ""

    @State private var ttpServerURL = ""
    @State private var ttpUsername = ""
    @State private var ttpPassword = ""
    @State private var ttpAccessToken = ""
    @State private var ttpRefreshToken = ""
    @State private var ttpAccountId = ""
    @State private var ttpAccountName = ""
    @State private var ttpStartingBalance = ""
    @State private var ttpDailyDrawdown = ""
    @State private var ttpMaxDrawdown = ""

    @State private var isWorking = false
    @State private var ibkrStatus: ConnectionStatus = .unknown
    @State private var aquaStatus: ConnectionStatus = .unknown
    @State private var ttpStatus: ConnectionStatus = .unknown
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            connectionTabs
            activeConnectorPanel
            statusBlock
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Broker Management", systemImage: "building.columns.fill")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.softGold)

            Text("Sync accounts, equity, positions, and broker truth first. Trader OS should read synced money, not guesses.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var connectionTabs: some View {
        HStack(spacing: 8) {
            connectorTab(.ibkr, status: ibkrStatus)
            connectorTab(.aqua, status: aquaStatus)
            connectorTab(.tradeThePool, status: ttpStatus)
        }
    }

    private func connectorTab(
        _ tab: BrokerConnectorTab,
        status: ConnectionStatus
    ) -> some View {
        Button {
            selectedConnector = tab
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Circle()
                        .fill(status.color)
                        .frame(width: 9, height: 9)

                    Text(tab.shortTitle)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.primaryText)
                }

                Text(status.label)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                selectedConnector == tab
                ? AppTheme.softGold.opacity(0.16)
                : Color.secondary.opacity(0.08)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var activeConnectorPanel: some View {
        switch selectedConnector {
        case .ibkr:
            ibkrSection

        case .aqua:
            aquaSection

        case .tradeThePool:
            tradeThePoolSection
        }
    }

    private var ibkrSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            connectorHeader(
                title: "IBKR Login / Sync",
                subtitle: "IBKR may require device approval. If the backend gateway is offline, sync will fail until the IBKR session is active.",
                icon: "chart.line.uptrend.xyaxis"
            )

            HStack {
                brokerButton("Check IBKR") {
                    let health = try await APIService.shared.fetchIBKRHealth(
                        accessToken: accessToken
                    )

                    ibkrStatus = health.connected == true ? .connected : .needsLogin
                    statusMessage = health.message ?? "IBKR status checked."
                }

                brokerButton("Full IBKR Sync") {
                    let result = try await APIService.shared.fullSyncIBKR(
                        accessToken: accessToken
                    )

                    ibkrStatus = .connected
                    statusMessage = result.summary ?? "IBKR full sync complete."
                    await onSyncComplete()
                }
            }
        }
    }

    private var aquaSection: some View {
        propFirmSection(
            title: "Aqua / Match-Trader Login",
            subtitle: "Aqua Funding account access through the Match-Trader platform. Keep this separate from Trade The Pool.",
            brokerName: "Aqua Funding",
            status: $aquaStatus,
            serverURL: $aquaServerURL,
            username: $aquaUsername,
            password: $aquaPassword,
            accessTokenValue: $aquaAccessToken,
            refreshToken: $aquaRefreshToken,
            accountId: $aquaAccountId,
            accountName: $aquaAccountName,
            startingBalance: $aquaStartingBalance,
            dailyDrawdown: $aquaDailyDrawdown,
            maxDrawdown: $aquaMaxDrawdown
        )
    }

    private var tradeThePoolSection: some View {
        propFirmSection(
            title: "Trade The Pool Login",
            subtitle: "Separate company and login flow. Supports future Google login and manual login without mixing it with Aqua.",
            brokerName: "Trade The Pool",
            status: $ttpStatus,
            serverURL: $ttpServerURL,
            username: $ttpUsername,
            password: $ttpPassword,
            accessTokenValue: $ttpAccessToken,
            refreshToken: $ttpRefreshToken,
            accountId: $ttpAccountId,
            accountName: $ttpAccountName,
            startingBalance: $ttpStartingBalance,
            dailyDrawdown: $ttpDailyDrawdown,
            maxDrawdown: $ttpMaxDrawdown
        )
    }

    private func propFirmSection(
        title: String,
        subtitle: String,
        brokerName: String,
        status: Binding<ConnectionStatus>,
        serverURL: Binding<String>,
        username: Binding<String>,
        password: Binding<String>,
        accessTokenValue: Binding<String>,
        refreshToken: Binding<String>,
        accountId: Binding<String>,
        accountName: Binding<String>,
        startingBalance: Binding<String>,
        dailyDrawdown: Binding<String>,
        maxDrawdown: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            connectorHeader(
                title: title,
                subtitle: subtitle,
                icon: "shield.lefthalf.filled"
            )

            Text("Platform: Match-Trader")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)

            VStack(alignment: .leading, spacing: 8) {
                Text("Saved Login")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.primaryText)

                input("Email / Username", text: username, contentType: .username)
                secureInput("Password", text: password)

                Button {
                    statusMessage = "\(brokerName) app login flow placeholder. Next backend step: exchange credentials or OAuth for platform token."
                    status.wrappedValue = .needsToken
                } label: {
                    Label("Continue Login", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(isWorking)

                Button {
                    statusMessage = "\(brokerName) Google login placeholder. Add OAuth flow later without removing manual login."
                    status.wrappedValue = .needsToken
                } label: {
                    Label("Continue with Google", systemImage: "g.circle.fill")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Platform Token Sync")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.primaryText)

                input("Server URL", text: serverURL, contentType: .URL)
                secureInput("Access Token", text: accessTokenValue)
                secureInput("Refresh Token Optional", text: refreshToken)
                input("Account ID Optional", text: accountId)
                input("Account Name Optional", text: accountName)
                input("Starting Balance Optional", text: startingBalance)
                input("Daily Drawdown Optional", text: dailyDrawdown)
                input("Max Drawdown Optional", text: maxDrawdown)
            }

            HStack {
                brokerButton("Sync Accounts") {
                    let result = try await APIService.shared.syncMatchTraderAccounts(
                        makePayload(
                            brokerName: brokerName,
                            serverURL: serverURL.wrappedValue,
                            accessTokenValue: accessTokenValue.wrappedValue,
                            refreshToken: refreshToken.wrappedValue,
                            accountId: accountId.wrappedValue,
                            accountName: accountName.wrappedValue,
                            startingBalance: startingBalance.wrappedValue,
                            dailyDrawdown: dailyDrawdown.wrappedValue,
                            maxDrawdown: maxDrawdown.wrappedValue
                        ),
                        accessToken: accessToken
                    )

                    status.wrappedValue = .connected
                    statusMessage = result.summary ?? "\(brokerName) accounts synced."
                    await onSyncComplete()
                }

                brokerButton("Sync Positions") {
                    let result = try await APIService.shared.syncMatchTraderPositions(
                        makePayload(
                            brokerName: brokerName,
                            serverURL: serverURL.wrappedValue,
                            accessTokenValue: accessTokenValue.wrappedValue,
                            refreshToken: refreshToken.wrappedValue,
                            accountId: accountId.wrappedValue,
                            accountName: accountName.wrappedValue,
                            startingBalance: startingBalance.wrappedValue,
                            dailyDrawdown: dailyDrawdown.wrappedValue,
                            maxDrawdown: maxDrawdown.wrappedValue
                        ),
                        accessToken: accessToken
                    )

                    status.wrappedValue = .connected
                    statusMessage = result.summary ?? "\(brokerName) positions synced."
                    await onSyncComplete()
                }
            }

            brokerButton("Full \(brokerName) Sync") {
                let result = try await APIService.shared.fullSyncMatchTrader(
                    makePayload(
                        brokerName: brokerName,
                        serverURL: serverURL.wrappedValue,
                        accessTokenValue: accessTokenValue.wrappedValue,
                        refreshToken: refreshToken.wrappedValue,
                        accountId: accountId.wrappedValue,
                        accountName: accountName.wrappedValue,
                        startingBalance: startingBalance.wrappedValue,
                        dailyDrawdown: dailyDrawdown.wrappedValue,
                        maxDrawdown: maxDrawdown.wrappedValue
                    ),
                    accessToken: accessToken
                )

                status.wrappedValue = .connected
                statusMessage = result.summary ?? result.headline ?? "\(brokerName) full sync complete."
                await onSyncComplete()
            }
        }
    }

    private func makePayload(
        brokerName: String,
        serverURL: String,
        accessTokenValue: String,
        refreshToken: String,
        accountId: String,
        accountName: String,
        startingBalance: String,
        dailyDrawdown: String,
        maxDrawdown: String
    ) -> MatchTraderSyncRequest {
        MatchTraderSyncRequest(
            serverURL: serverURL,
            accessToken: accessTokenValue,
            refreshToken: refreshToken.isEmpty ? nil : refreshToken,
            tokenType: "Bearer",
            expiresAt: nil,
            broker: brokerName,
            accountLabel: accountName.isEmpty ? nil : accountName,
            accountId: accountId.isEmpty ? nil : accountId,
            accountName: accountName.isEmpty ? nil : accountName,
            startingBalance: Double(startingBalance),
            dailyDrawdownLimit: Double(dailyDrawdown),
            maxDrawdownLimit: Double(maxDrawdown),
            symbols: [selectedSymbol.uppercased()]
        )
    }

    private func connectorHeader(
        title: String,
        subtitle: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.headline.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
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
    }

    private func input(
        _ title: String,
        text: Binding<String>,
        contentType: UITextContentType? = nil
    ) -> some View {
        TextField(title, text: text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(contentType)
            .keyboardType(contentType == .URL ? .URL : .default)
            .padding()
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func secureInput(
        _ title: String,
        text: Binding<String>
    ) -> some View {
        SecureField(title, text: text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.password)
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

private enum BrokerConnectorTab: String, CaseIterable {
    case ibkr
    case aqua
    case tradeThePool

    var shortTitle: String {
        switch self {
        case .ibkr:
            return "IBKR"
        case .aqua:
            return "Aqua"
        case .tradeThePool:
            return "TTP"
        }
    }
}

private enum ConnectionStatus {
    case unknown
    case needsLogin
    case needsToken
    case connected

    var label: String {
        switch self {
        case .unknown:
            return "Not checked"
        case .needsLogin:
            return "Login needed"
        case .needsToken:
            return "Token needed"
        case .connected:
            return "Connected"
        }
    }

    var color: Color {
        switch self {
        case .unknown:
            return .gray
        case .needsLogin:
            return .orange
        case .needsToken:
            return .yellow
        case .connected:
            return .green
        }
    }
}
