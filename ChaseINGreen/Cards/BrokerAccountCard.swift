//
//  BrokerAccountCard.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/1/26.
//



import SwiftUI

struct BrokerAccountCard: View {
    let account: BrokerAccountResponse

    private var displayName: String {
        account.accountName ?? account.accountId
    }

    private var brokerName: String {
        BrokerPreset.from(account.broker)?.displayName ?? account.broker
    }

    private var equityValue: Double? {
        account.equity ?? account.balance
    }

    private var pnlValue: Double {
        (account.dailyPnl ?? 0) + (account.unrealizedPnl ?? 0) + (account.realizedPnl ?? 0)
    }

    private var pnlTint: Color {
        pnlValue >= 0 ? .green : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(spacing: 12) {
                metric("Balance", formatMoney(account.balance))
                metric("Equity", formatMoney(equityValue))
            }

            HStack(spacing: 12) {
                metric("Daily DD Left", formatMoney(account.dailyDrawdownRemaining))
                metric("Max DD Left", formatMoney(account.maxDrawdownRemaining))
            }

            HStack(spacing: 12) {
                metric("Target Left", formatMoney(account.profitTargetRemaining ?? account.payoutTarget))
                metric("Buying Power", formatMoney(account.buyingPower))
            }

            if let notes = account.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding()
        .background(AppTheme.cardBlack)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(pnlTint.opacity(0.35), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.primaryText)

                Text(brokerName)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.softGold)

                Text(account.accountStatus ?? "active")
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatMoney(pnlValue))
                    .font(.headline.bold())
                    .foregroundStyle(pnlTint)

                Text("P/L")
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatMoney(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%@%.2f", value >= 0 ? "$" : "-$", abs(value))
    }
}
