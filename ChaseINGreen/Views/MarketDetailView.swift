//
//  MarketDetailView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/12/26.
//

import SwiftUI

struct MarketDetailView: View {
    let requestSymbol: String
    let displayName: String
    let tradeSymbol: String
    let accessToken: String

    @State private var quote: QuoteResponse?
    @State private var preTradeContext: PreTradeContextResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    quoteSection
                    insightGateSection
                    preTradeSection
                }
                .padding()
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await loadMarketDetail()
        }
        .refreshable {
            await loadMarketDetail()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayName)
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text(tradeSymbol)
                .font(.headline.bold())
                .foregroundStyle(AppTheme.softGold)

            Text("Market Detail")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.secondaryText)

            if isLoading {
                ProgressView()
                    .tint(AppTheme.gold)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.danger)
            }
        }
    }

    private var quoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Live Market")

            if let quote {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(displayName)
                                .font(.title2.bold())
                                .foregroundStyle(AppTheme.primaryText)

                            Text(quote.displaySymbol)
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.softGold)

                            Text(quote.instrumentName)
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)

                            Text(quote.instrumentDetail)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.mutedText)
                        }

                        Spacer()

                        Text(formatPrice(quote.price))
                            .font(.title.bold())
                            .foregroundStyle(AppTheme.primaryText)
                    }

                    HStack {
                        Text("Change: \(formatSigned(quote.change))")
                        Spacer()
                        Text("%: \(formatSigned(quote.percentChange))")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(quoteTint(quote))

                    HStack {
                        metric("Open", formatPrice(quote.open))
                        metric("High", formatPrice(quote.high))
                        metric("Low", formatPrice(quote.low))
                    }

                    HStack {
                        metric("Prev Close", formatPrice(quote.previousClose))
                        metric("Volume", formatVolume(quote.volume))
                    }

                    Text("\(quote.priceLabel) • \(quote.freshness) • \(quote.marketState ?? "Unknown")")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding()
                .background(AppTheme.cardBlack)
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(AppTheme.cardStroke, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                AppUnavailableView(
                    title: "No Market Price",
                    systemImage: "chart.line.uptrend.xyaxis",
                    message: "Pull down to refresh this ticker."
                )
            }
        }
    }

    private var insightGateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("AI Levels")

            VStack(alignment: .leading, spacing: 8) {
                Text("Support, resistance, zones, and AI reads are premium insight tools.")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.primaryText)

                Text("Daily AI tickets should control how many symbols can unlock levels and pre-trade insight.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding()
            .background(AppTheme.cardBlack)
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppTheme.gold.opacity(0.35), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private var preTradeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("AI Pre-Trade Read")

            if let preTradeContext {
                PreTradeContextCard(
                    context: preTradeContext,
                    isLoading: isLoading,
                    errorMessage: nil
                ) {
                    Task {
                        await loadMarketDetail()
                    }
                }
            } else {
                AppUnavailableView(
                    title: "No Pre-Trade Context",
                    systemImage: "brain.head.profile",
                    message: "AI read will appear after the ticker loads."
                )
            }
        }
    }

    private func loadMarketDetail() async {
        isLoading = true
        errorMessage = nil

        do {
            quote = try await APIService.shared.fetchQuote(
                for: requestSymbol,
                accessToken: accessToken
            )

            let request = PreTradeContextRequest(symbol: requestSymbol)

            preTradeContext = try await APIService.shared.fetchPreTradeContext(
                request,
                accessToken: accessToken
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .black, design: .rounded))
            .foregroundStyle(AppTheme.softGold)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.secondaryText)

            Text(value)
                .font(.headline.bold())
                .foregroundStyle(AppTheme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatPrice(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f", value)
    }

    private func formatSigned(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%+.2f", value)
    }

    private func formatVolume(_ value: Int?) -> String {
        guard let value else { return "--" }
        return "\(value)"
    }

    private func quoteTint(_ quote: QuoteResponse) -> Color {
        guard let percentChange = quote.percentChange else {
            return AppTheme.secondaryText
        }

        if percentChange > 0 { return .green }
        if percentChange < 0 { return .red }
        return AppTheme.secondaryText
    }
}

#Preview {
    NavigationStack {
        MarketDetailView(
            requestSymbol: "TQQQ",
            displayName: "TQQQ",
            tradeSymbol: "TQQQ",
            accessToken: "dummy-access-token"
        )
    }
}
