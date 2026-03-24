import Foundation

enum DocumentType: String, CaseIterable, Codable, Hashable {
    case driversLicense  = "Driver's License"
    case passport        = "Passport"
    case stateID         = "State ID"
    case insuranceHealth = "Health Insurance"
    case insuranceAuto   = "Auto Insurance"
    case insuranceHome   = "Home Insurance"
    case vaccineRecord   = "Vaccine Record"
    case socialSecurity  = "Social Security Card"
    case workPermit      = "Work Permit / Visa"
    case custom          = "Custom"

    var defaultCategory: DocumentCategory {
        switch self {
        case .driversLicense, .passport, .stateID, .socialSecurity:
            return .identity
        case .insuranceHealth, .vaccineRecord:
            return .medical
        case .insuranceAuto, .insuranceHome:
            return .financial
        case .workPermit:
            return .work
        case .custom:
            return .custom
        }
    }

    var requiresFrontBack: Bool {
        switch self {
        case .driversLicense, .stateID:
            return true
        default:
            return false
        }
    }

    var systemImage: String {
        switch self {
        case .driversLicense:  return "car.fill"
        case .passport:        return "globe"
        case .stateID:         return "person.crop.rectangle.fill"
        case .insuranceHealth: return "cross.fill"
        case .insuranceAuto:   return "car.2.fill"
        case .insuranceHome:   return "house.fill"
        case .vaccineRecord:   return "syringe.fill"
        case .socialSecurity:  return "number.square.fill"
        case .workPermit:      return "briefcase.fill"
        case .custom:          return "doc.fill"
        }
    }
}
