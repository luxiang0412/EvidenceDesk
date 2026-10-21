import XCTest

/// End-to-end UI workflow tests. Each test runs against a unique temporary
/// storage directory (never the real user store) and a synthetic fixture.
final class EvidenceDeskFlowTests: XCTestCase {
    var app: XCUIApplication!
    /// Stable per-class name; wiped with `--reset-test-storage`. Must differ
    /// from other classes so suites never share a store.
    let storageName = "EvidenceDesk-Flow"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--test-storage-name", storageName,
                               "--reset-test-storage", "--seed-demo"]
        app.launch()
        app.activate()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil

        app = nil
    }

    // MARK: - Core loop over seeded data

    func testSeededCaseRendersAllSections() throws {
        // Relaunch per section (via the app's `--ed-section` argument) instead of
        // clicking the segmented picker: on hardware with a Touch Bar the picker
        // is mirrored there and synthetic clicks are unreliable (D-013).
        let sections = ["overview", "sources", "evidence", "findings", "timeline", "report"]
        for section in sections {
            relaunch(section: section)
            XCTAssertTrue(sectionContentIsVisible(section),
                          "section \(section) should render its content")
            attachWindowScreenshot("section-\(section)", of: app)
        }
    }

    func testRestartPreservesData() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 25))
        XCTAssertTrue(row("caseRow.C-001").waitForExistence(timeout: 25),
                      "the seeded case must exist before the restart")

        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--test-storage-name", storageName,
                               "--ed-section", "sources"]
        app.launch()
        app.activate()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 25))
        XCTAssertTrue(row("sourceRow.S-001").waitForExistence(timeout: 25),
                      "sources must survive an app restart")
        attachWindowScreenshot("restart-sources", of: app)
    }

    // MARK: - Create a case through the File menu

    func testCreateCaseEndToEnd() throws {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 25))
        XCTAssertTrue(app.buttons["New research case"].waitForExistence(timeout: 15))
        app.buttons["New research case"].click()

        let titleField = app.textFields["Title"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 10), "new-case sheet must show a Title field")
        titleField.click()
        titleField.typeText("Fresh Case A")

        let create = app.buttons["Create Case"].firstMatch
        XCTAssertTrue(create.exists)
        create.click()

        // The new case gets the next stable code (the fixture seeded C-001).
        XCTAssertTrue(element(identifier: "caseRow.C-002", in: app).waitForExistence(timeout: 20),
                      "the new case must be listed with the next stable code")
        attachWindowScreenshot("new-case", of: app)
    }

    // MARK: - Helpers

    /// Checks the evidence that a section was actually rendered.
    private func sectionContentIsVisible(_ section: String) -> Bool {
        switch section {
        case "overview": return heading("Case Overview", in: app).waitForExistence(timeout: 25)
        case "sources": return row("sourceRow.S-001").waitForExistence(timeout: 25)
        case "evidence": return row("evidenceRow.E-001").waitForExistence(timeout: 25)
        case "findings": return row("findingRow.F-001").waitForExistence(timeout: 25)
        case "timeline": return row("timelineRow.Tender announced").waitForExistence(timeout: 25)
        case "report": return app.textViews.firstMatch.waitForExistence(timeout: 25)
        default: return false
        }
    }

    /// Restarts the app straight into `section`, keeping the same isolated store
    /// (the first launch seeds it).
    private func relaunch(section: String) {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--test-storage-name", storageName,
                               "--ed-section", section]
        app.launch()
        app.activate()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 30))
    }

    private func row(_ identifier: String) -> XCUIElement {
        element(identifier: identifier, in: app)
    }

}