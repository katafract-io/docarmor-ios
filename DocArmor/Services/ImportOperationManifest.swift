import Foundation

/// Atomic record of a share extension import operation.
/// Written to App Group storage BEFORE the extension completes, allowing the main app
/// to diagnose partial failures and safely manage item retention.
struct ImportOperationManifest: Codable, Sendable {
    enum ItemStatus: String, Codable, Sendable {
        case success
        case failedLoadUnsupported = "failed_load_unsupported"
        case failedFileSize = "failed_file_size"
        case failedImagePrep = "failed_image_prep"
        case failedFileRepresentation = "failed_file_representation"
        case failedFileURL = "failed_file_url"
        case failedContainerAccess = "failed_container_access"
        case failedCopy = "failed_copy"
        case unknown = "failed_unknown"

        var displayReason: String {
            switch self {
            case .success:
                return "Successfully imported"
            case .failedLoadUnsupported:
                return "File type not supported (images and PDFs only)"
            case .failedFileSize:
                return "File exceeds 50 MB limit"
            case .failedImagePrep:
                return "Image could not be prepared for storage"
            case .failedFileRepresentation:
                return "File could not be accessed"
            case .failedFileURL:
                return "File URL was unavailable"
            case .failedContainerAccess:
                return "App Group container unavailable"
            case .failedCopy:
                return "File could not be copied"
            case .unknown:
                return "Unknown error"
            }
        }
    }

    struct ImportedItem: Codable, Sendable {
        /// Original filename or description from the share source
        let sourceIdentifier: String
        /// Filename after being persisted to the inbox
        let persistedFileName: String?
        let status: ItemStatus
        /// If failed, the underlying error reason
        let errorDescription: String?

        var isSuccess: Bool { status == .success }
        var isFailed: Bool { !isSuccess }
    }

    /// Unique operation ID
    let operationID: String
    /// ISO8601 timestamp when the operation started
    let createdAt: Date
    /// Number of items presented for import
    let expectedItemCount: Int
    /// Per-item status records
    let items: [ImportedItem]
    /// True if the main app has reviewed this operation's results
    var isAcknowledged: Bool

    /// True if all items imported successfully
    var isFullSuccess: Bool {
        items.count == expectedItemCount && items.allSatisfy(\.isSuccess)
    }

    /// True if any items imported successfully
    var hasPartialSuccess: Bool {
        items.contains(where: \.isSuccess)
    }

    /// Count of successful imports
    var successCount: Int {
        items.filter(\.isSuccess).count
    }

    /// Count of failed imports
    var failureCount: Int {
        items.filter(\.isFailed).count
    }

    /// Human-readable summary for display
    var resultSummary: String {
        if isFullSuccess {
            return "All \(successCount) item\(successCount == 1 ? "" : "s") imported successfully."
        } else if hasPartialSuccess {
            return "\(successCount) of \(items.count) item\(items.count == 1 ? "" : "s") imported. \(failureCount) failed."
        } else {
            return "All \(items.count) item\(items.count == 1 ? "" : "s") failed to import."
        }
    }

    /// Detailed report for debugging (main app diagnostics)
    var detailedReport: String {
        var lines = [resultSummary]
        for (idx, item) in items.enumerated() {
            if item.isFailed {
                lines.append("  [\(idx + 1)] \(item.sourceIdentifier): \(item.status.displayReason)")
                if let err = item.errorDescription, !err.isEmpty {
                    lines.append("       \(err)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Creates a new operation manifest.
    /// - Parameters:
    ///   - expectedItemCount: Number of items the extension received from the share sheet
    ///   - items: Per-item import status records
    init(
        operationID: String = UUID().uuidString,
        createdAt: Date = Date(),
        expectedItemCount: Int,
        items: [ImportedItem],
        isAcknowledged: Bool = false
    ) {
        self.operationID = operationID
        self.createdAt = createdAt
        self.expectedItemCount = expectedItemCount
        self.items = items
        self.isAcknowledged = isAcknowledged
    }

    /// Mark this operation as acknowledged by the main app (e.g., after consuming the files).
    mutating func acknowledge() {
        self.isAcknowledged = true
    }

    /// Persist this manifest to App Group storage.
    func save() throws {
        guard let containerURL = AppGroup.containerURL() else {
            throw NSError(domain: "ImportOperationManifest", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Group container unavailable"])
        }

        let manifestDir = containerURL.appendingPathComponent("ImportManifests", isDirectory: true)
        try FileManager.default.createDirectory(at: manifestDir, withIntermediateDirectories: true)

        let manifestURL = manifestDir.appendingPathComponent("\(operationID).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        try data.write(to: manifestURL, options: .atomic)
    }

    /// Load a manifest by operation ID from App Group storage.
    static func load(operationID: String) throws -> ImportOperationManifest? {
        guard let containerURL = AppGroup.containerURL() else {
            return nil
        }

        let manifestURL = containerURL.appendingPathComponent("ImportManifests/\(operationID).json")
        guard FileManager.default.fileExists(atPath: manifestURL.path(percentEncoded: false)) else {
            return nil
        }

        let data = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ImportOperationManifest.self, from: data)
    }

    /// List all manifests in chronological order (newest first).
    static func allManifests() -> [ImportOperationManifest] {
        guard let containerURL = AppGroup.containerURL() else {
            return []
        }

        let manifestDir = containerURL.appendingPathComponent("ImportManifests", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: manifestDir, includingPropertiesForKeys: nil) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return files.compactMap { url in
            guard url.pathExtension == "json" else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(ImportOperationManifest.self, from: data)
        }.sorted { $0.createdAt > $1.createdAt }
    }

    /// Delete a manifest file after it has been acknowledged and items consumed.
    static func delete(operationID: String) throws {
        guard let containerURL = AppGroup.containerURL() else {
            return
        }

        let manifestURL = containerURL.appendingPathComponent("ImportManifests/\(operationID).json")
        guard FileManager.default.fileExists(atPath: manifestURL.path(percentEncoded: false)) else {
            return
        }
        try FileManager.default.removeItem(at: manifestURL)
    }

    /// Clean up old acknowledged manifests (older than 7 days).
    static func cleanupOldManifests() {
        let cutoff = Date(timeIntervalSinceNow: -7 * 86400)  // 7 days ago
        for manifest in allManifests() {
            if manifest.isAcknowledged && manifest.createdAt < cutoff {
                try? delete(operationID: manifest.operationID)
            }
        }
    }
}
