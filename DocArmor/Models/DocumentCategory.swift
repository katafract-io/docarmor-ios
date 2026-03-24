import SwiftUI

enum DocumentCategory: String, CaseIterable, Codable, Hashable {
    case identity  = "Identity"
    case medical   = "Medical"
    case financial = "Financial"
    case travel    = "Travel"
    case work      = "Work"
    case custom    = "Custom"

    var systemImage: String {
        switch self {
        case .identity:  return "person.text.rectangle.fill"
        case .medical:   return "cross.case.fill"
        case .financial: return "creditcard.fill"
        case .travel:    return "airplane"
        case .work:      return "briefcase.fill"
        case .custom:    return "folder.fill"
        }
    }

    var color: Color {
        switch self {
        case .identity:  return .blue
        case .medical:   return .red
        case .financial: return .green
        case .travel:    return .orange
        case .work:      return .purple
        case .custom:    return .gray
        }
    }
}
