//
//  SubscriptionManager.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/24/26.
//

import Foundation
import StoreKit

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    let premiumMonthlyID = "chaseingreen_premium_monthly"
    let premiumYearlyID = "chaseingreen_premium_yearly"
    let goldMonthlyID = "chaseingreen_gold_monthly"
    let goldYearlyID = "chaseingreen_gold_yearly"

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var lastErrorMessage: String?

    private struct AppleSubscriptionSyncPayload: Codable {
        let productId: String
        let transactionId: String
        let originalTransactionId: String
        let expiresAt: String?
        let isTrial: Bool

        enum CodingKeys: String, CodingKey {
            case productId = "product_id"
            case transactionId = "transaction_id"
            case originalTransactionId = "original_transaction_id"
            case expiresAt = "expires_at"
            case isTrial = "is_trial"
        }
    }

    private var transactionUpdatesTask: Task<Void, Never>?

    private init() {
        transactionUpdatesTask = listenForTransactionUpdates()
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var productIDs: [String] {
        [
            goldMonthlyID,
            goldYearlyID
        ]
    }

    var premiumProducts: [Product] {
        []
    }


    var goldProducts: [Product] {
        products.filter { product in
            product.id == goldMonthlyID || product.id == goldYearlyID
        }
        .sorted { $0.price < $1.price }
    }

    var hasPremium: Bool {
        hasGold
    }

    var hasGold: Bool {
        purchasedProductIDs.contains(goldMonthlyID) ||
        purchasedProductIDs.contains(goldYearlyID)
    }

    var currentPlanName: String {
        if hasGold { return "Gold" }
        return "Free"
    }

    func loadProducts() async {
        isLoadingProducts = true
        lastErrorMessage = nil
        defer { isLoadingProducts = false }

        do {
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            lastErrorMessage = "Could not load subscription products."
            print("❌ Failed to load products: \(error.localizedDescription)")
        }
    }

    func refreshPurchasedProducts() async {
        var purchased = Set<String>()

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard productIDs.contains(transaction.productID) else { continue }

            purchased.insert(transaction.productID)
        }

        purchasedProductIDs = purchased
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        lastErrorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastErrorMessage = "Purchase could not be verified."
                    return
                }

                purchasedProductIDs.insert(transaction.productID)
                await transaction.finish()
                await refreshPurchasedProducts()

            case .userCancelled:
                break

            case .pending:
                lastErrorMessage = "Purchase is pending approval."

            @unknown default:
                lastErrorMessage = "Purchase did not complete."
            }
        } catch {
            lastErrorMessage = "Purchase failed."
            print("❌ Purchase failed: \(error.localizedDescription)")
        }
    }

    func restorePurchases() async {
        lastErrorMessage = nil

        do {
            try await AppStore.sync()
            await refreshPurchasedProducts()
        } catch {
            lastErrorMessage = "Restore failed."
            print("❌ Restore failed: \(error.localizedDescription)")
        }
    }

    func syncEntitlementsWithServer(accessToken: String?) async {
        guard let accessToken, !accessToken.isEmpty else {
            return
        }

        let formatter = ISO8601DateFormatter()

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            guard transaction.revocationDate == nil else {
                continue
            }

            guard productIDs.contains(transaction.productID) else {
                continue
            }

            let payload = AppleSubscriptionSyncPayload(
                productId: transaction.productID,
                transactionId: String(transaction.id),
                originalTransactionId: String(transaction.originalID),
                expiresAt: transaction.expirationDate.map { formatter.string(from: $0) },
                isTrial: false
            )

            do {
                let body = try JSONEncoder().encode(payload)

                _ = try await APIService.shared.sendRequest(
                    path: "/me/apple-subscription/sync",
                    method: "POST",
                    accessToken: accessToken,
                    body: body,
                    label: "syncAppleSubscription"
                )
            } catch {
                lastErrorMessage = "Subscription is active on this iPhone, but ChaseINGreen could not sync it yet."
                print("⚠️ Apple subscription sync failed: \(error.localizedDescription)")
            }
        }
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard case .verified(let transaction) = result else { continue }

                await self.refreshPurchasedProducts()
                await transaction.finish()
            }
        }
    }
}
