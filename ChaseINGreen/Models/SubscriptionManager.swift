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

    let goldMonthlyID = "chaseingreen_gold_monthly"
    let goldYearlyID = "chaseingreen_gold_yearly"

    private let alternateGoldProductIDs: Set<String> = [
        "com.apldevo.chaseingreen.gold.monthly",
        "com.apldevo.chaseingreen.gold.yearly",
        "com.oes.chaseingreen.gold.monthly",
        "com.oes.chaseingreen.gold.yearly",
    ]

    private let legacyGoldEntitlementIDs: Set<String> = [
        "chaseingreen_premium_monthly",
        "chaseingreen_premium_yearly",
        "com.oes.chaseingreen.premium.monthly",
        "com.oes.chaseingreen.premium.yearly",
    ]

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var lastErrorMessage: String?

    private struct AppleSubscriptionSyncPayload: Codable {
        let productId: String?
        let transactionId: String?
        let originalTransactionId: String?
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
        Array(Set([
            goldMonthlyID,
            goldYearlyID
        ]).union(alternateGoldProductIDs)).sorted()
    }

    private var recognizedGoldEntitlementIDs: Set<String> {
        Set(productIDs)
            .union(alternateGoldProductIDs)
            .union(legacyGoldEntitlementIDs)
    }

    var premiumProducts: [Product] {
        []
    }


    var goldProducts: [Product] {
        products
            .filter { productIDs.contains($0.id) }
            .sorted { lhs, rhs in
                let lhsPeriod = lhs.subscription?.subscriptionPeriod
                let rhsPeriod = rhs.subscription?.subscriptionPeriod

                if lhsPeriod?.unit == .month && rhsPeriod?.unit == .year {
                    return true
                }

                if lhsPeriod?.unit == .year && rhsPeriod?.unit == .month {
                    return false
                }

                return lhs.price < rhs.price
            }
    }

    var hasPremium: Bool {
        hasGold
    }

    var hasGold: Bool {
        !purchasedProductIDs.isDisjoint(
            with: recognizedGoldEntitlementIDs
        )
    }

    var currentPlanName: String {
        if hasGold { return "Gold" }
        return "Free"
    }

    func loadProducts() async {
        isLoadingProducts = true
        lastErrorMessage = nil
        defer { isLoadingProducts = false }

        print("🟡 Requesting StoreKit products:")
        productIDs.forEach { print("   • \($0)") }

        do {
            let loadedProducts = try await Product.products(for: productIDs)

            print("🟢 StoreKit returned \(loadedProducts.count) products:")
            loadedProducts.forEach {
                print("   • \($0.id) — \($0.displayName) — \($0.displayPrice)")
            }

            products = loadedProducts.sorted { $0.price < $1.price }

            if products.isEmpty {
                lastErrorMessage =
                    "The App Store returned no ChaseINGreen subscription products."
            }
        } catch {
            products = []
            lastErrorMessage =
                "Could not load subscription products: \(error.localizedDescription)"

            print("❌ Failed to load products:")
            print(error)
        }
    }

    func refreshPurchasedProducts() async {
        var purchased = Set<String>()

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard recognizedGoldEntitlementIDs.contains(
                transaction.productID
            ) else { continue }

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
        var syncedActiveEntitlement = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            guard transaction.revocationDate == nil else {
                continue
            }

            guard recognizedGoldEntitlementIDs.contains(
                transaction.productID
            ) else {
                continue
            }

            syncedActiveEntitlement = true

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

        if !syncedActiveEntitlement {
            let payload = AppleSubscriptionSyncPayload(
                productId: nil,
                transactionId: nil,
                originalTransactionId: nil,
                expiresAt: nil,
                isTrial: false
            )

            do {
                let body = try JSONEncoder().encode(payload)
                _ = try await APIService.shared.sendRequest(
                    path: "/me/apple-subscription/sync",
                    method: "POST",
                    accessToken: accessToken,
                    body: body,
                    label: "clearAppleSubscription"
                )
            } catch {
                lastErrorMessage = "ChaseINGreen could not confirm the current subscription status yet."
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
