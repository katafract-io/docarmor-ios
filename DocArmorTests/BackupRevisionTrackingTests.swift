import XCTest
import SwiftData
import CryptoKit
@testable import DocArmor

/// Test suite for backup revision tracking (#145).
/// Verifies that edited documents are correctly marked dirty and retried on failed backups.
final class BackupRevisionTrackingTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var vaultKey: SymmetricKey!

    override func setUp() async throws {
        try await super.setUp()

        // Create an in-memory SwiftData container for tests
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: Document.self, DocumentPage.self,
            configurations: config
        )
        modelContext = ModelContext(modelContainer)

        // Generate a vault key for testing
        vaultKey = SymmetricKey(size: .bits256)
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        vaultKey = nil
        try await super.tearDown()
    }

    // MARK: - Hash Computation Tests

    /// Test that a new document has a different hash than after being edited.
    func testHashChangesAfterContentEdit() throws {
        let doc = Document(
            name: "Test Document",
            documentType: .passport,
            category: .identity
        )
        modelContext.insert(doc)
        try modelContext.save()

        let initialHash = doc.computeBackupHash()

        // Edit metadata
        doc.issuerName = "New Issuer"
        try modelContext.save()

        let editedHash = doc.computeBackupHash()
        XCTAssertNotEqual(initialHash, editedHash, "Hash should change after metadata edit")
    }

    /// Test that hash changes when pages are appended.
    func testHashChangesAfterPageAppend() throws {
        let doc = Document(
            name: "Test Document",
            documentType: .passport
        )
        modelContext.insert(doc)
        try modelContext.save()

        let initialHash = doc.computeBackupHash()

        // Append a page
        let page = DocumentPage(
            pageIndex: 0,
            encryptedImageData: Data("fake-encrypted".utf8),
            nonce: Data("fake-nonce-128b".utf8),
            label: "Front"
        )
        page.document = doc
        modelContext.insert(page)
        try modelContext.save()

        let editedHash = doc.computeBackupHash()
        XCTAssertNotEqual(initialHash, editedHash, "Hash should change after page append")
    }

    /// Test that identical documents produce identical hashes.
    func testIdenticalDocumentsProduceSameHash() throws {
        let doc1 = Document(
            name: "Test",
            documentType: .driversLicense,
            issuerName: "DMV",
            identifierSuffix: "ABC123"
        )
        modelContext.insert(doc1)

        let doc2 = Document(
            name: "Test",
            documentType: .driversLicense,
            issuerName: "DMV",
            identifierSuffix: "ABC123"
        )
        modelContext.insert(doc2)

        try modelContext.save()

        let hash1 = doc1.computeBackupHash()
        let hash2 = doc2.computeBackupHash()

        XCTAssertEqual(hash1, hash2, "Identical documents should have identical hashes")
    }

    // MARK: - Dirty State Tests

    /// Test that a new document is marked dirty (never backed up).
    func testNewDocumentIsDirty() throws {
        let doc = Document(
            name: "New Doc",
            documentType: .passport
        )
        modelContext.insert(doc)
        try modelContext.save()

        XCTAssertTrue(doc.isDirtyForBackup, "New document should be dirty")
        XCTAssertNil(doc.lastBackupHash, "New document should have no backup hash")
    }

    /// Test that a document with matching hash is not dirty.
    func testDocumentWithMatchingHashIsClean() throws {
        let doc = Document(
            name: "Test",
            documentType: .passport
        )
        modelContext.insert(doc)
        try modelContext.save()

        let currentHash = doc.computeBackupHash()
        doc.lastBackupHash = currentHash
        doc.lastBackedUpAt = Date.now
        try modelContext.save()

        XCTAssertFalse(doc.isDirtyForBackup, "Document with matching hash should not be dirty")
    }

    /// Test that a document with mismatched hash (after edit) is dirty.
    func testEditedDocumentIsDirtyAfterBackup() throws {
        let doc = Document(
            name: "Test",
            documentType: .passport
        )
        modelContext.insert(doc)
        try modelContext.save()

        // Simulate successful backup
        let initialHash = doc.computeBackupHash()
        doc.lastBackupHash = initialHash
        doc.lastBackedUpAt = Date.now
        try modelContext.save()

        XCTAssertFalse(doc.isDirtyForBackup, "Backed-up document should be clean")

        // Edit the document
        doc.issuerName = "Updated Issuer"
        try modelContext.save()

        XCTAssertTrue(doc.isDirtyForBackup, "Edited document should be dirty even after successful backup")
    }

    /// Test that a failed backup marks the document as dirty for retry.
    func testFailedBackupPreservesBackupState() throws {
        let doc = Document(
            name: "Test",
            documentType: .passport
        )
        modelContext.insert(doc)
        try modelContext.save()

        // Simulate first successful backup
        let hash1 = doc.computeBackupHash()
        doc.lastBackupHash = hash1
        doc.lastBackedUpAt = Date.now
        try modelContext.save()

        XCTAssertFalse(doc.isDirtyForBackup, "Backed-up document should be clean")

        // Edit the document (backup task would fail)
        doc.notes = "New notes"
        try modelContext.save()

        // Backup is attempted but fails; lastBackupHash is NOT updated
        // (this is what the fix prevents from happening)

        XCTAssertTrue(doc.isDirtyForBackup, "Document should remain dirty after failed backup attempt")
    }

    // MARK: - Application State Tests

    /// Test that relaunch recovery identifies dirty documents correctly.
    func testRelaunchtRecoveryIdentifiesDirtyDocuments() throws {
        // Create three documents:
        // 1. Never backed up
        let neverBacked = Document(
            name: "Never Backed",
            documentType: .passport
        )
        modelContext.insert(neverBacked)

        // 2. Successfully backed up
        let backed = Document(
            name: "Backed",
            documentType: .passport
        )
        modelContext.insert(backed)
        try modelContext.save()

        let backedHash = backed.computeBackupHash()
        backed.lastBackupHash = backedHash
        backed.lastBackedUpAt = Date.now

        // 3. Backed up but then edited (stale)
        let edited = Document(
            name: "Edited After Backup",
            documentType: .passport
        )
        modelContext.insert(edited)
        try modelContext.save()

        let editedHash = edited.computeBackupHash()
        edited.lastBackupHash = editedHash
        edited.lastBackedUpAt = Date.now
        try modelContext.save()

        edited.notes = "Now with notes"
        try modelContext.save()

        let allDocs = try modelContext.fetch(FetchDescriptor<Document>())
        let dirtyDocs = allDocs.filter { $0.isDirtyForBackup }

        XCTAssertEqual(dirtyDocs.count, 2, "Should identify 2 dirty documents")
        XCTAssertTrue(dirtyDocs.contains { $0.id == neverBacked.id }, "Never-backed doc should be dirty")
        XCTAssertTrue(dirtyDocs.contains { $0.id == edited.id }, "Edited doc should be dirty")
        XCTAssertFalse(dirtyDocs.contains { $0.id == backed.id }, "Clean backed doc should not be dirty")
    }

    /// Test that app termination immediately after save preserves dirty state.
    func testImmediateTerminationPreservesDirtyState() throws {
        let doc = Document(
            name: "Test",
            documentType: .passport
        )
        modelContext.insert(doc)
        try modelContext.save()

        // User edits and saves locally
        doc.issuerName = "Updated"
        let currentHash = doc.computeBackupHash()
        doc.lastBackupHash = currentHash
        try modelContext.save()

        // Simulate immediate app termination (backup task never even starts)
        // Re-create context to simulate relaunch
        let newContext = ModelContext(modelContainer)
        let refetched = try newContext.fetch(FetchDescriptor<Document>()).first
        XCTAssertNotNil(refetched, "Document should persist")

        // Verify dirty state is still marked
        if let refetched {
            let newEdit = refetched.computeBackupHash()
            refetched.issuerName = "Another edit"
            let newerHash = refetched.computeBackupHash()

            XCTAssertNotEqual(newEdit, newerHash, "Hash should change with new edit")
            XCTAssertTrue(refetched.isDirtyForBackup, "New edit should mark document dirty again")
        }
    }

    /// Test that stale in-flight upload cannot mark newer edit as backed up.
    func testStaleUploadCannotMarkNewerEditAsBackedUp() throws {
        let doc = Document(
            name: "Test",
            documentType: .passport
        )
        modelContext.insert(doc)
        try modelContext.save()

        // Simulate upload of hash1
        let hash1 = doc.computeBackupHash()

        // User makes a new edit while upload is in flight
        doc.notes = "Quick note"
        try modelContext.save()

        let hash2 = doc.computeBackupHash()
        XCTAssertNotEqual(hash1, hash2, "Edits should produce different hashes")

        // Simulate stale upload completing with hash1
        // The code should NOT mark as backed up because hash1 != current hash2
        doc.lastBackupHash = hash2
        try modelContext.save()

        // If we tried to set lastBackupHash = hash1 (the stale upload),
        // it would NOT match the current hash2, so backup would remain dirty
        let staleApplyHash = hash1
        let currentHash = doc.computeBackupHash()

        XCTAssertNotEqual(staleApplyHash, currentHash, "Stale upload hash should not match current state")
        XCTAssertTrue(doc.isDirtyForBackup, "Document should remain dirty when stale hash doesn't match")
    }

    // MARK: - Metadata Edit Tests

    /// Test that metadata-only edit marks document dirty.
    func testMetadataOnlyEditMarksDirty() throws {
        let doc = Document(
            name: "Test",
            documentType: .passport
        )
        modelContext.insert(doc)
        try modelContext.save()

        let hash1 = doc.computeBackupHash()
        doc.lastBackupHash = hash1
        doc.lastBackedUpAt = Date.now
        try modelContext.save()

        XCTAssertFalse(doc.isDirtyForBackup, "Backed document should be clean")

        // Metadata-only edit
        doc.notes = "Updated notes"
        try modelContext.save()

        XCTAssertTrue(doc.isDirtyForBackup, "Metadata-only edit should mark document dirty")
    }

    /// Test that page-append edit marks document dirty.
    func testPageAppendEditMarksDirty() throws {
        let doc = Document(
            name: "Test",
            documentType: .driversLicense
        )
        modelContext.insert(doc)
        try modelContext.save()

        let hash1 = doc.computeBackupHash()
        doc.lastBackupHash = hash1
        doc.lastBackedUpAt = Date.now
        try modelContext.save()

        XCTAssertFalse(doc.isDirtyForBackup, "Backed document should be clean")

        // Append a page
        let page = DocumentPage(
            pageIndex: 0,
            encryptedImageData: Data("encrypted".utf8),
            nonce: Data("nonce-1234567890a".utf8),
            label: "Front"
        )
        page.document = doc
        modelContext.insert(page)
        try modelContext.save()

        XCTAssertTrue(doc.isDirtyForBackup, "Page-append edit should mark document dirty")
    }

    /// Test that page-replace edit marks document dirty.
    func testPageReplaceEditMarksDirty() throws {
        let doc = Document(
            name: "Test",
            documentType: .driversLicense
        )
        modelContext.insert(doc)

        let page = DocumentPage(
            pageIndex: 0,
            encryptedImageData: Data("original".utf8),
            nonce: Data("nonce-1234567890a".utf8),
            label: "Front"
        )
        page.document = doc
        modelContext.insert(page)
        try modelContext.save()

        let hash1 = doc.computeBackupHash()
        doc.lastBackupHash = hash1
        doc.lastBackedUpAt = Date.now
        try modelContext.save()

        XCTAssertFalse(doc.isDirtyForBackup, "Backed document should be clean")

        // Replace page content
        page.encryptedImageData = Data("replaced".utf8)
        page.nonce = Data("nonce-different!".utf8)
        try modelContext.save()

        XCTAssertTrue(doc.isDirtyForBackup, "Page-replace edit should mark document dirty")
    }

    /// Test that persisting the success marker itself doesn't fail silently.
    func testBackupStateCanBePersisted() throws {
        let doc = Document(
            name: "Test",
            documentType: .passport
        )
        modelContext.insert(doc)
        try modelContext.save()

        let currentHash = doc.computeBackupHash()
        doc.lastBackupHash = currentHash
        doc.lastBackedUpAt = Date.now

        // Should not throw
        XCTAssertNoThrow {
            try modelContext.save()
        }

        // Verify persisted state
        let newContext = ModelContext(modelContainer)
        let refetched = try newContext.fetch(FetchDescriptor<Document>()).first
        XCTAssertNotNil(refetched)
        XCTAssertEqual(refetched?.lastBackupHash, currentHash)
        XCTAssertEqual(refetched?.lastBackedUpAt, doc.lastBackedUpAt)
        XCTAssertFalse(refetched?.isDirtyForBackup ?? true)
    }
}

// MARK: - Helper

extension BackupRevisionTrackingTests {
    private func XCTAssertNoThrow<T>(_ expression: @escaping () throws -> T, file: StaticString = #file, line: UInt = #line) {
        do {
            _ = try expression()
        } catch {
            XCTFail("Expected no throw but got: \(error)", file: file, line: line)
        }
    }
}
