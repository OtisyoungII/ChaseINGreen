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

    private var normalizedPlan: String {
        serverPlan.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isServerAdmin: Bool {
        serverIsAdmin || normalizedPlan == "admin"
    }

    private var isInternalAccess: Bool {
        isServerAdmin || normalizedPlan == "secret"
    }

    private var displayPlanName: String {
        if isServerAdmin { return "Admin" }
        if normalizedPlan == "secret" { return "Secret" }
        if normalizedPlan == "gold" { return "Gold" }
        if normalizedPlan == "premium" { return "Premium" }
        return subscriptions.currentPlanName
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection

                        if isInternalAccess {
                            internalAccessCard
                        } else {
                            subscriptionOptionsSection
                        }

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
            Image(systemName: isInternalAccess ? "shield.lefthalf.filled" : "crown.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.gold)

            Text(isInternalAccess ? "Access Active" : "Upgrade ChaseINGreen")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text(isInternalAccess ? "Your account is controlled by OES server access." : "Unlock advanced AI trading tools and premium features.")
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.secondaryText)

            Text("Current Plan: \(displayPlanName)")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.softGold)
        }
    }

    private var internalAccessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isServerAdmin ? "Admin Access Active" : "Internal Access Active")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.gold)

            Text(isServerAdmin ? "This account has permanent admin access through the backend." : "This account has internal access through the backend.")
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text("Apple subscriptions do not override Admin or Secret access. Server tier wins.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding()
        .background(AppTheme.cardBlack)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.gold.opacity(0.45), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var subscriptionOptionsSection: some View {
        VStack(spacing: 18) {
            if subscriptions.isLoadingProducts {
                ProgressView()
                    .tint(AppTheme.gold)
                    .padding(.vertical, 30)
            } else {
                if !subscriptions.premiumProducts.isEmpty {
                    sectionTitle("Premium")

                    ForEach(subscriptions.premiumProducts, id: \.id) { product in
                        productCard(product)
                    }
                }

                if !subscriptions.goldProducts.isEmpty {
                    sectionTitle("Gold")

                    ForEach(subscriptions.goldProducts, id: \.id) { product in
                        productCard(product)
                    }
                }

                restoreButton
            }
        }
    }

    private var restoreButton: some View {
        Button {
            Task {
                await subscriptions.restorePurchases()
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
                    Text(product.displayName)
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.primaryText)

                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.gold)
            }

            Button {
                Task {
                    await subscriptions.purchase(product)
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

    private func loadPaywall() async {
        await subscriptions.loadProducts()
        await subscriptions.refreshPurchasedProducts()
        await loadServerPlan()
    }

    private func loadServerPlan() async {
        guard let accessToken else { return }

        do {
            serverPlanError = nil

            let user = try await APIService.shared.fetchCurrentUser(accessToken: accessToken)
            serverPlan = user.plan ?? "free"
            serverIsAdmin = user.isAdmin
        } catch {
            serverPlanError = "Could not verify server plan."
        }
    }
}

#Preview {
    SubscriptionPaywallView(accessToken: nil)
}
