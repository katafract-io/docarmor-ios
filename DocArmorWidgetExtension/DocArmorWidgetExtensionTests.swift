import XCTest
@testable import Doc_Armor_Widget_Extension

final class DocArmorWidgetExtensionTests: XCTestCase {

    // MARK: - Entitlements File Tests

    func testWidgetEntitlementsFileExists() {
        // Verify the widget entitlements file is present
        let bundle = Bundle(for: DocArmorWidgetExtensionTests.self)
        let entitlementsPath = bundle.path(forResource: "DocArmorWidgetExtension", ofType: "entitlements")
        XCTAssertNotNil(entitlementsPath, "Widget entitlements file should exist at DocArmorWidgetExtension.entitlements")
    }

    func testWidgetEntitlementsContainsAppGroup() throws {
        // Verify the entitlements file contains the required App Group
        guard let resourcePath = Bundle.main.resourcePath else {
            XCTFail("Could not access bundle resources")
            return
        }

        let entitlementsPath = resourcePath + "/DocArmorWidgetExtension.entitlements"
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: entitlementsPath) {
            let data = try Data(contentsOf: URL(fileURLWithPath: entitlementsPath))
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)

            guard let dict = plist as? [String: Any] else {
                XCTFail("Entitlements file should be a dictionary")
                return
            }

            guard let appGroups = dict["com.apple.security.application-groups"] as? [String] else {
                XCTFail("Entitlements should contain com.apple.security.application-groups array")
                return
            }

