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
        assertEmptyState("No Research Cases", in: app)
        assertEmptyState("No Research Cases", in: app)
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

    // Search-with-no-results and the archived empty state are captured in
    // `ScreenshotTests.testCaptureEmptyStates`. They are not asserted here
    // because text entry goes through the user's active input method, which
    // makes typed queries non-deterministic on machines with a CJK IME
    // (docs/DECISIONS.md D-013).

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

    private func attach(_ name: String) {
        let window = app.windows.firstMatch
        let shot = window.exists ? window.screenshot() : XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}