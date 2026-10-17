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

    let goldMonthlyID = AppleSubscriptionContract.monthlyProductID
    let goldYearlyID = AppleSubscriptionContract.yearlyProductID

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
    @Published private(set) var isRestoring = false
    @Published private(set) var lastErrorMessage: String?

    private var appAccountToken: UUID?
    private var accountGeneration: UInt64?
    private var operationGate = SubscriptionOperationGate()
    private var entitlementSyncTask: Task<Void, Never>?

    func resetForAccountChange() {
        appAccountToken = nil
        accountGeneration = nil
        purchasedProductIDs = []
        lastErrorMessage = nil
    }

    private func prepareAccount(accessToken: String) async throws {
        let generation = AuthSessionCoordinator.shared.sessionGeneration
        let data = try await APIService.shared.sendRequest(
            path: AppleSubscriptionContract.contextPath, method: "GET",
            accessToken: accessToken, label: "appleSubscriptionContext")
        let context = try JSONDecoder().decode(AppleSubscriptionContract.ContextResponse.self, from: data)
        guard AuthSessionCoordinator.shared.isCurrentSession(generation) else { throw CancellationError() }
        if appAccountToken != context.app_account_token { purchasedProductIDs = [] }
        appAccountToken = context.app_account_token
        accountGeneration = generation
    }

    private func accepts(_ transaction: Transaction) -> Bool {
        guard let generation = accountGeneration,
              AuthSessionCoordinator.shared.isCurrentSession(generation) else { return false }
        return recognizedGoldEntitlementIDs.contains(transaction.productID)
            && AppleEntitlementPolicy.accepts(
                verified: true, revoked: transaction.revocationDate != nil,
                expiration: transaction.expirationDate, transactionAccount: transaction.appAccountToken,
                signedInAccount: appAccountToken)
    }

    private var transactionUpdatesTask: Task<Void, Never>?

    private init() {
        transactionUpdatesTask = listenForTransactionUpdates()
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var productIDs: [String] {
        AppleSubscriptionContract.productIDs
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

    var missingGoldProductIDs: [String] {
        let loaded = Set(products.map(\.id))
        return productIDs.filter { !loaded.contains($0) }
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
        guard !isLoadingProducts else { return }
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

            if !missingGoldProductIDs.isEmpty {
                lastErrorMessage = "The App Store did not return all ChaseINGreen Gold subscriptions. Please try again."
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
        let generation = AuthSessionCoordinator.shared.sessionGeneration
        var purchased = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, accepts(transaction) else { continue }
            purchased.insert(transaction.productID)
        }
        guard AuthSessionCoordinator.shared.isCurrentSession(generation) else { return }
        purchasedProductIDs = purchased
    }

    func purchase(_ product: Product, accessToken: String?) async {
        guard operationGate.begin("purchase") else { return }
        isPurchasing = true
        lastErrorMessage = nil
        defer { isPurchasing = false; operationGate.finish("purchase") }

        do {
            guard let accessToken else { throw CancellationError() }
            try await prepareAccount(accessToken: accessToken)
            guard let appAccountToken else { throw CancellationError() }
            let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])

            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastErrorMessage = "Purchase could not be verified."
                    return
                }

                guard accepts(transaction) else {
                    lastErrorMessage = "Purchase needs verification for this ChaseINGreen account."
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
            lastErrorMessage = "The App Store could not complete the purchase: \(error.localizedDescription)"
            print("❌ Purchase failed: \(error.localizedDescription)")
        }
    }

    func restorePurchases() async {
        guard operationGate.begin("restore") else { return }
        isRestoring = true
        lastErrorMessage = nil
        defer { isRestoring = false; operationGate.finish("restore") }

        do {
            try await AppStore.sync()
            await refreshPurchasedProducts()
        } catch {
            lastErrorMessage = "The App Store could not restore purchases: \(error.localizedDescription)"
            print("❌ Restore failed: \(error.localizedDescription)")
        }
    }

    func syncEntitlementsWithServer(accessToken: String?) async {
        if let entitlementSyncTask {
            await entitlementSyncTask.value
            return
        }
        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.performEntitlementSync(accessToken: accessToken)
        }
        entitlementSyncTask = task
        await task.value
        entitlementSyncTask = nil
    }

    private func performEntitlementSync(accessToken: String?) async {
        guard let accessToken, !accessToken.isEmpty else {
            resetForAccountChange()
            return
        }
        let generation = AuthSessionCoordinator.shared.sessionGeneration
        do {
            try await prepareAccount(accessToken: accessToken)
            var signedTransaction: String?
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result, accepts(transaction) else { continue }
                signedTransaction = result.jwsRepresentation
                break
            }
            guard AuthSessionCoordinator.shared.isCurrentSession(generation) else { return }
            let body = try JSONEncoder().encode(AppleSubscriptionContract.SyncRequest(signed_transaction: signedTransaction))
            let data = try await APIService.shared.sendRequest(
                path: AppleSubscriptionContract.syncPath, method: "POST", accessToken: accessToken,
                body: body, label: "syncAppleSubscription")
            let response = try JSONDecoder().decode(AppleSubscriptionContract.SyncResponse.self, from: data)
            guard AuthSessionCoordinator.shared.isCurrentSession(generation) else { return }
            if !response.success {
                lastErrorMessage = "Subscription verification is temporarily unavailable. Please try again."
            } else if response.subscription.status == "sandbox_active" {
                lastErrorMessage = "Sandbox subscription verified for authorized testing."
            } else if response.subscription.status == "no_entitlement" {
                lastErrorMessage = "No active subscription was found for this ChaseINGreen account."
            } else {
                lastErrorMessage = nil
            }
            await refreshPurchasedProducts()
        } catch {
            guard AuthSessionCoordinator.shared.isCurrentSession(generation) else { return }
            purchasedProductIDs = []
            lastErrorMessage = "ChaseINGreen could not verify the subscription. Please try again."
        }
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard case .verified(let transaction) = result else { continue }

                await self.refreshPurchasedProducts()
                if let token = AuthSessionCoordinator.shared.currentAccessToken {
                    await self.syncEntitlementsWithServer(accessToken: token)
                }
                await transaction.finish()
            }
        }
    }
}