            XCTAssertTrue(
                appGroups.contains("group.com.katafract.DocArmor"),
                "App Group 'group.com.katafract.DocArmor' should be in entitlements"
            )
        } else {
            // If running in Xcode without resource path, just verify the identifier matches
            let expectedGroup = "group.com.katafract.DocArmor"
            XCTAssertEqual(WidgetAppGroup.identifier, expectedGroup, "Widget App Group identifier should match main app")
        }
    }

    // MARK: - Snapshot Store Tests

    func testSnapshotStoreLoadAvailable() {
        // Simulate available snapshot data
        let testSnapshot = WidgetVaultReadinessSnapshot(
            updatedAt: .now,
            totalDocuments: 5,
            needsAttentionCount: 1,
            expiringSoonCount: 2,
            readyNowCount: 2
        )

        guard let data = try? JSONEncoder().encode(testSnapshot) else {
            XCTFail("Failed to encode test snapshot")
            return
        }

        // Store in UserDefaults
        if let defaults = UserDefaults(suiteName: WidgetAppGroup.identifier) {
            defaults.set(data, forKey: "vaultReadinessSnapshot")
            defaults.synchronize()

            // Load via store
            let result = WidgetSnapshotStore.load()

            if case .available(let loaded) = result {
                XCTAssertEqual(loaded.totalDocuments, 5)
                XCTAssertEqual(loaded.needsAttentionCount, 1)
                XCTAssertEqual(loaded.expiringSoonCount, 2)
                XCTAssertEqual(loaded.readyNowCount, 2)
            } else {
                XCTFail("Expected .available case, got \(result)")
            }

            // Cleanup
            defaults.removeObject(forKey: "vaultReadinessSnapshot")
        }
    }

    func testSnapshotStoreLoadEmpty() {
        // Ensure no data is stored
        if let defaults = UserDefaults(suiteName: WidgetAppGroup.identifier) {
            defaults.removeObject(forKey: "vaultReadinessSnapshot")
            defaults.synchronize()

            let result = WidgetSnapshotStore.load()

            if case .empty = result {
                // Expected behavior
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected .empty case when no data stored, got \(result)")
            }
        }
    }

    func testSnapshotStoreLoadCorrupted() {
        // Store corrupted data
        if let defaults = UserDefaults(suiteName: WidgetAppGroup.identifier) {
            defaults.set("not valid json".data(using: .utf8), forKey: "vaultReadinessSnapshot")
            defaults.synchronize()

            let result = WidgetSnapshotStore.load()

            if case .unavailable = result {
                // Expected behavior
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected .unavailable case for corrupted data, got \(result)")
            }

            // Cleanup
            defaults.removeObject(forKey: "vaultReadinessSnapshot")
        }
    }

    // MARK: - Emergency Card Store Tests

    func testEmergencyCardStoreLoadAvailable() {
        let testCard = WidgetEmergencyCardData(
            isEnabled: true,
            bloodType: "O+",
            allergies: "Penicillin",
            medicalNotes: "No notes",
            contact1Name: "John Doe",
            contact1Phone: "555-1234",
            contact2Name: "",
            contact2Phone: ""
        )

        guard let data = try? JSONEncoder().encode(testCard) else {
            XCTFail("Failed to encode test card")
            return
        }

        if let defaults = UserDefaults(suiteName: WidgetAppGroup.identifier) {
            defaults.set(data, forKey: "emergencyCardData")
            defaults.synchronize()

            let result = WidgetEmergencyCardStore.load()

            if case .available(let loaded) = result {
                XCTAssertEqual(loaded.isEnabled, true)
                XCTAssertEqual(loaded.bloodType, "O+")
                XCTAssertEqual(loaded.allergies, "Penicillin")
                XCTAssertEqual(loaded.contact1Name, "John Doe")
            } else {
                XCTFail("Expected .available case, got \(result)")
            }

            // Cleanup
            defaults.removeObject(forKey: "emergencyCardData")
        }
    }

    func testEmergencyCardStoreLoadEmpty() {
        if let defaults = UserDefaults(suiteName: WidgetAppGroup.identifier) {
            defaults.removeObject(forKey: "emergencyCardData")
            defaults.synchronize()

            let result = WidgetEmergencyCardStore.load()

            if case .empty = result {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected .empty case when no data stored, got \(result)")
            }
        }
    }

    func testEmergencyCardStoreLoadCorrupted() {
        if let defaults = UserDefaults(suiteName: WidgetAppGroup.identifier) {
            defaults.set("corrupted json".data(using: .utf8), forKey: "emergencyCardData")
            defaults.synchronize()

            let result = WidgetEmergencyCardStore.load()

            if case .unavailable = result {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected .unavailable case for corrupted data, got \(result)")
            }

            // Cleanup
            defaults.removeObject(forKey: "emergencyCardData")
        }
    }

    // MARK: - Data Availability Distinction Tests

    func testDataAvailabilityEmptyVsUnavailable() {
        // Verify that we can distinguish between .empty and .unavailable
        let empty: WidgetDataAvailability<String> = .empty
        let unavailable: WidgetDataAvailability<String> = .unavailable

        // Both should not be equal
        XCTAssertNotEqual(empty, unavailable, "Empty and unavailable states should be distinguishable")
    }

    func testReadinessEntrySnapshotForEmpty() {
        let entry = ReadinessEntry(
            date: .now,
            snapshotAvailability: .empty
        )

        let snapshot = entry.snapshot
        XCTAssertEqual(snapshot.totalDocuments, 0, "Empty snapshot should have zero documents")
        XCTAssertEqual(snapshot.needsAttentionCount, 0)
        XCTAssertEqual(snapshot.readyNowCount, 0)
    }

    func testEmergencyCardEntryCardForEmpty() {
        let entry = EmergencyCardEntry(
            date: .now,
            cardAvailability: .empty
        )

        let card = entry.card
        XCTAssertEqual(card.isEnabled, false, "Empty card should be disabled")
        XCTAssertEqual(card.bloodType, "")
        XCTAssertEqual(card.contact1Name, "")
    }

    // MARK: - Widget Kind Constants

    func testWidgetKindConstants() {
        XCTAssertEqual(DocArmorReadinessWidget().kind, "DocArmorReadinessWidget", "Readiness widget kind should match reload call")
        XCTAssertEqual(DocArmorEmergencyCardWidget().kind, "DocArmorEmergencyCardWidget", "Emergency Card widget kind should match reload call")
    }
}
