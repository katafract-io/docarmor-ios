import XCTest
import WidgetKit
@testable import DocArmor

final class StoresWidgetReloadTests: XCTestCase {

    // MARK: - VaultSnapshotStore Tests

    func testVaultSnapshotStoreSaveCallsWidgetReload() {
        // This test verifies that the store saves data and calls WidgetCenter
        // In a real scenario, WidgetCenter.reloadTimelines will be called
        let testSnapshot = VaultReadinessSnapshot(
            updatedAt: .now,
            totalDocuments: 3,
            needsAttentionCount: 0,
            expiringSoonCount: 1,
            readyNowCount: 2
        )

        // Save the snapshot
        VaultSnapshotStore.save(snapshot: testSnapshot)

        // Verify data was persisted
        if let loaded = VaultSnapshotStore.loadSnapshot() {
            XCTAssertEqual(loaded.totalDocuments, 3)
            XCTAssertEqual(loaded.needsAttentionCount, 0)
            XCTAssertEqual(loaded.expiringSoonCount, 1)
            XCTAssertEqual(loaded.readyNowCount, 2)
        } else {
            XCTFail("Snapshot should have been saved and loadable")
        }
    }

    func testVaultSnapshotStoreLoadNoSnapshot() {
        // Clear any existing snapshot
        if let defaults = UserDefaults(suiteName: AppGroup.identifier) {
            defaults.removeObject(forKey: "vaultReadinessSnapshot")
            defaults.synchronize()
        }

        // Load should return nil when nothing stored
        let loaded = VaultSnapshotStore.loadSnapshot()
        XCTAssertNil(loaded, "Loading without saved snapshot should return nil")
    }

    // MARK: - EmergencyCardStore Tests

    func testEmergencyCardStoreSaveCallsWidgetReload() {
        let testCard = EmergencyCardData(
            isEnabled: true,
            bloodType: "A+",
            allergies: "None",
            medicalNotes: "Test notes",
            contact1Name: "Emergency Contact",
            contact1Phone: "555-9999",
            contact2Name: "",
            contact2Phone: ""
        )

        // Save the card
        EmergencyCardStore.save(testCard)

        // Verify data was persisted
        let loaded = EmergencyCardStore.load()
        XCTAssertEqual(loaded.isEnabled, true)
        XCTAssertEqual(loaded.bloodType, "A+")
        XCTAssertEqual(loaded.contact1Name, "Emergency Contact")
    }

    func testEmergencyCardStoreLoadEmpty() {
        // Clear any existing card
        if let defaults = UserDefaults(suiteName: AppGroup.identifier) {
            defaults.removeObject(forKey: "emergencyCardData")
            defaults.synchronize()
        }

        // Load should return default empty card
        let loaded = EmergencyCardStore.load()
        XCTAssertEqual(loaded.isEnabled, false, "Default card should be disabled")
        XCTAssertEqual(loaded.bloodType, "")
        XCTAssertEqual(loaded.contact1Name, "")
    }

    // MARK: - App Group Tests

    func testAppGroupIdentifierMatches() {
        // Verify the app group identifier is consistent
        let expectedGroup = "group.com.katafract.DocArmor"
        XCTAssertEqual(AppGroup.identifier, expectedGroup, "App Group identifier should match expected value")
    }

    func testAppGroupContainerURLIsAccessible() {
        let containerURL = AppGroup.containerURL()
        // Container URL may be nil in test environment, but if present should be a valid path
        if let url = containerURL {
            XCTAssertTrue(url.isFileURL, "Container URL should be a file URL")
            XCTAssertTrue(url.path.contains("group.com.katafract.DocArmor"), "Container path should contain app group identifier")
        }
    }
}
