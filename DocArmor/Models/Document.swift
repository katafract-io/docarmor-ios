import Foundation
import SwiftData

@Model
final class Document {
    var id: UUID
    var name: String
    /// Stored as String for migration safety across enum changes
    var documentTypeRaw: String
    /// Stored as String for migration safety
    var categoryRaw: String
    var notes: String
    var expirationDate: Date?
    /// Days before expiry to send reminder: 30, 60, 90 — nil means no reminder
    var expirationReminderDays: Int?
    var createdAt: Date
    var updatedAt: Date
    var isFavorite: Bool

    @Relationship(deleteRule: .cascade)
    var pages: [DocumentPage]

    // MARK: - Computed

    var documentType: DocumentType {
        DocumentType(rawValue: documentTypeRaw) ?? .custom
    }

    var category: DocumentCategory {
        DocumentCategory(rawValue: categoryRaw) ?? .identity
    }

    var isExpired: Bool {
        guard let expiry = expirationDate else { return false }
        return expiry < Date.now
    }

    var daysUntilExpiry: Int? {
        guard let expiry = expirationDate else { return nil }
        return Calendar.current.dateComponents([.day], from: .now, to: expiry).day
    }

    var sortedPages: [DocumentPage] {
        pages.sorted { $0.pageIndex < $1.pageIndex }
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        name: String,
        documentType: DocumentType,
        category: DocumentCategory? = nil,
        notes: String = "",
        expirationDate: Date? = nil,
        expirationReminderDays: Int? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.documentTypeRaw = documentType.rawValue
        self.categoryRaw = (category ?? documentType.defaultCategory).rawValue
        self.notes = notes
        self.expirationDate = expirationDate
        self.expirationReminderDays = expirationReminderDays
        self.createdAt = Date.now
        self.updatedAt = Date.now
        self.isFavorite = isFavorite
        self.pages = []
    }
}
