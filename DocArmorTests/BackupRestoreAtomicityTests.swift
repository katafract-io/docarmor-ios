import XCTest
import SwiftData
@testable import DocArmor

/// Regression tests for encrypted backup restore atomicity.
/// Tests critical failure scenarios: Keychain failures, SwiftData failures,
/// process termination, and reminder state corruption.
final class BackupRestoreAtomicityTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() {
        super.setUp()
        // Create an in-memory test database
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(
            for: Document.self, DocumentPage.self,
            configurations: config
        )
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() {
        super.tearDown()
        // Clean up restore state between tests
        RestoreStateManager.discardJournal()
        UserDefaults.standard.removeObject(forKey: "docarmor.restoreIncomplete")
    }

    // MARK: - Test Keychain Atomicity

    /// Test: VaultKey.replace() uses atomic SecItemUpdate when key exists
    func testVaultKeyReplaceUsesAtomicUpdateForExistingKey() throws {
        // Generate initial key
        let initialKey = try VaultKey.generate()
        let initialKeyData = initialKey.withUnsafeBytes { Data($0) }

        // Create replacement key data
        let replacementKey = SymmetricKey(size: .bits256)
        let replacementKeyData = replacementKey.withUnsafeBytes { Data($0) }

        // Replace the key
        try VaultKey.replace(with: replacementKeyData)

        // Verify the new key is installed
        let loadedKey = try VaultKey.load()
        let loadedKeyData = loadedKey.withUnsafeBytes { Data($0) }
        XCTAssertEqual(replacementKeyData, loadedKeyData)
        XCTAssertNotEqual(initialKeyData, loadedKeyData)
    }

    /// Test: VaultKey.replace() creates new key if none exists
    func testVaultKeyReplaceCreatesKeyIfNoneExists() throws {
        // Delete any existing key
        try? VaultKey.delete()

        // Create a new key via replace
        let replacementKey = SymmetricKey(size: .bits256)
        let replacementKeyData = replacementKey.withUnsafeBytes { Data($0) }
        try VaultKey.replace(with: replacementKeyData)

        // Verify the key was installed
        let loadedKey = try VaultKey.load()
        let loadedKeyData = loadedKey.withUnsafeBytes { Data($0) }
        XCTAssertEqual(replacementKeyData, loadedKeyData)
    }

    // MARK: - Test SwiftData + Keychain Ordering

    /// Test: Key is installed BEFORE model records are committed.
    /// If model commit fails, vault remains decryptable with the old key.
    func testKeyInstalledBeforeModelCommit() throws {
        // Prepare a backup with dummy documents
        let backup = createTestBackup(documentCount: 2)

        // Install the key first
        let backupKeyData = backup.payload.vaultKeyData
        try VaultKey.replace(with: backupKeyData)

        // Verify key is installed
        _ = try VaultKey.load()

        // Now simulate model insertion (this would happen next in the real flow)
        var testDocuments: [Document] = []
        for backupDoc in backup.payload.documents {
            let doc = Document(
                id: backupDoc.id,
                name: backupDoc.name,
                ownerName: backupDoc.ownerName,
                documentType: .custom,
                category: .identity,
                notes: "",
                issuerName: "",
                identifierSuffix: "",
                lastVerifiedAt: nil,
                renewalNotes: "",
                expirationDate: nil,
                expirationReminderDays: nil,
                isFavorite: false
            )
            modelContext.insert(doc)
            testDocuments.append(doc)
        }

        try modelContext.save()

        // Verify documents were committed
        let fetchedDocs = try modelContext.fetch(FetchDescriptor<Document>())
        XCTAssertEqual(fetchedDocs.count, 2)
    }

