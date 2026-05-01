import XCTest

@MainActor
class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Frame 01: Vault with household filter active

    func testVaultFiltered() {
        let app = launch(flags: defaultFlags)
        sleep(3)
        // Tap the household filter chip for "Christian"
        let christianChip = app.buttons.matching(identifier: "filter-christian").firstMatch
        if christianChip.waitForExistence(timeout: 4) {
            christianChip.tap()
            sleep(2)
        }
        snapshot("01-vault-filtered")
    }

    // MARK: - Frame 02: Document detail with expiration warning

    func testDocumentDetailExpiring() {
        _ = launch(flags: defaultFlags + ["--auto-open", "insuranceAuto"])
        sleep(3)
        snapshot("02-detail-expiring")
    }

    // MARK: - Frame 03: Tap-to-share

    func testTapToShare() {
        let app = launch(flags: defaultFlags + ["--auto-open", "insuranceAuto"])
        sleep(3)
        let share = app.buttons.matching(identifier: "share-button").firstMatch
        if share.waitForExistence(timeout: 4) {
            share.tap()
            sleep(3)  // animate in
        }
        snapshot("03-share-sheet")
    }

    // MARK: - Frame 04: Present mode (landscape) — GATED on PR #79

    func testPresentMode() {
        let app = launch(flags: defaultFlags + ["--auto-open", "driversLicense"])
        sleep(3)
        let showNow = app.buttons.matching(identifier: "show-now-button").firstMatch
        if showNow.waitForExistence(timeout: 4) {
            showNow.tap()
            sleep(4)  // wait for landscape rotation animation to complete
        }
        snapshot("04-present-mode")
    }

    // MARK: - Frame 05: Preparedness with household gap drilled in

    func testPreparednessGap() {
        let app = launch(flags: defaultFlags + ["--seed-data", "preparedness"])
        sleep(3)
        // Preparedness checklist is inline in VaultView. Tap the Travel checklist row
        // to drill into household member gaps (Jane's missing passport + vaccine).
        let travelChecklist = app.buttons.matching(identifier: "preparedness-travel").firstMatch
        if travelChecklist.waitForExistence(timeout: 4) {
            travelChecklist.tap()
            sleep(3)  // wait for detail sheet to animate in
        }
        snapshot("05-preparedness-gap")
    }

    // MARK: - Frame 06: Sovereign paywall — contextual upgrade

    func testSovereignPaywall() {
        let unsubFlags = ["--screenshots", "--skip-onboarding", "--mock-unsubscribed", "--seed-data", "full-vault"]
        let app = launch(flags: unsubFlags + ["--auto-open", "driversLicense"])
        sleep(3)
        // Attempt Present Mode → triggers paywall (PresentModeView checks entitlement)
        let showNow = app.buttons.matching(identifier: "show-now-button").firstMatch
        if showNow.waitForExistence(timeout: 4) {
            showNow.tap()
            sleep(3)  // paywall sheet animates in
        }
        snapshot("06-paywall")
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
        return app
    }
}
