import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let importButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    private static let maxFileSizeBytes: Int = 50 * 1024 * 1024  // 50 MB

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        refreshDetailText()
        cleanupStaleInboxItems()
    }

    private func configureUI() {
        view.backgroundColor = .systemBackground

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.text = "Save to DocArmor"
        titleLabel.textAlignment = .center

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .preferredFont(forTextStyle: .body)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0
        detailLabel.textAlignment = .center

        importButton.translatesAutoresizingMaskIntoConstraints = false
        importButton.configuration = .filled()
        importButton.configuration?.title = "Import"
        importButton.addTarget(self, action: #selector(importTapped), for: .touchUpInside)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.configuration = .plain()
        cancelButton.configuration?.title = "Cancel"
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true

        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            detailLabel,
            activityIndicator,
            importButton,
            cancelButton
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func refreshDetailText() {
        let count = attachmentProviders.count
        detailLabel.text = count == 0
            ? "No supported attachments were found in this share item."
            : "DocArmor will copy \(count) attachment\(count == 1 ? "" : "s") into its secure import inbox."
        importButton.isEnabled = count > 0
    }

    private var attachmentProviders: [NSItemProvider] {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        return items
            .flatMap { $0.attachments ?? [] }
            .filter { provider in
                provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) ||
                provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) ||
                provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) ||
                provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            }
    }

    @objc
    private func cancelTapped() {
        extensionContext?.cancelRequest(withError: NSError(domain: "DocArmorShareExtension", code: 0))
    }

    @objc
    private func importTapped() {
        setImporting(true)
        Task {
            do {
                let manifest = try await persistAttachments()
                try manifest.save()

                // If there are failures, show the partial result before completing
                if !manifest.isFullSuccess && manifest.hasPartialSuccess {
                    presentPartialSuccess(manifest)
                } else if !manifest.hasPartialSuccess {
                    // All failed
                    presentError(manifest.resultSummary)
                    setImporting(false)
                    return
                }

                extensionContext?.completeRequest(returningItems: nil)
            } catch {
                presentError(error.localizedDescription)
                setImporting(false)
            }
        }
    }

    private func setImporting(_ importing: Bool) {
        importButton.isEnabled = !importing
        cancelButton.isEnabled = !importing
        importing ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
    }

    private func persistAttachments() async throws -> ImportOperationManifest {
        let folder = try importFolderURL()
        let operationID = UUID().uuidString
        var items: [ImportOperationManifest.ImportedItem] = []

        for (index, provider) in attachmentProviders.enumerated() {
            let sourceIdentifier = "Item \(index + 1)"
            do {
                let fileName = try await persist(provider: provider, into: folder)
                items.append(ImportOperationManifest.ImportedItem(
                    sourceIdentifier: sourceIdentifier,
                    persistedFileName: fileName,
                    status: .success,
                    errorDescription: nil
                ))
            } catch let error as NSError {
                // Categorize the error
                let status: ImportOperationManifest.ItemStatus
                switch (error.domain, error.code) {
                case ("DocArmorShareExtension", 415):
                    status = .failedLoadUnsupported
                case ("DocArmorShareExtension", 413):
                    status = .failedFileSize
                case ("DocArmorShareExtension", 3):
                    status = .failedImagePrep
                case ("DocArmorShareExtension", 2):
                    status = .failedFileRepresentation
                case ("DocArmorShareExtension", 4):
                    status = .failedFileURL
                case ("DocArmorShareExtension", 1):
                    status = .failedContainerAccess
                default:
                    status = .unknown
                }

                items.append(ImportOperationManifest.ImportedItem(
                    sourceIdentifier: sourceIdentifier,
                    persistedFileName: nil,
                    status: status,
                    errorDescription: error.localizedDescription
                ))
            } catch {
                items.append(ImportOperationManifest.ImportedItem(
                    sourceIdentifier: sourceIdentifier,
                    persistedFileName: nil,
                    status: .unknown,
                    errorDescription: error.localizedDescription
                ))
            }
        }

        let manifest = ImportOperationManifest(
            operationID: operationID,
            createdAt: Date(),
            expectedItemCount: attachmentProviders.count,
            items: items,
            isAcknowledged: false
        )

        // Only throw if NOTHING imported
        if manifest.successCount == 0 && manifest.failureCount > 0 {
            throw NSError(
                domain: "DocArmorShareExtension",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: manifest.resultSummary]
            )
        }

        return manifest
    }

    private func persist(provider: NSItemProvider, into folder: URL) async throws -> String {
        if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            return try await persistFileRepresentation(provider: provider, type: .pdf, into: folder)
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            return try await persistImage(provider: provider, into: folder)
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            return try await persistFileURL(provider: provider, into: folder)
        }
        // Explicitly reject unsupported file types (e.g. .txt, .docx, .zip, links)
        throw NSError(
            domain: "DocArmorShareExtension",
            code: 415,
            userInfo: [NSLocalizedDescriptionKey: "This file type isn't supported. DocArmor accepts images and PDFs."]
        )
    }

    private func persistImage(provider: NSItemProvider, into folder: URL) async throws -> String {
        let image = try await loadObject(ofClass: UIImage.self, from: provider)
        let downsampledImage = downsampleImage(image, maxDimension: 2400, compressionQuality: 0.82)
        guard let jpegData = downsampledImage.jpegData(compressionQuality: 0.82), !jpegData.isEmpty else {
            throw NSError(domain: "DocArmorShareExtension", code: 3, userInfo: [NSLocalizedDescriptionKey: "Image data could not be prepared for storage."])
        }
        try validateFileSize(jpegData.count)
        let fileName = "share-\(UUID().uuidString).jpg"
        let fileURL = folder.appendingPathComponent(fileName)
        try jpegData.write(to: fileURL, options: .atomic)
        return fileName
    }

    private func persistFileURL(provider: NSItemProvider, into folder: URL) async throws -> String {
        let fileURL = try await loadFileURL(provider: provider)
        let uti = UTType(filenameExtension: fileURL.pathExtension)

        // PDF: copy through as-is.
        if uti?.conforms(to: .pdf) == true {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int ?? 0
            try validateFileSize(fileSize)
            let destination = uniqueDestinationURL(in: folder, preferredName: fileURL.lastPathComponent)
            try FileManager.default.copyItem(at: fileURL, to: destination)
            return destination.lastPathComponent
        }

        // Image file: downsample before writing (avoid copying a 50 MB original into the inbox).
        if uti?.conforms(to: .image) == true, let image = UIImage(contentsOfFile: fileURL.path) {
            let downsampled = downsampleImage(image, maxDimension: 2400, compressionQuality: 0.82)
            guard let jpegData = downsampled.jpegData(compressionQuality: 0.82), !jpegData.isEmpty else {
                throw NSError(domain: "DocArmorShareExtension", code: 3, userInfo: [NSLocalizedDescriptionKey: "Image data could not be prepared for storage."])
            }
            try validateFileSize(jpegData.count)
            let fileName = "share-\(UUID().uuidString).jpg"
            let destination = folder.appendingPathComponent(fileName)
            try jpegData.write(to: destination, options: .atomic)
            return fileName
        }

        // Anything else (.docx/.zip/.txt/etc.) — reject rather than jamming the inbox with
        // a file the app can't normalize.
        throw NSError(
            domain: "DocArmorShareExtension",
            code: 415,
            userInfo: [NSLocalizedDescriptionKey: "This file type isn't supported. DocArmor accepts images and PDFs."]
        )
    }

    private func persistFileRepresentation(
        provider: NSItemProvider,
        type: UTType,
        into folder: URL
    ) async throws -> String {
        let sourceURL = try await loadFileRepresentation(provider: provider, type: type)
        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let fileSize = attributes[.size] as? Int ?? 0
        try validateFileSize(fileSize)
        let destination = uniqueDestinationURL(in: folder, preferredName: sourceURL.lastPathComponent)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination.lastPathComponent
    }

    private func importFolderURL() throws -> URL {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.katafract.DocArmor") else {
            throw NSError(domain: "DocArmorShareExtension", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Group container is unavailable."])
        }
        let folder = root.appendingPathComponent("ImportInbox", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func uniqueDestinationURL(in folder: URL, preferredName: String) -> URL {
        let baseName = URL(fileURLWithPath: preferredName).deletingPathExtension().lastPathComponent
        let ext = URL(fileURLWithPath: preferredName).pathExtension
        let sanitizedBase = baseName.isEmpty ? "import-\(UUID().uuidString)" : baseName
        let filename = ext.isEmpty ? sanitizedBase : "\(sanitizedBase).\(ext)"
        return folder.appendingPathComponent("\(UUID().uuidString)-\(filename)")
    }

    private func loadFileRepresentation(provider: NSItemProvider, type: UTType) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: NSError(domain: "DocArmorShareExtension", code: 2, userInfo: [NSLocalizedDescriptionKey: "File representation was unavailable."]))
                }
            }
        }
    }

    private func loadFileURL(provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let data = item as? Data,
                   let url = NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL? {
                    continuation.resume(returning: url)
                    return
                }
                if let url = item as? URL {
                    continuation.resume(returning: url)
                    return
                }
                continuation.resume(throwing: NSError(domain: "DocArmorShareExtension", code: 4, userInfo: [NSLocalizedDescriptionKey: "Shared file URL was unavailable."]))
            }
        }
    }

    private func validateFileSize(_ size: Int) throws {
        guard size <= Self.maxFileSizeBytes else {
            throw NSError(
                domain: "DocArmorShareExtension",
                code: 413,
                userInfo: [NSLocalizedDescriptionKey: "File too large. DocArmor supports files up to 50 MB."]
            )
        }
    }

    private func cleanupStaleInboxItems() {
        // Only delete files that have been acknowledged by the main app (consumed).
        // Keep unacknowledged items indefinitely so the user has time to review them.
        // This prevents losing successfully-shared items just because another unrelated
        // share session ran.
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.katafract.DocArmor") else {
            return
        }

        let inboxURL = containerURL.appendingPathComponent("ImportInbox", isDirectory: true)

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: inboxURL,
                includingPropertiesForKeys: [.creationDateKey]
            )

            // Get all persisted manifests to check acknowledgment status
            let manifests = ImportOperationManifest.allManifests()

            for itemURL in contents {
                let fileName = itemURL.lastPathComponent
                // Only delete if this file is in an acknowledged manifest
                let inAcknowledgedManifest = manifests.contains { manifest in
                    manifest.isAcknowledged &&
                    manifest.items.contains { $0.persistedFileName == fileName }
                }

                if inAcknowledgedManifest {
                    try FileManager.default.removeItem(at: itemURL)
                }
            }
        } catch {
            // Silent failure; stale cleanup is non-critical
        }
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: "Import Failed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func presentPartialSuccess(_ manifest: ImportOperationManifest) {
        let alert = UIAlertController(
            title: "Partial Import",
            message: manifest.resultSummary + "\n\nSuccessfully imported items are ready in DocArmor's inbox.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.extensionContext?.completeRequest(returningItems: nil)
        })
        present(alert, animated: true)
    }

    private func loadObject(ofClass cls: AnyClass, from provider: NSItemProvider) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let image = object as? UIImage {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: NSError(domain: "DocArmorShareExtension", code: 3, userInfo: [NSLocalizedDescriptionKey: "Image data was unavailable."]))
                }
            }
        }
    }

    private func downsampleImage(_ image: UIImage, maxDimension: CGFloat, compressionQuality: CGFloat) -> UIImage {
        let originalSize = image.size
        let largestSide = max(originalSize.width, originalSize.height)

        if largestSide > maxDimension {
            let scale = maxDimension / largestSide
            let targetSize = CGSize(
                width: max(1, floor(originalSize.width * scale)),
                height: max(1, floor(originalSize.height * scale))
            )
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }

        return image
    }
}
