import Foundation

enum ProductID {
    static let proMonthly    = "com.katafract.DocArmor.pro.monthly"
    static let proAnnual     = "com.katafract.DocArmor.pro.annual"
    static let familyMonthly = "com.katafract.DocArmor.family.monthly"
    static let familyAnnual  = "com.katafract.DocArmor.family.annual"

    static let all: Set<String> = [proMonthly, proAnnual, familyMonthly, familyAnnual]

    static func plan(for productID: String) -> EntitlementService.Plan {
        switch productID {
        case familyMonthly, familyAnnual: return .family
        case proMonthly, proAnnual:       return .pro
        default:                          return .free
        }
    }
}
