import Foundation

/// Checks if user has an active Enclave/Sovereign/Founder platform token from shared App Group.
/// Written by WraithVPN or Vaultyx on subscription purchase.
enum PlatformEntitlement {
    static let sharedGroup = "group.com.katafract.enclave"
    static let tokenKey = "enclave.sigil.token"
    static let planKey = "enclave.sigil.plan"

    /// Distinguishes between "no entitlement" and "container unavailable" (app group read failure).
    /// Returns (isUnlocked: Bool, readFailed: Bool).
    /// readFailed=true means the App Group container couldn't be accessed (no entitlement app installed).
    static func platformEntitlementStatus() -> (isUnlocked: Bool, readFailed: Bool) {
        guard let defaults = UserDefaults(suiteName: sharedGroup) else {
            return (false, true)
        }
        guard let token = defaults.string(forKey: tokenKey), !token.isEmpty else {
            return (false, false)
        }
        guard let plan = defaults.string(forKey: planKey) else {
            return (false, false)
        }
        let unlocked = ["enclave", "enclave_annual", "enclave_plus", "enclave_plus_annual",
                        "sovereign", "sovereign_annual", "founder"].contains(plan.lowercased())
        return (unlocked, false)
    }

    /// Returns true if user has an active Enclave, Enclave Plus, Sovereign, or Founder token.
    static var isPlatformUnlocked: Bool {
        platformEntitlementStatus().isUnlocked
    }
}
