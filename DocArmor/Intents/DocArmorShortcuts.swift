import AppIntents

/// Registers all Siri App Shortcuts so users can invoke them by voice
/// without manually adding them in the Shortcuts app.
struct DocArmorShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShowDocumentIntent(),
            phrases: [
                "Show my \(\.$documentType) in \(.applicationName)",
                "Open my \(\.$documentType) in \(.applicationName)",
                "Find my \(\.$documentType) in \(.applicationName)",
                "Pull up my \(\.$documentType) in \(.applicationName)"
            ],
            shortTitle: "Show Document",
            systemImageName: "doc.fill"
        )

        AppShortcut(
            intent: OpenCategoryIntent(),
            phrases: [
                "Open \(\.$category) documents in \(.applicationName)",
                "Show \(\.$category) vault in \(.applicationName)"
            ],
            shortTitle: "Open Category",
            systemImageName: "folder.fill"
        )
    }
}
