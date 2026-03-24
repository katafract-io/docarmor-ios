import AppIntents

/// Siri intent: "Show my driver's license in DocArmor"
struct ShowDocumentIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Document"
    static let description = IntentDescription(
        "Open a specific document type in your DocArmor vault.",
        categoryName: "Documents"
    )

    /// Opens the app so biometric auth can happen naturally
    static let openAppWhenRun = true

    @Parameter(title: "Document Type", description: "The type of document to show")
    var documentType: DocumentTypeEntity

    func perform() async throws -> some IntentResult {
        // App opens via openAppWhenRun — DocArmorApp handles navigation
        // via the pendingDocumentType environment binding after auth.
        // We post a notification the app observes to set the pending type.
        NotificationCenter.default.post(
            name: .showDocumentIntent,
            object: nil,
            userInfo: ["documentType": documentType.id]
        )
        return .result()
    }
}

// MARK: - Open Category Intent

/// Siri intent: "Open identity documents in DocArmor"
struct OpenCategoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Category"
    static let description = IntentDescription(
        "Open a document category in your DocArmor vault.",
        categoryName: "Documents"
    )

    static let openAppWhenRun = true

    @Parameter(title: "Category")
    var category: DocumentCategoryEntity

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .openCategoryIntent,
            object: nil,
            userInfo: ["category": category.id]
        )
        return .result()
    }
}

// MARK: - Category Entity

struct DocumentCategoryEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Document Category")
    static let defaultQuery = DocumentCategoryQuery()

    var id: String
    var displayName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: displayName))
    }

    init(category: DocumentCategory) {
        self.id = category.rawValue
        self.displayName = category.rawValue
    }
}

struct DocumentCategoryQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [DocumentCategoryEntity] {
        DocumentCategory.allCases
            .filter { identifiers.contains($0.rawValue) }
            .map { DocumentCategoryEntity(category: $0) }
    }

    func suggestedEntities() async throws -> [DocumentCategoryEntity] {
        DocumentCategory.allCases.map { DocumentCategoryEntity(category: $0) }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    nonisolated static let showDocumentIntent = Notification.Name("docarmor.intent.showDocument")
    nonisolated static let openCategoryIntent = Notification.Name("docarmor.intent.openCategory")
}
