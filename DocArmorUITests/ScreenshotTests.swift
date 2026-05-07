import XCTest

@MainActor
class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Frame 01: Vault with household docs

    func testVaultFiltered() {
        // filter-christian lives inside a SwiftUI Menu and is not reachable
        // via the accessibility tree until the menu is expanded; the
        // unfiltered seeded vault is representative for now.
        _ = launch(flags: defaultFlags)
        sleep(3)
        snapshot("01-vault-filtered")
    }

    // MARK: - Frame 02: Document detail with expiration warning

    func testDocumentDetailExpiring() {
        _ = launch(flags: defaultFlags + ["--auto-open", "insuranceAuto"])
        sleep(3)
        snapshot("02-detail-expiring")
    }

    // MARK: - Frame 03: Tap-to-share (Document Actions menu expanded)

    func testTapToShare() {
        let app = launch(flags: defaultFlags + ["--auto-open", "insuranceAuto"])
        sleep(3)
        // Wait for decryption so Share is enabled (it's .disabled when decryptedImages.isEmpty).
        XCTAssertTrue(waitForEnabled(app.buttons["document-actions-menu"], timeout: 10),
                      "Document Actions menu never enabled")
        app.buttons["document-actions-menu"].tap()
        sleep(2) // menu animates in; Share becomes part of accessibility tree
        let share = app.buttons["share-button"]
        XCTAssertTrue(share.waitForExistence(timeout: 4), "share-button missing inside Menu")
        share.tap()
        sleep(3) // confirmation dialog animates in
        snapshot("03-share-sheet")
    }

    // MARK: - Frame 04: Present mode (landscape full-screen)

    func testPresentMode() {
        let app = launch(flags: defaultFlags + ["--auto-open", "driversLicense"])
        sleep(3)
        let showNow = app.buttons["show-now-button"]
        XCTAssertTrue(waitForEnabled(showNow, timeout: 10),
                      "show-now-button never enabled (decryptedImages still empty after 10s)")
        showNow.tap()
        sleep(4) // landscape rotation + present-mode animation
        snapshot("04-present-mode")
    }

    // MARK: - Frame 05: Preparedness with household gap

    func testPreparednessGap() {
        let app = launch(flags: defaultFlags + ["--seed-data", "preparedness"])
        sleep(3)
        let travelChecklist = app.buttons.matching(identifier: "preparedness-travel").firstMatch
        if travelChecklist.waitForExistence(timeout: 4) {
            travelChecklist.tap()
            sleep(3)
        }
        snapshot("05-preparedness-gap")
    }

    // MARK: - Frame 06: Sovereign paywall — contextual upgrade

    func testSovereignPaywall() {
        let unsubFlags = ["--screenshots", "--skip-onboarding", "--mock-unsubscribed", "--seed-data", "full-vault"]
        let app = launch(flags: unsubFlags + ["--auto-open", "driversLicense"])
        sleep(3)
        // Present Mode tap → PresentModeView entitlement check → paywall sheet for unsubscribed.
        let showNow = app.buttons["show-now-button"]
        XCTAssertTrue(waitForEnabled(showNow, timeout: 10),
                      "show-now-button never enabled in unsubscribed mode")
        showNow.tap()
        sleep(3) // paywall sheet animates in
        snapshot("06-paywall")
    }

    // MARK: - Frame 07: Lock screen / biometric gate

    func testLockScreen() {
        // --mock-locked prevents auto-authentication on launch, keeping vault locked
        _ = launch(flags: defaultFlags + ["--mock-locked"])
        sleep(2)
        snapshot("07-lock-screen")
    }

    // MARK: - Frame 08: Import/scan flow — document scanner open

    func testImportScan() {
        // --show-scanner opens the AddDocumentView sheet with scanner displayed on launch
        _ = launch(flags: defaultFlags + ["--show-scanner"])
        sleep(3)
        snapshot("08-import-scan")
    }

    // MARK: - Helpers

    private var defaultFlags: [String] {
        ["--screenshots", "--skip-onboarding", "--mock-subscribed", "--seed-data", "full-vault"]
    }

    private func launch(flags: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += flags
        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 30),
            "App did not reach foreground within 30s — aborting to avoid silent 0-PNG run"
        )
        return app
    }

    /// Polls until the element exists AND is enabled, or timeout.
    /// XCUIElement.waitForExistence returns true even for disabled elements,
    /// so disabled-button taps no-op silently. This catches that case.
    private func waitForEnabled(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isEnabled { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return false
    }
}
