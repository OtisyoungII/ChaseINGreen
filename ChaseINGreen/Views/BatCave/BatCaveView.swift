//
//  BatCaveView.swift
//  ChaseINGreen
//
//  By: Otis Young II
// --------------------------------------------------------------
//  BAT CAVE
//
//  ✅ Unified Portfolio
//  ✅ Brokerage + Prop + Crypto
//  ✅ AI Portfolio Overview
//  ✅ Account Switching
//  ✅ Ready for Execution Panel
// --------------------------------------------------------------

import SwiftUI

struct BatCaveView: View {

    @State private var vm = BatCaveViewModel()

    let accessToken: String

    var body: some View {

        NavigationStack {

            ScrollView {

                LazyVStack(spacing: 20) {

                    // MARK: Portfolio Summary

                    portfolioSummaryCard

                    // MARK: AI

                    portfolioAICard

                    // MARK: Accounts

                    accountList

                    // MARK: Warnings

                    if !vm.warnings.isEmpty {

                        warningCard
                    }

                    // MARK: Opportunities

                    if !vm.opportunities.isEmpty {

                        opportunityCard
                    }

                    // MARK: Actions

                    if !vm.actions.isEmpty {

                        actionCard
                    }
                }
                .padding()
            }
            .navigationTitle("Bat Cave")
            .refreshable {

                await vm.refresh(
                    accessToken: accessToken
                )
            }
            .task {

                await vm.load(
                    accessToken: accessToken
                )
            }
            .overlay {

                if vm.isLoading {

                    ProgressView()
                        .controlSize(.large)
                }
            }
        }
    }
}

// MARK: Portfolio Card

private extension BatCaveView {

    var portfolioSummaryCard: some View {

        VStack(alignment: .leading, spacing: 14) {

            Text(vm.portfolioHeadline)
                .font(.title2.bold())

            Text(vm.portfolioSummary)

            Divider()

            HStack {

                stat(
                    title: "Equity",
                    value: vm.totalEquity
                )

                Spacer()

                stat(
                    title: "Cash",
                    value: vm.totalCash
                )
            }

            HStack {

                stat(
                    title: "Buying Power",
                    value: vm.totalBuyingPower
                )

                Spacer()

                stat(
                    title: "P/L",
                    value: vm.totalPnL
                )
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    func stat(
        title: String,
        value: Double
    ) -> some View {

        VStack(alignment: .leading) {

            Text(title)
                .font(.caption)

            Text(value,
                 format: .currency(code: "USD"))
                .font(.headline.bold())
        }
    }
}

// MARK: AI

private extension BatCaveView {

    var portfolioAICard: some View {

        VStack(alignment: .leading,
               spacing: 12) {

            Label(
                "Portfolio AI",
                systemImage: "brain.head.profile"
            )
            .font(.headline)

            Text(vm.aiHeadline)
                .font(.title3.bold())

            Text(vm.aiSummary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: Accounts

private extension BatCaveView {

    var accountList: some View {

        VStack(alignment: .leading,
               spacing: 16) {

            HStack {

                Text("Connected Accounts")
                    .font(.headline)

                Spacer()

                Button("All") {

                    Task {

                        await vm.selectAllAccounts(
                            accessToken: accessToken
                        )
                    }
                }
            }

            ForEach(vm.accounts) { account in

                Button {

                    Task {

                        await vm.selectAccount(
                            account,
                            accessToken: accessToken
                        )
                    }

                } label: {

                    VStack(alignment: .leading,
                           spacing: 8) {

                        HStack {

                            Text(account.accountName ?? account.broker)
                                .font(.headline)

                            Spacer()

                            Text(account.broker)
                                .font(.caption.bold())
                        }

                        Text(account.summary)

                        HStack {

                            Text(account.balance,
                                 format: .currency(code: "USD"))

                            Spacer()

                            Text(account.totalPnl,
                                 format: .currency(code: "USD"))
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: Warnings

private extension BatCaveView {

    var warningCard: some View {

        VStack(alignment: .leading,
               spacing: 10) {

            Label(
                "Warnings",
                systemImage: "exclamationmark.triangle.fill"
            )

            ForEach(vm.warnings,
                    id: \.self) {

                Text("• \($0)")
            }
        }
        .padding()
        .background(.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: Opportunities

private extension BatCaveView {

    var opportunityCard: some View {

        VStack(alignment: .leading,
               spacing: 10) {

            Label(
                "Opportunities",
                systemImage: "sparkles"
            )

            ForEach(vm.opportunities,
                    id: \.self) {

                Text("• \($0)")
            }
        }
        .padding()
        .background(.green.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: Actions

private extension BatCaveView {

    var actionCard: some View {

        VStack(alignment: .leading,
               spacing: 10) {

            Label(
                "Suggested Actions",
                systemImage: "bolt.fill"
            )

            ForEach(vm.actions,
                    id: \.self) {

                Text("• \($0)")
            }
        }
        .padding()
        .background(.blue.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {

    BatCaveView(
        accessToken: ""
    )
}
