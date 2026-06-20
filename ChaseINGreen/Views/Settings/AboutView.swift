//
//  AboutView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 5/16/26.
//

import SwiftUI

struct AboutView: View {

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    Text("ChaseINGreen")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.gold)

                    Text("Version 1.0")
                        .foregroundStyle(AppTheme.secondaryText)

                    Divider()

                    section(
                        title: "What ChaseINGreen Does",
                        body: """
ChaseINGreen helps traders review market context, track trades, monitor active positions, and make more disciplined decisions.

The app is built to support better preparation before entering trades, cleaner trade tracking, and stronger risk awareness.
"""
                    )

                    Divider()

                    section(
                        title: "Access Levels",
                        body: """
Free users can view market data, charts, watchlists, and manually track trades.

Premium users can access limited AI trade reads and pre-trade context.

Gold users can unlock additional AI chart tools and reveal advanced trade context.

Internal tools are reserved for admin-approved testing and are not publicly available.
"""
                    )

                    Divider()

                    section(
                        title: "Trading Risk Notice",
                        body: """
Trading involves risk. Market conditions can change quickly, and no app, signal, chart, or AI tool can guarantee a profitable outcome.

ChaseINGreen provides educational trade context and decision-support tools. It does not place trades for you, manage your brokerage account, or guarantee results.

You remain responsible for your own entries, exits, position sizing, and risk management.
"""
                    )

                    Divider()

                    section(
                        title: "Privacy",
                        body: """
ChaseINGreen stores account, trade, and app activity information needed to provide trade tracking, analytics, monitoring, and user features.

User data is not sold to third parties.
"""
                    )

                    Divider()

                    section(
                        title: "Rules",
                        body: """
Access may be limited or removed for misuse, abuse, fraud, harassment, platform manipulation, or attempts to access restricted tools.

Some advanced features may be changed, limited, or removed as ChaseINGreen improves.
"""
                    )

                    Divider()

                    Text("© Otis Execution Systems LLC")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding()
            }
        }
        .navigationTitle("About")
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.primaryText)

            Text(body)
                .foregroundStyle(AppTheme.primaryText)
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
