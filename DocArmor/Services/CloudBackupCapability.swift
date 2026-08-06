import Foundation

/// Unified cloud backup capability model used consistently across all code paths.
///
/// **Design decision (2026-07-30):** Founder tier INCLUDES cloud backup capability,
/// matching the behavior of PlatformEntitlement and SovereignBackupService. EntitlementService's
/// earlier exclusion of Founder was an omission, not a deliberate narrower design — the fix
/// unifies capability detection across all entry points.
///
/// Cloud backup is available to users with:
/// - "sovereign" or "sovereign_annual" plan (explicit Sovereign subscription)
/// - "founder" plan (founder tier, lifetime all-access)
///
/// This model is the single source of truth for capability detection. All code paths
/// (Settings UI, save-time backup, foreground recovery, restore, usage, delete) must
/// use this model rather than duplicating plan checks.
struct CloudBackupCapability {
    /// Returns true iff the given plan string enables cloud backup capability.
    /// Accepts both canonical and nil/empty strings (treated as not cloud-capable).
    static func isCloudCapable(plan: String?) -> Bool {
        guard let plan = plan?.lowercased(), !plan.isEmpty else { return false }
        return plan == "sovereign" || plan == "sovereign_annual" || plan == "founder"
    }

    /// Reads the plan from the shared App Group and returns true iff it's cloud-capable.
    /// Returns false if the App Group is unavailable or the plan is missing.
    ///
    /// - Returns: (isCloudCapable: Bool, readFailed: Bool) where readFailed=true
    ///   means the App Group container couldn't be accessed (no entitlement app installed).
    static func resolveFromAppGroup() -> (isCloudCapable: Bool, readFailed: Bool) {
        let appGroup = "group.com.katafract.enclave"
        let planKey = "enclave.sigil.plan"

        guard let defaults = UserDefaults(suiteName: appGroup) else {
            return (false, true)  // App Group unavailable
        }

        let plan = defaults.string(forKey: planKey) ?? ""
        return (isCloudCapable(plan: plan), false)
    }

    /// Shared App Group keys and constants used by all cloud backup code paths.
    enum AppGroup {
        static let suiteName = "group.com.katafract.enclave"
        static let tokenKey = "enclave.sigil.token"
        static let planKey = "enclave.sigil.plan"
    }

    /// Preference key for user's explicit opt-in/opt-out of cloud backup.
    /// When absent, it MUST be treated as "not yet decided" (no implicit upload consent),
    /// not as "true" (upload enabled).
    enum Preference {
        static let key = "sovereignBackup.enabled"

        /// Returns the explicit backup preference, or nil if the user has not yet made a choice.
        /// Critically: returns nil (not true) for missing preference to avoid implicit consent.
        ///
        /// - Returns: true = user has explicitly enabled backup; false = user has explicitly disabled it;
        ///   nil = user has never seen or interacted with the Cloud Backup control.
        static func readExplicitChoice() -> Bool? {
            // UserDefaults.object(forKey:) returns nil if the key doesn't exist,
            // which is correct — we need to distinguish "never set" from "set to false".
            // Cast to Optional<Bool> to preserve this nil.
            return UserDefaults.standard.object(forKey: key) as? Bool
        }

        /// Persists the user's explicit choice. Called when the user toggles the Cloud Backup
        /// control in Settings, or when a new plan is resolved as cloud-capable and we need
        /// to default to enabled (explicitly, not implicitly).
        static func write(_ enabled: Bool) {
            UserDefaults.standard.set(enabled, forKey: key)
        }

        /// Removes the preference key entirely (e.g., when plan is downgraded to non-cloud).
        /// Next read will return nil, preventing implicit upload consent for a plan that
        /// shouldn't have cloud capability.
        static func reset() {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
