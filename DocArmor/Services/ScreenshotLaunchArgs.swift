import Foundation

/// Parses DocArmor screenshot-mode launch flags.
/// Activated via command-line arguments for fastlane snapshot CI.
///
/// Supported flags:
///   --skip-onboarding              Mark onboarding as complete on launch
///   --seed-data <variant>          Seed documents: "preparedness", "full-vault", "minimal"
///   --auto-open <document-type>    Auto-navigate to a specific document type (e.g., "driversLicense")
///   --mock-subscribed              Override EntitlementService to return Sovereign tier
///   --mock-unsubscribed            Override EntitlementService to return locked (free) tier
///   --mock-locked                  Keep the vault locked (force lock screen visibility)
///   --show-scanner                 Open the document scanner on launch
///
/// Usage:
///   if ScreenshotLaunchArgs.skipOnboarding {
///       UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
///   }
enum ScreenshotLaunchArgs {
    private static let launchArgs = CommandLine.arguments

    /// Whether --skip-onboarding was passed
    static var skipOnboarding: Bool {
        launchArgs.contains("--skip-onboarding")
    }

    /// Returns the variant name if --seed-data <value> was passed.
    /// Valid values: "preparedness", "full-vault", "minimal", or nil if not set.
    static var seedDataVariant: String? {
        guard let index = launchArgs.firstIndex(of: "--seed-data"),
              index + 1 < launchArgs.count else {
            return nil
        }
        return launchArgs[index + 1]
    }

    /// Returns the document type name if --auto-open <type> was passed (e.g., "driversLicense").
    /// Matches DocumentType.rawValue for lookup.
    static var autoOpenDocumentType: String? {
        guard let index = launchArgs.firstIndex(of: "--auto-open"),
              index + 1 < launchArgs.count else {
            return nil
        }
        return launchArgs[index + 1]
    }

    /// Whether --mock-subscribed was passed (overlaps with ScreenshotMode.isEnabled for compat).
    /// If true, EntitlementService returns Sovereign tier status.
    static var mockSubscribed: Bool {
        launchArgs.contains("--mock-subscribed")
    }

    /// Whether --mock-unsubscribed was passed.
    /// If true, EntitlementService returns locked (free) tier status.
    /// Mutually exclusive with --mock-subscribed; --mock-subscribed wins if both are set.
    static var mockUnsubscribed: Bool {
        launchArgs.contains("--mock-unsubscribed")
    }

    /// Whether --mock-locked was passed.
    /// If true, prevents automatic authentication on launch, keeping the vault locked.
    /// Used to display the lock screen / biometric gate frame.
    static var mockLocked: Bool {
        launchArgs.contains("--mock-locked")
    }

    /// Whether --show-scanner was passed.
    /// If true, opens the document scanner / import flow on launch.
    /// Used to display the scanner / import sheet frame.
    static var showScanner: Bool {
        launchArgs.contains("--show-scanner")
    }
}
