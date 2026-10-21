import XCTest

/// End-to-end UI workflow tests. Each test runs against a unique temporary
/// storage directory (never the real user store) and a synthetic fixture.
final class EvidenceDeskFlowTests: XCTestCase {
    var app: XCUIApplication!
    let storageName = "EvidenceDesk-Flow-\(UUID().uuidString)"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--test-storage-name", storageName, "--seed-demo"]
        app.launch()
        app.activate()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil

        // Locate and remove this run's isolated storage inside the app container.
        removeIsolatedStorage()
    }

    // MARK: - Core loop over seeded data

    func testSeededCaseRendersAllSections() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 25))
        XCTAssertTrue(window.staticTexts["Case Overview"].waitForExistence(timeout: 15))

        openSection("Sources")
        XCTAssertTrue(row("sourceRow.S-001").waitForExistence(timeout: 15))
        XCTAssertTrue(row("sourceRow.S-002").exists)
        XCTAssertTrue(row("sourceRow.S-003").exists)
        attach("sources")

        openSection("Evidence")
        XCTAssertTrue(row("evidenceRow.E-001").waitForExistence(timeout: 15))
        attach("evidence")

        openSection("Findings")
        XCTAssertTrue(row("findingRow.F-001").waitForExistence(timeout: 15))
        attach("findings")

        openSection("Timeline")
        XCTAssertTrue(row("timelineRow.Tender announced").waitForExistence(timeout: 15))
        XCTAssertTrue(row("timelineRow.Decision expected").exists, "undated event stays visible")
        XCTAssertTrue(app.staticTexts["Date Undetermined"].exists)
        attach("timeline")

        openSection("Report")
        // The preview is a read-only text view; assert on the generated content.
        let reportText = app.textViews.firstMatch
        XCTAssertTrue(reportText.waitForExistence(timeout: 20), "report preview text view should exist")
        let reportValue = (reportText.value as? String) ?? ""
        XCTAssertTrue(reportValue.contains("## Research Question"), "report must include the question section")
        XCTAssertTrue(reportValue.contains("## Sources"), "report must include the source list")
        XCTAssertTrue(reportValue.contains("Supporting evidence"), "report must show support group")
        attach("report")
    }

    func testRestartPreservesData() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 25))
        openSection("Sources")
        XCTAssertTrue(row("sourceRow.S-001").waitForExistence(timeout: 15))

        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--test-storage-name", storageName]
        app.launch()
        app.activate()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 25))
        openSection("Sources")
        XCTAssertTrue(row("sourceRow.S-001").waitForExistence(timeout: 15),
                      "sources must survive an app restart")
        attach("restart-sources")
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

        // The new case becomes selected; its row is addressable by stable ID.
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "caseRow.C-"))
            .firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Fresh Case A"].exists
                      || app.descendants(matching: .any)
                        .containing(NSPredicate(format: "label CONTAINS %@", "Fresh Case A")).count > 0)
        attach("new-case")
    }

    // MARK: - Helpers

    private func openSection(_ title: String) {
        let radio = app.radioButtons[title]
        XCTAssertTrue(radio.waitForExistence(timeout: 15), "section \(title) should exist")
        radio.click()
    }

    private func row(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Deletes the isolated store directory the app created for this test.
    private func removeIsolatedStorage() {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.luxiang0412.EvidenceDesk/Data/tmp/EvidenceDeskUITest", isDirectory: true)
        let target = base.appendingPathComponent(storageName, isDirectory: true)
        try? FileManager.default.removeItem(at: target)
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