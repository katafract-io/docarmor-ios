import XCTest

@MainActor
final class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments = ["-ScreenshotMode", "seedData"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    /// Screenshot 1: Home grid — 5 synthetic documents
    func test_01_HomeGrid() throws {
        sleep(2)
        snapshot("01_HomeGrid")
    }

    /// Screenshot 2: Document detail — OCR text + pages + encryption
    func test_02_DocumentDetail() throws {
        let homeGrid = app.collectionViews.firstMatch
        if homeGrid.exists, homeGrid.cells.count > 0 {
            homeGrid.cells.element(boundBy: 0).tap()
            sleep(2)
            snapshot("02_DocumentDetail")
        }
    }

    /// Screenshot 3: Vault / Grid view — all documents
    func test_03_VaultGrid() throws {
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            let vaultButton = tabBar.buttons.matching(NSPredicate(format: "label CONTAINS 'vault' OR label CONTAINS 'Vault'")).firstMatch
            if vaultButton.exists {
                vaultButton.tap()
                sleep(2)
                snapshot("03_VaultGrid")
            }
        }
    }

    /// Screenshot 4: Settings — Face ID + encryption + iCloud
    func test_04_Settings() throws {
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            let settingsButton = tabBar.buttons.matching(NSPredicate(format: "label CONTAINS 'settings' OR label CONTAINS 'Settings'")).firstMatch
            if settingsButton.exists {
                settingsButton.tap()
                sleep(2)
                snapshot("04_Settings")
            }
        }
    }

    /// Screenshot 5: Paywall — Unlock or Sovereign state
    func test_05_Paywall() throws {
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            let settingsButton = tabBar.buttons.matching(NSPredicate(format: "label CONTAINS 'settings' OR label CONTAINS 'Settings'")).firstMatch
            if settingsButton.exists {
                settingsButton.tap()
                sleep(1)
                let subscriptionButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Subscription' OR label CONTAINS 'subscription' OR label CONTAINS 'Upgrade'")).firstMatch
                if subscriptionButton.exists {
                    subscriptionButton.tap()
                    sleep(2)
                    snapshot("05_Paywall")
                }
            }
        }
    }

    /// Screenshot 6: Add document flow
    func test_06_AddDocument() throws {
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '+'")).firstMatch
        if addButton.exists {
            addButton.tap()
            sleep(2)
            snapshot("06_AddDocument")
        }
    }

    /// Screenshot 7: Preparedness checklist
    func test_07_Preparedness() throws {
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            let settingsButton = tabBar.buttons.matching(NSPredicate(format: "label CONTAINS 'settings' OR label CONTAINS 'Settings'")).firstMatch
            if settingsButton.exists {
                settingsButton.tap()
                sleep(1)
                let preparednessButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Preparedness'")).firstMatch
                if preparednessButton.exists {
                    preparednessButton.tap()
                    sleep(2)
                    snapshot("07_Preparedness")
                }
            }
        }
    }
}

// MARK: - iPad Pro 13-inch (M5) Variants

@MainActor
final class ScreenshotTests_iPad: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments = ["-ScreenshotMode", "seedData"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func test_iPad_01_VaultGrid() throws {
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            let vaultButton = tabBar.buttons.matching(NSPredicate(format: "label CONTAINS 'vault' OR label CONTAINS 'Vault'")).firstMatch
            if vaultButton.exists {
                vaultButton.tap()
                sleep(2)
                snapshot("01_VaultGrid_iPad")
            }
        }
    }

    func test_iPad_02_DocumentDetail() throws {
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            let vaultButton = tabBar.buttons.matching(NSPredicate(format: "label CONTAINS 'vault' OR label CONTAINS 'Vault'")).firstMatch
            if vaultButton.exists {
                vaultButton.tap()
                sleep(1)
                let firstDoc = app.cells.element(boundBy: 0)
                if firstDoc.exists {
                    firstDoc.tap()
                    sleep(2)
                    snapshot("02_DocumentDetail_iPad")
                }
            }
        }
    }

    func test_iPad_03_Settings() throws {
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            let settingsButton = tabBar.buttons.matching(NSPredicate(format: "label CONTAINS 'settings' OR label CONTAINS 'Settings'")).firstMatch
            if settingsButton.exists {
                settingsButton.tap()
                sleep(2)
                snapshot("03_Settings_iPad")
            }
        }
    }
}
