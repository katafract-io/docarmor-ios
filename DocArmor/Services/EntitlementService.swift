import StoreKit
import Foundation

@Observable
@MainActor
final class EntitlementService {
    // Current entitlement level
    enum Plan: Int, Comparable {
        case free = 0
        case pro = 1
        case family = 2
        static func < (lhs: Plan, rhs: Plan) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    private(set) var currentPlan: Plan = .free
    private(set) var isLoading: Bool = false
    private(set) var products: [Product] = []

    // Present Mode free-use counter (3 free uses)
    var presentModeUsesRemaining: Int {
        max(0, 3 - presentModeUseCount)
    }
    private var presentModeUseCount: Int {
        get { UserDefaults.standard.integer(forKey: "presentModeUseCount") }
        set { UserDefaults.standard.set(newValue, forKey: "presentModeUseCount") }
    }

    func recordPresentModeUse() {
        presentModeUseCount += 1
    }

    var canUsePresentMode: Bool {
        currentPlan >= .pro || presentModeUsesRemaining > 0
    }
    var canUseTravelMode: Bool { currentPlan >= .pro }
    var smartPackLimit: Int { currentPlan >= .pro ? Int.max : 1 }
    var canUseCustomPacks: Bool { currentPlan >= .pro }
    var canManageHousehold: Bool { currentPlan >= .pro }
    var hasFamilyVault: Bool { currentPlan >= .family }

    // MARK: - Product Loading

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: ProductID.all)
            // Sort by pro first, then family
            products.sort { lhs, rhs in
                let lhsPlan = ProductID.plan(for: lhs.id)
                let rhsPlan = ProductID.plan(for: rhs.id)
                if lhsPlan != rhsPlan {
                    return lhsPlan > rhsPlan
                }
                return lhs.id < rhs.id
            }
        } catch {
            // Log error but don't crash — gracefully degrade to free tier
            print("Failed to load products: \(error)")
        }
    }

    // MARK: - Purchases

    func purchase(_ product: Product) async throws -> Transaction? {
        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            // Get the verified transaction
            switch verification {
            case .verified(let transaction):
                // Grant entitlement
                await grant(entitlement: transaction)
                await transaction.finish()
                return transaction
            case .unverified:
                print("Transaction verification failed")
                return nil
            }
        case .userCancelled:
            return nil
        case .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    // MARK: - Restoration & Refresh

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                await grant(entitlement: transaction)
                await transaction.finish()
            case .unverified:
                break
            }
        }
    }

    func refreshEntitlements() async {
        isLoading = true
        defer { isLoading = false }

        var highestPlan: Plan = .free

        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                let plan = ProductID.plan(for: transaction.productID)
                if plan > highestPlan {
                    highestPlan = plan
                }
                await transaction.finish()
            case .unverified:
                break
            }
        }

        // Also check Apple Family Sharing (if any family member has an entitlement, grant it)
        // StoreKit 2 automatically includes family-shared subscriptions in currentEntitlements
        currentPlan = highestPlan
    }

    // MARK: - Transaction Listening

    func startListening() {
        Task {
            await listenForTransactions()
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            switch result {
            case .verified(let transaction):
                await grant(entitlement: transaction)
                await transaction.finish()
            case .unverified:
                break
            }
        }
    }

    // MARK: - Private Helpers

    private func grant(entitlement transaction: Transaction) async {
        let plan = ProductID.plan(for: transaction.productID)
        if plan > currentPlan {
            currentPlan = plan
        }
    }
}
