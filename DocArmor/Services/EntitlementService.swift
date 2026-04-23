import StoreKit
import Foundation

@Observable
@MainActor
final class EntitlementService {
    // Current entitlement level
    enum Plan: Int, Comparable {
        case free = 0
        case unlocked = 1  // Paid DocArmor $12.99 unlock
        case sovereign = 2 // Sovereign tier (Vaultyx) — full unlock + cloud backup
        static func < (lhs: Plan, rhs: Plan) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    private(set) var currentPlan: Plan = .free
    private(set) var isLoading: Bool = false
    private(set) var products: [Product] = []

    // Track whether we've checked the shared App Group for Sovereign entitlement
    private var hasCheckedSharedGroup = false

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
        currentPlan >= .unlocked || presentModeUsesRemaining > 0
    }
    var canUseTravelMode: Bool { currentPlan >= .unlocked }
    var smartPackLimit: Int { currentPlan >= .unlocked ? Int.max : 1 }
    var canUseCustomPacks: Bool { currentPlan >= .unlocked }
    var canManageHousehold: Bool { currentPlan >= .unlocked }
    var hasFamilyVault: Bool { currentPlan >= .unlocked }
    var canUseCloudBackup: Bool { currentPlan >= .sovereign }  // Sovereign-only feature

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

        // Check for own StoreKit purchases
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

        // Check shared App Group for Sovereign tier from Vaultyx
        if let sovereignPlan = checkSharedAppGroupEntitlement(), sovereignPlan > highestPlan {
            highestPlan = sovereignPlan
        }

        // Also check Apple Family Sharing (if any family member has an entitlement, grant it)
        // StoreKit 2 automatically includes family-shared subscriptions in currentEntitlements
        currentPlan = highestPlan
    }

    // MARK: - Shared App Group Check

    /// Reads Sovereign entitlement from the shared App Group `group.com.katafract.enclave`.
    /// This is written by Vaultyx after a successful Sovereign purchase.
    private func checkSharedAppGroupEntitlement() -> Plan? {
        guard let defaults = UserDefaults(suiteName: "group.com.katafract.enclave") else {
            return nil
        }

        let token = defaults.string(forKey: "enclave.sigil.token") ?? ""
        let plan  = (defaults.string(forKey: "enclave.sigil.plan") ?? "").lowercased()

        // If token is present and plan is sovereign (or sovereign_annual), grant .sovereign
        if !token.isEmpty && (plan.contains("sovereign")) {
            return .sovereign
        }

        return nil
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

    /// Called on app foreground or periodically to re-check Sovereign status.
    /// Useful if the user just purchased Sovereign in Vaultyx and returned to DocArmor.
    func checkForSovereignUpdate() {
        if let sovereignPlan = checkSharedAppGroupEntitlement(), sovereignPlan > currentPlan {
            currentPlan = sovereignPlan
        }
    }
}
