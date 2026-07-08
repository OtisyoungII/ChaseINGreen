//
//  BrokerDiagnosticsPanel.swift
//  ChaseINGreen
//
//  By: Otis Young II
// --------------------------------------------------------------
// ✅ Broker diagnostics panel
// ✅ Tests broker health before live trading
// ✅ Reconnect/check status without forcing logout
// ✅ No live orders placed here
// --------------------------------------------------------------

import SwiftUI

struct BrokerDiagnosticsPanel: View {

    let accessToken: String
    let onRefresh: () async -> Void

    @State private var isCheckingIBKR = false
    @State private var ibkrHealth: IBKRHealthResponse?
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            ibkrDiagnostics

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
            Label("Broker Diagnostics", systemImage: "stethoscope")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.softGold)

            Text("Check broker connection health before relying on account data or Trader OS.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var ibkrDiagnostics: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("IBKR")
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.primaryText)

            detailRow("Connected", boolText(ibkrHealth?.connected))
            detailRow("Authenticated", boolText(ibkrHealth?.authenticated))
            detailRow("Status", ibkrHealth?.status ?? "Not checked")
            detailRow("Message", ibkrHealth?.message ?? "Tap Check / Reconnect")

            HStack {
                Button {
                    Task { await checkIBKR() }
                } label: {
                    Text(isCheckingIBKR ? "Checking..." : "Check IBKR")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.softGold.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(isCheckingIBKR)

                Button {
                    Task { await reconnectIBKR() }
                } label: {
                    Text("Reconnect")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(isCheckingIBKR)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func checkIBKR() async {
        isCheckingIBKR = true
        errorMessage = nil
        statusMessage = nil

        do {
            ibkrHealth = try await APIService.shared.fetchIBKRHealth(accessToken: accessToken)
            statusMessage = ibkrHealth?.message ?? "IBKR checked."
        } catch {
            errorMessage = error.localizedDescription
        }

        isCheckingIBKR = false
    }

    private func reconnectIBKR() async {
        isCheckingIBKR = true
        errorMessage = nil
        statusMessage = nil

        do {
            ibkrHealth = try await APIService.shared.fetchIBKRHealth(accessToken: accessToken)

            if ibkrHealth?.connected == true || ibkrHealth?.authenticated == true {
                _ = try await APIService.shared.fullSyncIBKR(accessToken: accessToken)
                statusMessage = "IBKR reconnected and synced."
                await onRefresh()
            } else {
                statusMessage = ibkrHealth?.message ?? "IBKR needs approval from its own app/device."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isCheckingIBKR = false
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            Spacer()

            Text(value)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.primaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private func boolText(_ value: Bool?) -> String {
        guard let value else { return "Unknown" }
        return value ? "Yes" : "No"
    }
}
