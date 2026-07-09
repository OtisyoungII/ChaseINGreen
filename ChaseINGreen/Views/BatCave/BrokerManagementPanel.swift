//
//  BrokerManagementPanel.swift
//  ChaseINGreen
//
//  By: Otis Young II
// --------------------------------------------------------------
// ✅ Bat Cave broker management panel
// ✅ Separate broker/company lanes
// ✅ Aqua Funding = user login flow through Match-Trader Platform API
// ✅ Trade The Pool = separate lane, not mixed with Aqua
// ✅ IBKR = official session / gateway lane only
// ✅ Token fields are admin/internal only
// ✅ No live orders placed here
// --------------------------------------------------------------

import SwiftUI

struct BrokerManagementPanel: View {

    let selectedSymbol: String
    let accessToken: String
    let onSyncComplete: () async -> Void

    @State private var selectedLane: BrokerLane = .aqua

    // MARK: - Aqua Login

    @State private var aquaServerURL = ""
    @State private var aquaUsername = ""
    @State private var aquaPassword = ""
    @State private var aquaAccountLabel = ""

    // MARK: - Aqua Admin Token Sync

    @State private var aquaShowAdminSync = false
    @State private var aquaAccessToken = ""
    @State private var aquaRefreshToken = ""
    @State private var aquaAccountId = ""
    @State private var aquaAccountName = ""
    @State private var aquaStartingBalance = ""
    @State private var aquaDailyDrawdown = ""
    @State private var aquaMaxDrawdown = ""

    // MARK: - TTP Login

    @State private var ttpServerURL = ""
    @State private var ttpUsername = ""
    @State private var ttpPassword = ""
    @State private var ttpAccountLabel = ""

    // MARK: - TTP Admin Token Sync

    @State private var ttpShowAdminSync = false
    @State private var ttpAccessToken = ""
    @State private var ttpRefreshToken = ""
    @State private var ttpAccountId = ""
    @State private var ttpAccountName = ""
    @State private var ttpStartingBalance = ""
    @State private var ttpDailyDrawdown = ""
    @State private var ttpMaxDrawdown = ""

    // MARK: - UI State

    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            lanePicker
            activeLane

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

