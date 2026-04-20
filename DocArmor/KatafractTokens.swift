import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Temporary inline copy of KatafractStyle tokens for DocArmor.
/// TODO: replace with `import KatafractStyle` once the SPM dependency is
/// added via Xcode → File → Add Package Dependencies →
/// https://github.com/katafractured/KatafractStyle.git (from 0.1.1).
///
/// When the package is added, delete THIS file — the API is drop-in compatible.
extension Color {
    static let kataNavy      = Color(red: 0.059, green: 0.149, blue: 0.322)
    static let kataMidnight  = Color(red: 0.008, green: 0.024, blue: 0.063)
    static let kataSapphire  = Color(red: 0.122, green: 0.373, blue: 0.682)
    static let kataIce       = Color(red: 0.722, green: 0.875, blue: 1.000)
    static let kataGold      = Color(red: 0.776, green: 0.596, blue: 0.220)
    static let kataChampagne = Color(red: 1.000, green: 0.910, blue: 0.604)
    static let kataBronze    = Color(red: 0.431, green: 0.306, blue: 0.082)

    static let kataBackgroundGradient = LinearGradient(
        colors: [.kataNavy, .kataMidnight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let kataPremiumGradient = LinearGradient(
        colors: [Color.kataChampagne.opacity(0.95), Color(red: 0.9, green: 0.56, blue: 0.14).opacity(0.9)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

extension Font {
    static func kataDisplay(_ size: CGFloat = 40, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func kataHeadline(_ size: CGFloat = 24, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func kataBody(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func kataCaption(_ size: CGFloat = 12, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func kataMono(_ size: CGFloat = 14, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

public enum KataHaptic {
    case unlocked, saved, revealed, denied, tap, destructive

    @MainActor
    public func fire() {
        #if canImport(UIKit)
        switch self {
        case .unlocked:
            let g = UINotificationFeedbackGenerator(); g.prepare(); g.notificationOccurred(.success)
        case .saved:
            let g = UIImpactFeedbackGenerator(style: .medium); g.prepare(); g.impactOccurred()
        case .revealed:
            let g = UIImpactFeedbackGenerator(style: .rigid); g.prepare(); g.impactOccurred()
        case .denied:
            let g = UINotificationFeedbackGenerator(); g.prepare(); g.notificationOccurred(.error)
        case .tap:
            let g = UIImpactFeedbackGenerator(style: .light); g.prepare(); g.impactOccurred()
        case .destructive:
            let g = UINotificationFeedbackGenerator(); g.prepare(); g.notificationOccurred(.warning)
        }
        #endif
    }
}