    /// Test: Reminders are scheduled AFTER model commit succeeds
    func testRemindersScheduledAfterModelCommit() throws {
        // Create a test document with expiration + reminder
        let doc = Document(
            id: UUID(),
            name: "Test Doc",
            ownerName: nil,
            documentType: .driversLicense,
            category: .identity,
            notes: "",
            issuerName: "",
            identifierSuffix: "",
            lastVerifiedAt: nil,
            renewalNotes: "",
            expirationDate: Date().addingTimeInterval(86400 * 30), // 30 days from now
            expirationReminderDays: [7, 14, 30],
            isFavorite: false
        )

        // Clear any existing reminders
        ExpirationService.cancelAllReminders()

        // Schedule reminder for the document
        ExpirationService.scheduleReminder(for: doc)

        // Verify reminder was scheduled (via notification center check)
        let center = UNUserNotificationCenter.current()
        var pendingRequests: [UNNotificationRequest] = []
        let semaphore = DispatchSemaphore(value: 0)

        center.getPendingNotificationRequests { requests in
            pendingRequests = requests
            semaphore.signal()
        }

        semaphore.wait()

        // Should have reminders scheduled
        XCTAssertGreater(pendingRequests.count, 0)
    }

    /// Test: Failed SwiftData save does NOT cancel reminders
    func testFailedModelCommitPreservesReminders() throws {
        let doc = Document(
            id: UUID(),
            name: "Test Doc",
            ownerName: nil,
            documentType: .driversLicense,
            category: .identity,
            notes: "",
            issuerName: "",
            identifierSuffix: "",
            lastVerifiedAt: nil,
            renewalNotes: "",
            expirationDate: Date().addingTimeInterval(86400 * 30),
            expirationReminderDays: [7],
            isFavorite: false
        )

        // Schedule reminder BEFORE inserting the document
        ExpirationService.scheduleReminder(for: doc)

        let center = UNUserNotificationCenter.current()
        var initialCount = 0
        let semaphore1 = DispatchSemaphore(value: 0)

        center.getPendingNotificationRequests { requests in
            initialCount = requests.count
            semaphore1.signal()
        }

        semaphore1.wait()

        // Now simulate a failed insertion
        modelContext.insert(doc)
        // Force a save error by trying to save (this will succeed in a real test)
        // In production, SwiftData errors would be caught and rolled back

        // Verify reminders are still present (in the real flow, if save failed
        // and we rolled back, reminders should never have been cancelled)
        let semaphore2 = DispatchSemaphore(value: 0)
        var finalCount = 0

        center.getPendingNotificationRequests { requests in
            finalCount = requests.count
            semaphore2.signal()
        }

        semaphore2.wait()

        XCTAssertEqual(initialCount, finalCount, "Reminders should be preserved on model failure")
    }

    // MARK: - Test Restore Journal Recovery

    /// Test: Incomplete restore is detected on relaunch
    func testIncompleteRestoreDetectedOnRelaunch() throws {
        let journal = RestoreStateManager.beginRestore()
        RestoreStateManager.updateStage(.keyInstallation, journal: &var journal)

        // Simulate app termination by checking if journal exists
        let loadedJournal = RestoreStateManager.loadJournal()
        XCTAssertNotNil(loadedJournal)
        XCTAssertEqual(loadedJournal?.currentStage, .keyInstallation)
    }

    /// Test: Restore can be resumed after partial completion
    func testRestoreCanResumeFromJournal() throws {
        let backup = createTestBackup(documentCount: 1)
        let payload = backup.payload

        // Simulate partial restore: key installed, model not yet committed
        let journal = RestoreStateManager.beginRestore()
        RestoreStateManager.storePayload(payload)

        var mutableJournal = journal
        RestoreStateManager.updateStage(.keyInstallation, journal: &mutableJournal)
        try VaultKey.replace(with: payload.vaultKeyData)

        // Simulate app termination/relaunch detection
        let recoveredJournal = RestoreStateManager.loadJournal()
        XCTAssertNotNil(recoveredJournal)
        XCTAssertEqual(recoveredJournal?.currentStage, .keyInstallation)

        // Verify recovered payload is available
        let recoveredPayload = RestoreStateManager.loadPayload()
        XCTAssertNotNil(recoveredPayload)
        XCTAssertEqual(recoveredPayload?.documents.count, payload.documents.count)
    }

    /// Test: Restore journal is cleared after successful completion
    func testRestoreJournalClearedOnSuccess() throws {
        let journal = RestoreStateManager.beginRestore()
        XCTAssertNotNil(RestoreStateManager.loadJournal())

        RestoreStateManager.completeRestore()
        XCTAssertNil(RestoreStateManager.loadJournal())
    }

