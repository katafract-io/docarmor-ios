import Foundation

enum ProductID {
    // New single non-consumable unlock ($12.99 one-time)
    static let unlock = "com.katafract.DocArmor.unlock"

    // Legacy subscriptions (being deleted from ASC, kept here for backwards compatibility)
    static let proMonthly    = "com.katafract.DocArmor.pro.monthly"
    static let proAnnual     = "com.katafract.DocArmor.pro.annual"
    static let familyMonthly = "com.katafract.DocArmor.family.monthly"
    static let familyAnnual  = "com.katafract.DocArmor.family.annual"

    static let all: Set<String> = [unlock, proMonthly, proAnnual, familyMonthly, familyAnnual]

    static func plan(for productID: String) -> EntitlementService.Plan {
        switch productID {
        case unlock:                       return .unlocked
        case familyMonthly, familyAnnual:  return .unlocked  // Legacy family plans → unlocked
        case proMonthly, proAnnual:        return .unlocked  // Legacy pro plans → unlocked
        default:                           return .free
        }
    }
}
