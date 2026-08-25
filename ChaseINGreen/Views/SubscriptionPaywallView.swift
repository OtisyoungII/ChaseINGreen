//
//  SubscriptionPaywallView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/24/26.
//

import SwiftUI
import StoreKit

struct SubscriptionPaywallView: View {

    let accessToken: String?

    @StateObject private var subscriptions = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var serverPlan = "free"
    @State private var serverIsAdmin = false
    @State private var serverPlanError: String?
    @State private var showingPrivacyNotice = false

    private var normalizedPlan: String {
        serverPlan.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isServerAdmin: Bool {
        serverIsAdmin || normalizedPlan == "admin"
    }

    private var hasExpandedServerAccess: Bool {
        isServerAdmin || normalizedPlan == "secret"
    }

    private var displayPlanName: String {
        if hasExpandedServerAccess { return "Gold" }
        if normalizedPlan == "gold" { return "Gold" }
        if normalizedPlan == "premium" { return "Gold" }
        return subscriptions.currentPlanName
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection

                        subscriptionOptionsSection

                        if let error = subscriptions.lastErrorMessage {
                            Text(error)
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.danger)
                        }

                        if let serverPlanError {
                            Text(serverPlanError)
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.danger)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Subscriptions")

            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif

            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    doneButton
                }
                #else
                ToolbarItem(placement: .automatic) {
                    doneButton
                }
                #endif
            }
            .task {
                await loadPaywall()
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.gold)

            Text(hasExpandedServerAccess ? "Expanded Access Active" : "ChaseINGreen Gold")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text("Choose Gold for expanded AI market tools, additional alerts, deeper analytics, and enhanced trading support.")
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.secondaryText)

            Text("Current Plan: \(displayPlanName)")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.softGold)
        }
    }

    private var subscriptionOptionsSection: some View {
        VStack(spacing: 18) {
            if subscriptions.isLoadingProducts {
                ProgressView()
                    .tint(AppTheme.gold)
                    .padding(.vertical, 30)
            } else {
                if !subscriptions.goldProducts.isEmpty {
                    sectionTitle("Gold")

                    ForEach(subscriptions.goldProducts, id: \.id) { product in
                        productCard(product)
                    }
                } else {
                    Text(
                        "Gold purchasing is temporarily unavailable from the App Store. Confirm the Gold products are active for this app and storefront, then try again."
                    )
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.danger)
                    .multilineTextAlignment(.center)

                    Button("Try Loading Products Again") {
                        Task { await subscriptions.loadProducts() }
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.gold)
                }

                restoreButton

                subscriptionDisclosure
            }
        }
    }

    private var subscriptionDisclosure: some View {
        VStack(spacing: 10) {
            Text(
                "Gold subscriptions renew automatically unless canceled at least 24 hours before the current period ends. Payment is charged to your Apple Account. Manage or cancel in your App Store subscription settings."
            )
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(AppTheme.secondaryText)

            HStack(spacing: 18) {
                Link(
                    "Terms of Use",
                    destination: URL(
                        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
                    )!
                )

                Button("Privacy Notice") {
                    showingPrivacyNotice = true
                }

                Link(
                    "Manage Subscription",
                    destination: URL(
                        string: "https://apps.apple.com/account/subscriptions"
                    )!
                )
            }
            .font(.caption.bold())
            .foregroundStyle(AppTheme.gold)
        }
        .sheet(isPresented: $showingPrivacyNotice) {
            NavigationStack {
                PrivacyNoticeView()
            }
        }
    }

    private var restoreButton: some View {
        Button {
            Task {
                await subscriptions.restorePurchases()
                await subscriptions.syncEntitlementsWithServer(accessToken: accessToken)
                await loadServerPlan()
            }
        } label: {
            Text("Restore Purchases")
                .font(.headline.bold())
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.gold)
        .background(AppTheme.cardBlack)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.gold.opacity(0.35), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var doneButton: some View {
        Button("Done") {
            dismiss()
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.gold)

            Spacer()
        }
    }

    private func productCard(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(productTitle(product))
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.primaryText)

                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Text("\(product.displayPrice) / \(productPeriod(product))")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.gold)
            }

            Button {
                Task {
                    await subscriptions.purchase(product)
                    await subscriptions.syncEntitlementsWithServer(accessToken: accessToken)
                    await loadServerPlan()
                }
            } label: {
                if subscriptions.isPurchasing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Subscribe")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.deepBlack)
            .background(AppTheme.gold)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding()
        .background(AppTheme.cardBlack)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.gold.opacity(0.35), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func productTitle(_ product: Product) -> String {
        switch product.subscription?.subscriptionPeriod.unit {
        case .month: return "Gold Monthly"
        case .year: return "Gold Yearly"
        default: return product.displayName
        }
    }

    private func productPeriod(_ product: Product) -> String {
        switch product.subscription?.subscriptionPeriod.unit {
        case .month: return "month"
        case .year: return "year"
        default: return "subscription period"
        }
    }

    private func loadPaywall() async {
        await subscriptions.loadProducts()
        await subscriptions.refreshPurchasedProducts()
        await subscriptions.syncEntitlementsWithServer(accessToken: accessToken)
        await loadServerPlan()
    }

    private func loadServerPlan() async {
        guard let accessToken else { return }

        do {
            serverPlanError = nil

            let user = try await AppRefreshCoordinator.shared
                .revalidateProfile(
                    accessToken: accessToken,
                    trigger: "subscription-sync"
                )
            serverPlan = user.plan ?? "free"
            serverIsAdmin = user.isAdmin
        } catch {
            serverPlanError = "Could not verify server plan."
        }
    }
}

private struct PrivacyNoticeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy Notice")
                        .font(.largeTitle.bold())

                    Text(
                        "ChaseINGreen uses account identity, subscription status, watchlists, broker connection metadata, trades, positions, and app activity to provide the features you request. Broker passwords and private session credentials are not displayed to other users. Trading and journal data may be used to calculate your analytics and improve your in-app decision support. ChaseINGreen does not sell personal data."
                    )

                    Text(
                        "Broker connections and market-data providers remain governed by their own terms and privacy practices. You may disconnect a broker from the app. Account deletion and support requests are handled through the app's account controls and support channel."
                    )

                }
                .padding()
            }
        }
        .navigationTitle("Privacy")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

#Preview {
    SubscriptionPaywallView(accessToken: nil)
}
