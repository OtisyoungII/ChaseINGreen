//
//  BrokerManagementPanel.swift
//  ChaseINGreen
//
//  By: Otis Young II
// --------------------------------------------------------------
// ✅ Bat Cave broker management panel
// ✅ Separate company login/sync lanes
// ✅ IBKR = brokerage lane
// ✅ Aqua Funding = Aqua / Match-Trader lane
// ✅ Trade The Pool = separate prop-firm lane
// ✅ Webull / Fidelity / Robinhood / TradeStation shown as next lanes
// ✅ Uses saved Apple credentials through normal TextField behavior
// ✅ No live orders placed here
// --------------------------------------------------------------

import SwiftUI

struct BrokerManagementPanel: View {

    let selectedSymbol: String
    let accessToken: String
    let onSyncComplete: () async -> Void

    @State private var selectedLane: BrokerLane = .aqua

    @State private var aquaServerURL = ""
    @State private var aquaAccessToken = ""
    @State private var aquaRefreshToken = ""
    @State private var aquaAccountId = ""
    @State private var aquaAccountName = ""
    @State private var aquaStartingBalance = ""
    @State private var aquaDailyDrawdown = ""
    @State private var aquaMaxDrawdown = ""

    @State private var ttpServerURL = ""
    @State private var ttpAccessToken = ""
    @State private var ttpRefreshToken = ""
    @State private var ttpAccountId = ""
    @State private var ttpAccountName = ""
    @State private var ttpStartingBalance = ""
    @State private var ttpDailyDrawdown = ""
    @State private var ttpMaxDrawdown = ""

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

            Text("Sync money first: accounts, equity, positions, and broker truth before Trader OS reads the setup.")
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

    private var ibkrLane: some View {
        brokerCard(
            title: "IBKR",
            subtitle: "Brokerage account sync. Requires active IBKR session / device approval.",
            systemImage: "chart.line.uptrend.xyaxis"
        ) {
            HStack {
                brokerButton("Check IBKR") {
                    let health = try await APIService.shared.fetchIBKRHealth(accessToken: accessToken)
                    statusMessage = health.message ?? "IBKR status checked."
                }

                brokerButton("Full Sync") {
                    let result = try await APIService.shared.fullSyncIBKR(accessToken: accessToken)
                    statusMessage = result.summary ?? "IBKR full sync complete."
                    await onSyncComplete()
                }
            }
        }
    }

    private var aquaLane: some View {
        brokerCard(
            title: "Aqua Funding / Match-Trader",
            subtitle: "Aqua Funding account lane. Match-Trader is the platform provider, not the company.",
            systemImage: "waveform.path.ecg"
        ) {
            credentialTextField("Aqua Server URL", text: $aquaServerURL, contentType: .URL)
            credentialTextField("Aqua Access Token", text: $aquaAccessToken, contentType: .password)
            credentialTextField("Refresh Token Optional", text: $aquaRefreshToken, contentType: .password)

            Divider()

            input("Account ID Optional", text: $aquaAccountId)
            input("Account Name Optional", text: $aquaAccountName)
            input("Starting Balance Optional", text: $aquaStartingBalance)
            input("Daily Drawdown Optional", text: $aquaDailyDrawdown)
            input("Max Drawdown Optional", text: $aquaMaxDrawdown)

            HStack {
                brokerButton("Sync Accounts") {
                    let result = try await APIService.shared.syncMatchTraderAccounts(aquaPayload, accessToken: accessToken)
                    statusMessage = result.summary ?? "Aqua accounts synced."
                    await onSyncComplete()
                }

                brokerButton("Sync Positions") {
                    let result = try await APIService.shared.syncMatchTraderPositions(aquaPayload, accessToken: accessToken)
                    statusMessage = result.summary ?? "Aqua positions synced."
                    await onSyncComplete()
                }
            }

            brokerButton("Full Aqua Sync") {
                let result = try await APIService.shared.fullSyncMatchTrader(aquaPayload, accessToken: accessToken)
                statusMessage = result.summary ?? result.headline ?? "Aqua full sync complete."
                await onSyncComplete()
            }
        }
    }

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

            credentialTextField("TTP Server URL", text: $ttpServerURL, contentType: .URL)
            credentialTextField("TTP Access Token", text: $ttpAccessToken, contentType: .password)
            credentialTextField("Refresh Token Optional", text: $ttpRefreshToken, contentType: .password)

            Divider()

            input("Account ID Optional", text: $ttpAccountId)
            input("Account Name Optional", text: $ttpAccountName)
            input("Starting Balance Optional", text: $ttpStartingBalance)
            input("Daily Drawdown Optional", text: $ttpDailyDrawdown)
            input("Max Drawdown Optional", text: $ttpMaxDrawdown)

            HStack {
                brokerButton("Sync Accounts") {
                    let result = try await APIService.shared.syncMatchTraderAccounts(ttpPayload, accessToken: accessToken)
                    statusMessage = result.summary ?? "Trade The Pool accounts synced."
                    await onSyncComplete()
                }

                brokerButton("Sync Positions") {
                    let result = try await APIService.shared.syncMatchTraderPositions(ttpPayload, accessToken: accessToken)
                    statusMessage = result.summary ?? "Trade The Pool positions synced."
                    await onSyncComplete()
                }
            }

            brokerButton("Full TTP Sync") {
                let result = try await APIService.shared.fullSyncMatchTrader(ttpPayload, accessToken: accessToken)
                statusMessage = result.summary ?? result.headline ?? "Trade The Pool full sync complete."
                await onSyncComplete()
            }
        }
    }

    private func comingSoonLane(_ lane: BrokerLane) -> some View {
        brokerCard(
            title: lane.title,
            subtitle: "\(lane.title) will get its own login/sync flow. It is separated now so credentials never mix with Aqua, TTP, or IBKR.",
            systemImage: lane.systemImage
        ) {
            Text("Coming soon")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.softGold)

            Text("This lane is reserved for \(lane.title). Next step is backend adapter + health + sync routes.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var aquaPayload: MatchTraderSyncRequest {
        MatchTraderSyncRequest(
            serverURL: aquaServerURL,
            accessToken: aquaAccessToken,
            refreshToken: aquaRefreshToken.isEmpty ? nil : aquaRefreshToken,
            tokenType: "Bearer",
            expiresAt: nil,
            broker: "Aqua Funding",
            accountLabel: aquaAccountName.isEmpty ? nil : aquaAccountName,
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
            accountLabel: ttpAccountName.isEmpty ? nil : ttpAccountName,
            accountId: ttpAccountId.isEmpty ? nil : ttpAccountId,
            accountName: ttpAccountName.isEmpty ? nil : ttpAccountName,
            startingBalance: Double(ttpStartingBalance),
            dailyDrawdownLimit: Double(ttpDailyDrawdown),
            maxDrawdownLimit: Double(ttpMaxDrawdown),
            symbols: [selectedSymbol.uppercased()]
        )
    }

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
        case .aqua, .ibkr:
            return .green
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
