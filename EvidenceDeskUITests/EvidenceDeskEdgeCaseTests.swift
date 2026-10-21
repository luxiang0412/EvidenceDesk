import XCTest

/// Error paths, empty states, search, and menu coverage. Isolated storage per
/// test; never touches real user data or the network.
final class EvidenceDeskEdgeCaseTests: XCTestCase {
    var app: XCUIApplication!
    let storageName = "EvidenceDesk-UIEdge"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--test-storage-name", storageName,
                               "--reset-test-storage"]
        app.launch()
        app.activate()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil

        app = nil
    }

    func testEmptyStateOffersFirstAction() throws {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 25))
        XCTAssertTrue(emptyTitle("No Research Cases").waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["New Research Case"].firstMatch.exists)
        attach("empty-state")
    }

    func testCreateCaseRejectsBlankTitle() throws {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 25))
        XCTAssertTrue(app.buttons["New research case"].waitForExistence(timeout: 15))
        app.buttons["New research case"].click()

        let titleField = app.textFields["Title"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 10))

        // Clicking Create with an empty title surfaces validation, creates nothing.
        app.buttons["Create Case"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["A title is required."].waitForExistence(timeout: 10),
                      "blank title must produce a validation message")
        app.buttons["Cancel"].firstMatch.click()
        XCTAssertTrue(app.buttons["New Research Case"].firstMatch.waitForExistence(timeout: 10))
    }

    func testSearchNoResultState() throws {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 25))
        // Overview has no per-section search field, so the only search field is
        // the library sidebar search.
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        search.click()
        search.typeText("zzzz-no-such-case-zzzz")
        XCTAssertTrue(emptyTitle("No Matching Cases").waitForExistence(timeout: 15))
        attach("search-no-results")
        // Clearing the search returns to the full (empty) list state.
        search.typeKey("a", modifierFlags: .command)
        search.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(emptyTitle("No Research Cases").waitForExistence(timeout: 15))
    }

    func testArchivedEmptyStateIsNotDeletion() throws {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 25))
        app.buttons["Show archived cases"].click()
        XCTAssertTrue(emptyTitle("No Archived Cases").waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Archived cases appear here. Archiving is not deleting."].exists)
        attach("archived-empty")
    }

    func testMenuCommandsExistAndInspectorToggles() throws {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 25))

        let fileMenu = app.menuBars.menuBarItems["File"]
        XCTAssertTrue(fileMenu.exists)
        fileMenu.click()
        for item in ["New Research Case…", "Import Source…", "Export Report…"] {
            XCTAssertTrue(app.menuItems[item].exists, "File menu must contain \(item)")
        }
        app.typeKey(.escape, modifierFlags: [])

        let viewMenu = app.menuBars.menuBarItems["View"]
        XCTAssertTrue(viewMenu.exists)
        viewMenu.click()
        XCTAssertTrue(app.menuItems["Toggle Inspector"].exists)
        app.menuItems["Toggle Inspector"].click()
        // Toggling twice must not break the layout.
        viewMenu.click()
        app.menuItems["Toggle Inspector"].click()
    }

    func testEditMenuIsStandard() throws {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 25))
        let edit = app.menuBars.menuBarItems["Edit"]
        XCTAssertTrue(edit.exists)
        edit.click()
        for item in ["Undo", "Redo", "Cut", "Copy", "Paste", "Select All"] {
            XCTAssertTrue(app.menuItems[item].exists, "Edit menu must contain \(item)")
        }
        app.typeKey(.escape, modifierFlags: [])
    }

    private func emptyTitle(_ label: String) -> XCUIElement {
        app.staticTexts[label].firstMatch
    }

    private func attach(_ name: String) {
        let window = app.windows.firstMatch
        let shot = window.exists ? window.screenshot() : XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}