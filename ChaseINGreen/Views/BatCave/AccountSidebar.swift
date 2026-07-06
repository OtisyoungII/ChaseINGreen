//
//  AccountSidebar.swift
//  ChaseINGreen
//
//  By: Otis Young II
// --------------------------------------------------------------
// ✅ Bat Cave account sidebar
// ✅ All Accounts selector
// ✅ Broker/account cards
// ✅ Shows equity, group, broker, and risk tone
// ✅ Feeds BatCaveViewModel account switching
// --------------------------------------------------------------

import SwiftUI

struct AccountSidebar: View {

    let accounts: [UnifiedPortfolioAccount]
    let selectedAccountId: String?
    let accessToken: String

    @Bindable var vm: BatCaveViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            header

            allAccountsButton

            Divider()

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(accounts) { account in
                        accountButton(account)
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Accounts")
                .font(.headline)

            Text("\(accounts.count) connected")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var allAccountsButton: some View {
        Button {
            Task {
                await vm.selectAllAccounts(accessToken: accessToken)
            }
        } label: {
            HStack {
                Image(systemName: "square.grid.2x2.fill")

                VStack(alignment: .leading, spacing: 2) {
                    Text("All Accounts")
                        .font(.subheadline.bold())

                    Text("Unified view")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(selectedAccountId == nil ? .blue.opacity(0.16) : .ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func accountButton(_ account: UnifiedPortfolioAccount) -> some View {
        Button {
            Task {
                await vm.selectAccount(account, accessToken: accessToken)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {

                HStack {
                    Circle()
                        .fill(toneColor(account.riskTone))
                        .frame(width: 10, height: 10)

                    Text(account.accountName ?? account.accountId)
                        .font(.subheadline.bold())
                        .lineLimit(1)

                    Spacer()
                }

                HStack {
                    Text(account.broker.uppercased())
                    Spacer()
                    Text(account.accountGroup.replacingOccurrences(of: "_", with: " "))
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(account.equity, format: .currency(code: account.currency))
                    .font(.headline)
            }
            .padding()
            .background(
                selectedAccountId == account.accountId
                ? .blue.opacity(0.16)
                : .ultraThinMaterial
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func toneColor(_ tone: String) -> Color {
        switch tone.lowercased() {
        case "green":
            return .green
        case "yellow":
            return .yellow
        case "orange":
            return .orange
        case "red":
            return .red
        default:
            return .gray
        }
    }
}
