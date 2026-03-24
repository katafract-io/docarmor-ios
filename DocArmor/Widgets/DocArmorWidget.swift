import WidgetKit
import SwiftUI

/// Widget bundle entry point.
///
/// HOW TO SET UP THE WIDGET EXTENSION TARGET IN XCODE:
/// 1. File → New → Target → Widget Extension, name it "DocArmorWidget"
/// 2. Add this file + QuickLaunchWidget.swift to the widget extension target
/// 3. Add the App Group entitlement (group.com.katafract.docarmor) to both targets
/// 4. The @main attribute belongs only in the widget extension target — do NOT
///    include this file in the main DocArmor app target.
///
/// This file is kept here for reference / source organization.
struct DocArmorWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickLaunchWidget()
    }
}
