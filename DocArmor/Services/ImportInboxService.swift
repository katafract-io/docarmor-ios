import Foundation
import UniformTypeIdentifiers

nonisolated struct PendingImportItem: Identifiable, Sendable {
    enum Kind: String, Sendable {
        case image
        case pdf
        case file

        var systemImage: String {
            switch self {
            case .image:
                return "photo"
            case .pdf:
                return "doc.richtext"
            case .file:
                return "doc"
            }
        }
    }

    let id: String
    let fileURL: URL
    let filename: String
    let kind: Kind
    let createdAt: Date
}

enum ImportInboxService {
    nonisolated static func pendingItems() -> [PendingImportItem] {
        guard let inboxURL = inboxURL(createIfNeeded: true) else { return [] }

        let fileManager = FileManager.default
        guard
            let urls = try? fileManager.contentsOfDirectory(
                at: inboxURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        return urls.compactMap(makePendingImportItem(url:)).sorted { $0.createdAt > $1.createdAt }
    }

    /// Returns all pending import operations (unacknowledged manifests) with their results.
    nonisolated static func pendingOperations() -> [ImportOperationManifest] {
        ImportOperationManifest.allManifests().filter { !$0.isAcknowledged }
    }

    /// Returns partial import operations (some items succeeded, some failed).
    nonisolated static func partialOperations() -> [ImportOperationManifest] {
        pendingOperations().filter { $0.hasPartialSuccess && !$0.isFullSuccess }
    }

    nonisolated static func pendingCount() -> Int {
        pendingItems().count
    }

    nonisolated static func loadData(for item: PendingImportItem) throws -> Data {
        try Data(contentsOf: item.fileURL)
    }

    nonisolated static func consume(_ item: PendingImportItem) throws {
        try removeItem(at: item.fileURL)
    }

    /// Acknowledge and remove an import operation after all its successful items have been consumed.
    nonisolated static func acknowledgeOperation(_ operationID: String) throws {
        guard var manifest = try ImportOperationManifest.load(operationID: operationID) else {
            return
        }
        manifest.acknowledge()
        try manifest.save()
    }

    /// Clean up old acknowledged manifests (older than 7 days).
    nonisolated static func cleanupOldManifests() {
        ImportOperationManifest.cleanupOldManifests()
    }

    nonisolated static func clearInbox() throws {
        for item in pendingItems() {
            try removeItem(at: item.fileURL)
        }
    }

    nonisolated static func inboxURL(createIfNeeded: Bool = false) -> URL? {
        guard let containerURL = AppGroup.containerURL() else { return nil }

        let folderURL = containerURL.appendingPathComponent(
            AppGroup.importInboxFolderName,
            isDirectory: true
        )

        guard createIfNeeded else { return folderURL }

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            return folderURL
        } catch {
            return nil
        }
    }

    nonisolated private static func makePendingImportItem(url: URL) -> PendingImportItem? {
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        let createdAt = values?.creationDate ?? values?.contentModificationDate ?? .distantPast

        return PendingImportItem(
            id: url.lastPathComponent,
            fileURL: url,
            filename: url.lastPathComponent,
            kind: itemKind(for: url),
            createdAt: createdAt
        )
    }

    nonisolated private static func itemKind(for url: URL) -> PendingImportItem.Kind {
        let type = UTType(filenameExtension: url.pathExtension.lowercased())

        if type?.conforms(to: .pdf) == true {
            return .pdf
        }

        if type?.conforms(to: .image) == true {
            return .image
        }

        return .file
    }

    nonisolated private static func removeItem(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
