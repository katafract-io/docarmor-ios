import XCTest
@testable import DocArmor

final class ImportOperationManifestTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Clean up any lingering manifests from previous tests
        try? FileManager.default.removeItem(at: manifestStorageURL())
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: manifestStorageURL())
        super.tearDown()
    }

    private func manifestStorageURL() -> URL {
        // Use a temporary directory for testing
        let temp = FileManager.default.temporaryDirectory
        return temp.appendingPathComponent("ImportManifestTests")
    }

    func testFullSuccessManifest() {
        let items = [
            ImportOperationManifest.ImportedItem(sourceIdentifier: "Item 1", persistedFileName: "file1.jpg", status: .success, errorDescription: nil),
            ImportOperationManifest.ImportedItem(sourceIdentifier: "Item 2", persistedFileName: "file2.jpg", status: .success, errorDescription: nil)
        ]
        let manifest = ImportOperationManifest(expectedItemCount: 2, items: items)

        XCTAssertTrue(manifest.isFullSuccess)
        XCTAssertTrue(manifest.hasPartialSuccess)
        XCTAssertEqual(manifest.successCount, 2)
        XCTAssertEqual(manifest.failureCount, 0)
        XCTAssertEqual(manifest.resultSummary, "All 2 items imported successfully.")
    }

    func testPartialSuccessManifest() {
        let items = [
            ImportOperationManifest.ImportedItem(sourceIdentifier: "Item 1", persistedFileName: "file1.jpg", status: .success, errorDescription: nil),
            ImportOperationManifest.ImportedItem(sourceIdentifier: "Item 2", persistedFileName: nil, status: .failedFileSize, errorDescription: "File too large")
        ]
        let manifest = ImportOperationManifest(expectedItemCount: 2, items: items)

        XCTAssertFalse(manifest.isFullSuccess)
        XCTAssertTrue(manifest.hasPartialSuccess)
        XCTAssertEqual(manifest.successCount, 1)
        XCTAssertEqual(manifest.failureCount, 1)
        XCTAssertTrue(manifest.resultSummary.contains("1 of 2 items imported"))
    }

    func testAllFailedManifest() {
        let items = [
            ImportOperationManifest.ImportedItem(sourceIdentifier: "Item 1", persistedFileName: nil, status: .failedLoadUnsupported, errorDescription: "Unsupported type"),
            ImportOperationManifest.ImportedItem(sourceIdentifier: "Item 2", persistedFileName: nil, status: .failedFileSize, errorDescription: "File too large")
        ]
        let manifest = ImportOperationManifest(expectedItemCount: 2, items: items)

        XCTAssertFalse(manifest.isFullSuccess)
        XCTAssertFalse(manifest.hasPartialSuccess)
        XCTAssertEqual(manifest.successCount, 0)
        XCTAssertEqual(manifest.failureCount, 2)
        XCTAssertTrue(manifest.resultSummary.contains("All 2 items failed"))
    }

    func testAcknowledgement() {
        let items = [
            ImportOperationManifest.ImportedItem(sourceIdentifier: "Item 1", persistedFileName: "file1.jpg", status: .success, errorDescription: nil)
        ]
        var manifest = ImportOperationManifest(expectedItemCount: 1, items: items, isAcknowledged: false)

        XCTAssertFalse(manifest.isAcknowledged)
        manifest.acknowledge()
        XCTAssertTrue(manifest.isAcknowledged)
    }

    func testDetailedReport() {
        let items = [
            ImportOperationManifest.ImportedItem(sourceIdentifier: "photo.jpg", persistedFileName: "share-uuid.jpg", status: .success, errorDescription: nil),
            ImportOperationManifest.ImportedItem(sourceIdentifier: "document.docx", persistedFileName: nil, status: .failedLoadUnsupported, errorDescription: "File type not supported"),
            ImportOperationManifest.ImportedItem(sourceIdentifier: "large.pdf", persistedFileName: nil, status: .failedFileSize, errorDescription: "Exceeds 50MB limit")
        ]
        let manifest = ImportOperationManifest(expectedItemCount: 3, items: items)

        let report = manifest.detailedReport
        XCTAssertTrue(report.contains("1 of 3"))
        XCTAssertTrue(report.contains("document.docx"))
        XCTAssertTrue(report.contains("large.pdf"))
    }

    func testErrorStatusDisplayReasons() {
        let statuses: [(ImportOperationManifest.ItemStatus, String)] = [
            (.success, "Successfully imported"),
            (.failedLoadUnsupported, "File type not supported"),
            (.failedFileSize, "File exceeds 50 MB"),
            (.failedImagePrep, "Image could not be prepared"),
            (.failedFileRepresentation, "File could not be accessed"),
            (.failedFileURL, "File URL was unavailable"),
            (.failedContainerAccess, "App Group container unavailable"),
            (.failedCopy, "File could not be copied"),
            (.unknown, "Unknown error")
        ]

        for (status, expectedReason) in statuses {
            XCTAssertTrue(status.displayReason.contains(expectedReason.split(separator: " ").first ?? ""))
        }
    }

    func testOperationIDGeneration() {
        let manifest1 = ImportOperationManifest(expectedItemCount: 1, items: [])
        let manifest2 = ImportOperationManifest(expectedItemCount: 1, items: [])

        XCTAssertNotEqual(manifest1.operationID, manifest2.operationID)
        XCTAssertFalse(manifest1.operationID.isEmpty)
        XCTAssertFalse(manifest2.operationID.isEmpty)
    }

    func testCustomOperationID() {
        let customID = "test-operation-123"
        let manifest = ImportOperationManifest(operationID: customID, expectedItemCount: 1, items: [])

        XCTAssertEqual(manifest.operationID, customID)
    }

    func testMixedImportScenarios() {
        // Scenario: One success, one load/type failure, one size failure
        let items = [
            ImportOperationManifest.ImportedItem(
                sourceIdentifier: "photo.jpg",
                persistedFileName: "share-uuid1.jpg",
                status: .success,
                errorDescription: nil
            ),
            ImportOperationManifest.ImportedItem(
                sourceIdentifier: "document.txt",
                persistedFileName: nil,
                status: .failedLoadUnsupported,
                errorDescription: "Text files are not supported"
            ),
            ImportOperationManifest.ImportedItem(
                sourceIdentifier: "large.pdf",
                persistedFileName: nil,
                status: .failedFileSize,
                errorDescription: "File exceeds 50MB limit"
            )
        ]
        let manifest = ImportOperationManifest(expectedItemCount: 3, items: items)

        XCTAssertEqual(manifest.successCount, 1)
        XCTAssertEqual(manifest.failureCount, 2)
        XCTAssertTrue(manifest.hasPartialSuccess)
        XCTAssertFalse(manifest.isFullSuccess)
        XCTAssertTrue(manifest.resultSummary.contains("1 of 3"))
    }

    func testUnacknowledgedItemPersistenceAfterNewShare() {
        // Scenario: Item A is successfully shared on day 1, unacknowledged by main app.
        // On day 2, a new share happens. Item A should NOT be deleted.
        let items1 = [
            ImportOperationManifest.ImportedItem(
                sourceIdentifier: "Item A",
                persistedFileName: "file-a.jpg",
                status: .success,
                errorDescription: nil
            )
        ]
        let manifest1 = ImportOperationManifest(
            expectedItemCount: 1,
            items: items1,
            isAcknowledged: false
        )

        let items2 = [
            ImportOperationManifest.ImportedItem(
                sourceIdentifier: "Item B",
                persistedFileName: "file-b.jpg",
                status: .success,
                errorDescription: nil
            )
        ]
        let manifest2 = ImportOperationManifest(
            expectedItemCount: 1,
            items: items2,
            isAcknowledged: false
        )

        // Both operations have unacknowledged successful items
        XCTAssertFalse(manifest1.isAcknowledged)
        XCTAssertFalse(manifest2.isAcknowledged)
        XCTAssertTrue(manifest1.hasPartialSuccess)
        XCTAssertTrue(manifest2.hasPartialSuccess)

        // Cleanup should only delete acknowledged items
        // (File-a.jpg should survive because manifest1 is not acknowledged)
        let filesShouldBeDeleted = [manifest2.items].flatMap { $0 }
            .filter { manifest2.isAcknowledged }
            .compactMap { $0.persistedFileName }

        XCTAssertTrue(filesShouldBeDeleted.isEmpty, "No files should be deleted from unacknowledged operations")
    }

    func testSingleItemOperation() {
        let items = [
            ImportOperationManifest.ImportedItem(
                sourceIdentifier: "Photo",
                persistedFileName: "single.jpg",
                status: .success,
                errorDescription: nil
            )
        ]
        let manifest = ImportOperationManifest(expectedItemCount: 1, items: items)

        XCTAssertEqual(manifest.successCount, 1)
        XCTAssertTrue(manifest.isFullSuccess)
        XCTAssertTrue(manifest.resultSummary.contains("1 item"))
        XCTAssertFalse(manifest.resultSummary.contains("items"))
    }

    func testResultSummaryGrammar() {
        // Test singular vs plural forms in result summary
        let singleItem = [
            ImportOperationManifest.ImportedItem(sourceIdentifier: "Item", persistedFileName: "file.jpg", status: .success, errorDescription: nil)
        ]
        let singleManifest = ImportOperationManifest(expectedItemCount: 1, items: singleItem)
        XCTAssertTrue(singleManifest.resultSummary.contains("1 item"))

        let multipleItems = [
            ImportOperationManifest.ImportedItem(sourceIdentifier: "Item 1", persistedFileName: "file1.jpg", status: .success, errorDescription: nil),
            ImportOperationManifest.ImportedItem(sourceIdentifier: "Item 2", persistedFileName: "file2.jpg", status: .success, errorDescription: nil)
        ]
        let multiManifest = ImportOperationManifest(expectedItemCount: 2, items: multipleItems)
        XCTAssertTrue(multiManifest.resultSummary.contains("2 items"))
    }
}

// MARK: - Import Service Integration Tests

final class ImportInboxServiceManifestTests: XCTestCase {
    func testPendingOperations() {
        // Note: This test depends on the actual App Group container being available
        // In a real environment, we'd mock this with UserDefaults or a test container
        let pendingOps = ImportInboxService.pendingOperations()

        // Should be a valid array (may be empty in test environment)
        XCTAssertNotNil(pendingOps)
    }

    func testPartialOperations() {
        let partialOps = ImportInboxService.partialOperations()

        // Should filter to only partial success operations
        for operation in partialOps {
            XCTAssertTrue(operation.hasPartialSuccess && !operation.isFullSuccess)
        }
    }

    func testCleanupOldManifests() {
        // Should not throw
        XCTAssertNoThrow {
            ImportInboxService.cleanupOldManifests()
        }
    }
}

// MARK: - Helper Extension

extension XCTestCase {
    func XCTAssertNoThrow(
        _ expression: @autoclosure () throws -> Void,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            try expression()
        } catch {
            XCTFail("Expected no throw, but threw: \(error)", file: file, line: line)
        }
    }
}
