import AppIntents

/// AppEntity representing a document type for Siri parameter resolution.
struct DocumentTypeEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Document Type")
    static let defaultQuery = DocumentTypeQuery()

    var id: String                     // DocumentType.rawValue
    var displayName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: displayName))
    }

    init(documentType: DocumentType) {
        self.id = documentType.rawValue
        self.displayName = documentType.rawValue
    }

    var documentType: DocumentType {
        DocumentType(rawValue: id) ?? .custom
    }
}

// MARK: - Entity Query

struct DocumentTypeQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [DocumentTypeEntity] {
        DocumentType.allCases
            .filter { identifiers.contains($0.rawValue) }
            .map { DocumentTypeEntity(documentType: $0) }
    }

    func suggestedEntities() async throws -> [DocumentTypeEntity] {
        DocumentType.allCases.map { DocumentTypeEntity(documentType: $0) }
    }

    func defaultResult() async -> DocumentTypeEntity? {
        DocumentTypeEntity(documentType: .driversLicense)
    }
}
