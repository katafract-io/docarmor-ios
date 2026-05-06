import Foundation

/// Checks if user has an active Enclave/Sovereign/Founder platform token from shared App Group.
/// Written by WraithVPN or Vaultyx on subscription purchase.
enum PlatformEntitlement {
    static let sharedGroup = "group.com.katafract.enclave"
    static let tokenKey = "enclave.sigil.token"
    static let planKey = "enclave.sigil.plan"

    /// Returns true if user has an active Enclave, Enclave Plus, Sovereign, or Founder token.
    static var isPlatformUnlocked: Bool {
        guard let defaults = UserDefaults(suiteName: sharedGroup),
              let token = defaults.string(forKey: tokenKey),
              !token.isEmpty,
              let plan = defaults.string(forKey: planKey) else { return false }
        return ["enclave", "enclave_annual", "enclave_plus", "enclave_plus_annual",
                "sovereign", "sovereign_annual", "founder"].contains(plan.lowercased())
    }
}
