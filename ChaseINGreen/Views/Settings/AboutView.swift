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

                    VStack(alignment: .leading, spacing: 10) {

                        Text("Educational Disclaimer")
                            .font(.headline)
                            .foregroundStyle(AppTheme.primaryText)

                        Text("""
ChaseINGreen provides educational insights, trade tracking, and trade management tools only.

The information shown in this application is not financial advice and does not guarantee trading outcomes or profits.

Users are responsible for their own trading decisions and risk management.
""")
                        .foregroundStyle(AppTheme.primaryText)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {

                        Text("Privacy")
                            .font(.headline)
                            .foregroundStyle(AppTheme.primaryText)

                        Text("""
ChaseINGreen stores trade and account information used to provide analytics, trade monitoring, and user features.

User data is not sold to third parties.
""")
                        .foregroundStyle(AppTheme.primaryText)
                    }

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
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