            Text("Connect and sync money first: accounts, equity, positions, and broker truth before Trader OS reads the setup.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var lanePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BrokerLane.allCases) { lane in
                    Button {
                        selectedLane = lane
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(statusColor(for: lane))
                                .frame(width: 9, height: 9)

                            Text(lane.title)
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(selectedLane == lane ? AppTheme.softGold.opacity(0.18) : Color.secondary.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var activeLane: some View {
        switch selectedLane {
        case .aqua:
            aquaLane
        case .tradeThePool:
            ttpLane
        case .ibkr:
            ibkrLane
        case .webull, .fidelity, .robinhood, .tradeStation:
            comingSoonLane(selectedLane)
        }
    }

    // MARK: - IBKR

    private var ibkrLane: some View {
        brokerCard(
            title: "IBKR",
            subtitle: "IBKR requires an official approved session. ChaseINGreen should not ask for your IBKR password here.",
            systemImage: "chart.line.uptrend.xyaxis"
        ) {
            Text("For now, IBKR sync depends on an active IBKR Gateway / official session. Render cannot reach your Mac localhost session.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            HStack {
                brokerButton("Check IBKR") {
                    let health = try await APIService.shared.fetchIBKRHealth(accessToken: accessToken)
                    statusMessage = health.message ?? "IBKR status checked."
                }

                brokerButton("Try Sync") {
                    let result = try await APIService.shared.fullSyncIBKR(accessToken: accessToken)
                    statusMessage = result.summary ?? "IBKR full sync attempted."
                    await onSyncComplete()
                }
            }
        }
    }

    // MARK: - Aqua

    private var aquaLane: some View {
        brokerCard(
            title: "Aqua Funding / Match-Trader",
            subtitle: "Use your Aqua login. Match-Trader is the platform API provider behind this lane.",
            systemImage: "waveform.path.ecg"
        ) {
            credentialTextField("Aqua / Match-Trader Server URL", text: $aquaServerURL, contentType: .URL)
            credentialTextField("Username / Login", text: $aquaUsername, contentType: .username)
            secureCredentialField("Password", text: $aquaPassword)
            input("Account Label Optional", text: $aquaAccountLabel)

            HStack {
                brokerButton("Connect") {
                    let result = try await APIService.shared.loginMatchTrader(
                        MatchTraderLoginRequest(
                            serverURL: aquaServerURL,
                            login: aquaUsername,
                            password: aquaPassword,
                            broker: "Aqua Funding",
                            accountLabel: aquaAccountLabel.isEmpty ? nil : aquaAccountLabel
                        ),
                        accessToken: accessToken
                    )

                    statusMessage = result.summary ?? result.headline ?? "Aqua connected."
                    await onSyncComplete()
                }

                brokerButton("Reconnect") {
                    let result = try await APIService.shared.loginMatchTrader(
                        MatchTraderLoginRequest(
                            serverURL: aquaServerURL,
                            login: aquaUsername,
                            password: aquaPassword,
                            broker: "Aqua Funding",
                            accountLabel: aquaAccountLabel.isEmpty ? nil : aquaAccountLabel
                        ),
                        accessToken: accessToken
                    )

                    statusMessage = result.summary ?? "Aqua reconnected."
                    await onSyncComplete()
                }
            }

            adminTokenSyncBlock(
                title: "Admin/Internal Aqua Token Sync",
                isExpanded: $aquaShowAdminSync,
                accessTokenText: $aquaAccessToken,
                refreshTokenText: $aquaRefreshToken,
                accountId: $aquaAccountId,
                accountName: $aquaAccountName,
                startingBalance: $aquaStartingBalance,
                dailyDrawdown: $aquaDailyDrawdown,
                maxDrawdown: $aquaMaxDrawdown,
                syncAccountsTitle: "Sync Aqua Accounts",
                syncPositionsTitle: "Sync Aqua Positions",
                fullSyncTitle: "Full Aqua Sync",
                payload: aquaPayload
            )
        }
    }

    // MARK: - TTP

    private var ttpLane: some View {
        brokerCard(
            title: "Trade The Pool",
            subtitle: "Separate Trade The Pool login lane. Do not reuse Aqua credentials.",
            systemImage: "person.2.wave.2.fill"
        ) {
            Button {
                statusMessage = "Google login flow will be wired after backend OAuth route is ready."
            } label: {
                Label("Continue with Google", systemImage: "globe")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            credentialTextField("TTP / Match-Trader Server URL", text: $ttpServerURL, contentType: .URL)
            credentialTextField("Username / Login", text: $ttpUsername, contentType: .username)
            secureCredentialField("Password", text: $ttpPassword)
            input("Account Label Optional", text: $ttpAccountLabel)

            HStack {
                brokerButton("Connect") {
                    let result = try await APIService.shared.loginMatchTrader(
                        MatchTraderLoginRequest(
                            serverURL: ttpServerURL,
                            login: ttpUsername,
                            password: ttpPassword,
                            broker: "Trade The Pool",
                            accountLabel: ttpAccountLabel.isEmpty ? nil : ttpAccountLabel
                        ),
                        accessToken: accessToken
                    )

                    statusMessage = result.summary ?? result.headline ?? "Trade The Pool connected."
                    await onSyncComplete()
                }

                brokerButton("Reconnect") {
                    let result = try await APIService.shared.loginMatchTrader(
                        MatchTraderLoginRequest(
                            serverURL: ttpServerURL,
                            login: ttpUsername,
                            password: ttpPassword,
                            broker: "Trade The Pool",
                            accountLabel: ttpAccountLabel.isEmpty ? nil : ttpAccountLabel
                        ),
                        accessToken: accessToken
                    )

                    statusMessage = result.summary ?? "Trade The Pool reconnected."
                    await onSyncComplete()
                }
            }

            adminTokenSyncBlock(
                title: "Admin/Internal TTP Token Sync",
                isExpanded: $ttpShowAdminSync,
                accessTokenText: $ttpAccessToken,
                refreshTokenText: $ttpRefreshToken,
                accountId: $ttpAccountId,
                accountName: $ttpAccountName,
                startingBalance: $ttpStartingBalance,
                dailyDrawdown: $ttpDailyDrawdown,
                maxDrawdown: $ttpMaxDrawdown,
                syncAccountsTitle: "Sync TTP Accounts",
                syncPositionsTitle: "Sync TTP Positions",
                fullSyncTitle: "Full TTP Sync",
                payload: ttpPayload
            )
        }
    }

    // MARK: - Coming Soon

    private func comingSoonLane(_ lane: BrokerLane) -> some View {
        brokerCard(
            title: lane.title,
            subtitle: "\(lane.title) will get its own login/sync flow. Credentials stay separated by broker.",
            systemImage: lane.systemImage
        ) {
            Text("Coming soon")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.softGold)

            Text("Next step is backend adapter + health + sync routes for \(lane.title).")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    // MARK: - Admin Token Sync

    private func adminTokenSyncBlock(
        title: String,
        isExpanded: Binding<Bool>,
        accessTokenText: Binding<String>,
        refreshTokenText: Binding<String>,
        accountId: Binding<String>,
        accountName: Binding<String>,
        startingBalance: Binding<String>,
        dailyDrawdown: Binding<String>,
        maxDrawdown: Binding<String>,
        syncAccountsTitle: String,
        syncPositionsTitle: String,
        fullSyncTitle: String,
        payload: MatchTraderSyncRequest
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Internal testing only. Public users should not paste API tokens.")
                    .font(.caption)
                    .foregroundStyle(.orange)

                credentialTextField("Access Token", text: accessTokenText, contentType: .password)
                credentialTextField("Refresh Token Optional", text: refreshTokenText, contentType: .password)

                Divider()

                input("Account ID Optional", text: accountId)
                input("Account Name Optional", text: accountName)
                input("Starting Balance Optional", text: startingBalance)
                input("Daily Drawdown Optional", text: dailyDrawdown)
                input("Max Drawdown Optional", text: maxDrawdown)

                HStack {
                    brokerButton(syncAccountsTitle) {
                        let result = try await APIService.shared.syncMatchTraderAccounts(payload, accessToken: accessToken)
                        statusMessage = result.summary ?? "\(syncAccountsTitle) complete."
                        await onSyncComplete()
                    }

                    brokerButton(syncPositionsTitle) {
                        let result = try await APIService.shared.syncMatchTraderPositions(payload, accessToken: accessToken)
                        statusMessage = result.summary ?? "\(syncPositionsTitle) complete."
                        await onSyncComplete()
                    }
                }

                brokerButton(fullSyncTitle) {
                    let result = try await APIService.shared.fullSyncMatchTrader(payload, accessToken: accessToken)
                    statusMessage = result.summary ?? result.headline ?? "\(fullSyncTitle) complete."
                    await onSyncComplete()
                }
            }
            .padding(.top, 8)
        } label: {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)
        }
    }

    // MARK: - Payloads

    private var aquaPayload: MatchTraderSyncRequest {
        MatchTraderSyncRequest(
            serverURL: aquaServerURL,
            accessToken: aquaAccessToken,
            refreshToken: aquaRefreshToken.isEmpty ? nil : aquaRefreshToken,
            tokenType: "Bearer",
            expiresAt: nil,
            broker: "Aqua Funding",
            accountLabel: aquaAccountLabel.isEmpty ? nil : aquaAccountLabel,
            accountId: aquaAccountId.isEmpty ? nil : aquaAccountId,
            accountName: aquaAccountName.isEmpty ? nil : aquaAccountName,
            startingBalance: Double(aquaStartingBalance),
            dailyDrawdownLimit: Double(aquaDailyDrawdown),
            maxDrawdownLimit: Double(aquaMaxDrawdown),
            symbols: [selectedSymbol.uppercased()]
        )
    }

    private var ttpPayload: MatchTraderSyncRequest {
        MatchTraderSyncRequest(
            serverURL: ttpServerURL,
            accessToken: ttpAccessToken,
            refreshToken: ttpRefreshToken.isEmpty ? nil : ttpRefreshToken,
            tokenType: "Bearer",
            expiresAt: nil,
            broker: "Trade The Pool",
            accountLabel: ttpAccountLabel.isEmpty ? nil : ttpAccountLabel,
            accountId: ttpAccountId.isEmpty ? nil : ttpAccountId,
            accountName: ttpAccountName.isEmpty ? nil : ttpAccountName,
            startingBalance: Double(ttpStartingBalance),
            dailyDrawdownLimit: Double(ttpDailyDrawdown),
            maxDrawdownLimit: Double(ttpMaxDrawdown),
            symbols: [selectedSymbol.uppercased()]
        )
    }

    // MARK: - UI Helpers

    private func brokerCard<Content: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            content()
        }
        .padding()
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func input(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding()
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func credentialTextField(
        _ title: String,
        text: Binding<String>,
        contentType: UITextContentType?
    ) -> some View {
        TextField(title, text: text)
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding()
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func secureCredentialField(
        _ title: String,
        text: Binding<String>
    ) -> some View {
        SecureField(title, text: text)
            .textContentType(.password)
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

    private func statusColor(for lane: BrokerLane) -> Color {
        switch lane {
        case .aqua:
            return .yellow
        case .ibkr:
            return .yellow
        case .tradeThePool:
            return .yellow
        case .webull, .fidelity, .robinhood, .tradeStation:
            return .gray
        }
    }
}

private enum BrokerLane: String, CaseIterable, Identifiable {
    case aqua
    case tradeThePool
    case ibkr
    case webull
    case fidelity
    case robinhood
    case tradeStation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aqua: return "Aqua"
        case .tradeThePool: return "TTP"
        case .ibkr: return "IBKR"
        case .webull: return "Webull"
        case .fidelity: return "Fidelity"
        case .robinhood: return "Robinhood"
        case .tradeStation: return "TradeStation"
        }
    }

    var systemImage: String {
        switch self {
        case .aqua: return "waveform.path.ecg"
        case .tradeThePool: return "person.2.wave.2.fill"
        case .ibkr: return "chart.line.uptrend.xyaxis"
        case .webull: return "chart.bar.xaxis"
        case .fidelity: return "building.columns.fill"
        case .robinhood: return "leaf.fill"
        case .tradeStation: return "desktopcomputer"
        }
    }
}