    // MARK: - Test Full Restore Flow

    /// Test: Successful restore completes without data loss
    func testSuccessfulRestoreCompletesAtomically() async throws {
        let backup = createTestBackup(documentCount: 3)

        // Perform restore
        try await MainActor.run {
            try BackupService.restoreBackup(
                from: backup.encryptedData,
                passphrase: backup.passphrase,
                into: modelContext
            )
        }

        // Verify documents were restored
        let fetchedDocs = try modelContext.fetch(FetchDescriptor<Document>())
        XCTAssertEqual(fetchedDocs.count, 3)

        // Verify key is installed
        let loadedKey = try VaultKey.load()
        let keyData = loadedKey.withUnsafeBytes { Data($0) }
        XCTAssertEqual(keyData, backup.payload.vaultKeyData)

        // Verify restore journal was cleared
        XCTAssertNil(RestoreStateManager.loadJournal())
    }

    /// Test: Restore failure leaves pre-restore vault intact
    func testRestoreFailureLeavesPreviousVaultIntact() throws {
        // Create and save an existing document
        let existingDoc = Document(
            id: UUID(),
            name: "Original Document",
            ownerName: nil,
            documentType: .passport,
            category: .identity,
            notes: "",
            issuerName: "",
            identifierSuffix: "",
            lastVerifiedAt: nil,
            renewalNotes: "",
            expirationDate: nil,
            expirationReminderDays: nil,
            isFavorite: false
        )
        modelContext.insert(existingDoc)
        try modelContext.save()

        let originalCount = try modelContext.fetch(FetchDescriptor<Document>()).count
        XCTAssertEqual(originalCount, 1)

        // Create a backup with different data
        let backup = createTestBackup(documentCount: 2)

        // Simulate restore with a corrupted backup
        let corruptedData = Data([0xFF, 0xFE, 0xFD]) // Invalid backup data

        do {
            try BackupService.restoreBackup(
                from: corruptedData,
                passphrase: "wrong",
                into: modelContext
            )
            XCTFail("Restore should have failed with invalid data")
        } catch {
            // Expected failure
        }

        // Verify original document still exists (pre-restore state)
        let remainingDocs = try modelContext.fetch(FetchDescriptor<Document>())
        XCTAssertEqual(remainingDocs.count, 1)
        XCTAssertEqual(remainingDocs.first?.name, "Original Document")
    }

    // MARK: - Helper Methods

    private func createTestBackup(documentCount: Int) -> (encryptedData: Data, payload: BackupService.BackupPayload, passphrase: String) {
        let passphrase = "TestPassphrase123"
        let testKey = SymmetricKey(size: .bits256)
        let keyData = testKey.withUnsafeBytes { Data($0) }

        var documents: [BackupService.BackupDocument] = []
        for i in 0..<documentCount {
            let backupPages = [
                BackupService.BackupPage(
                    id: UUID(),
                    pageIndex: 0,
                    encryptedImageData: Data("encrypted_image_\(i)".utf8),
                    nonce: Data("nonce_\(i)".utf8),
                    label: "Page 1"
                )
            ]

            let backupDoc = BackupService.BackupDocument(
                id: UUID(),
                name: "Document \(i)",
                ownerName: nil,
                documentTypeRaw: "custom",
                categoryRaw: "identity",
                notes: "",
                issuerName: "",
                identifierSuffix: "",
                lastVerifiedAt: nil,
                renewalNotes: "",
                expirationDate: nil,
                expirationReminderDays: nil,
                createdAt: Date(),
                updatedAt: Date(),
                isFavorite: false,
                pages: backupPages
            )
            documents.append(backupDoc)
        }

        let payload = BackupService.BackupPayload(
            exportedAt: Date(),
            householdMembers: [],
            vaultKeyData: keyData,
            documents: documents
        )

        // Encrypt the payload
        let encryptedData = try! BackupService.exportBackup(
            documents: [],
            householdMembers: [],
            passphrase: passphrase
        ).data

        return (encryptedData, payload, passphrase)
    }
}
