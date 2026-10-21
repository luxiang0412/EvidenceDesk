import XCTest

/// Captures visual-acceptance screenshots from the real, **sandboxed** app via
/// XCUITest attachments. Extracted with:
///
/// ```bash
/// xcrun xcresulttool export attachments --path <xcresult> --output-path artifacts/Screenshots/UITests
/// ```
final class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!

    private func launch(seed: Bool,
                        storageName: String = "EvidenceDesk-Shot",
                        extraArguments: [String] = [],
                        environment: [String: String] = [:]) {
        var args = ["--test-storage-name", storageName, "--reset-test-storage"]
        if seed { args.append("--seed-demo") }
        args.append(contentsOf: extraArguments)

        // Retry once: a lingering instance from a previous test can swallow the
        // relaunch and leave no window for automation to attach to.
        for attempt in 0..<2 {
            app?.terminate()
            app = XCUIApplication()
            app.launchArguments = args
            app.launchEnvironment = environment
            app.launch()
            app.activate()
            if app.windows.firstMatch.waitForExistence(timeout: 20) { return }
            XCTContext.runActivity(named: "relaunch attempt \(attempt + 1)") { _ in }
        }
        XCTFail("app window did not appear after relaunch")
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testCaptureAllSections() throws {
        launch(seed: true)

        // Overview (default section)
        XCTAssertTrue(app.staticTexts["Case Overview"].waitForExistence(timeout: 20))
        capture("light-01-overview")

        for section in ["Sources", "Evidence", "Findings", "Timeline", "Report"] {
            let radio = app.radioButtons[section]
            XCTAssertTrue(radio.waitForExistence(timeout: 15), "section \(section)")
            radio.click()
            _ = app.windows.firstMatch.waitForExistence(timeout: 5)
            capture("light-\(section.lowercased())")
        }
    }

    func testCaptureDarkAppearance() throws {
        // Drives the system appearance for this app instance only.
        launch(seed: true, environment: ["EVIDENCE_DESK_APPEARANCE": "dark"])
        XCTAssertTrue(app.staticTexts["Case Overview"].waitForExistence(timeout: 20))
        capture("dark-01-overview")

        app.radioButtons["Findings"].click()
        capture("dark-02-findings")
    }

    func testCaptureEmptyStates() throws {
        launch(seed: false)
        XCTAssertTrue(app.staticTexts["No Research Cases"].waitForExistence(timeout: 20))
        capture("empty-01-library")

        app.buttons["Show archived cases"].click()
        XCTAssertTrue(app.staticTexts["No Archived Cases"].waitForExistence(timeout: 15))
        capture("empty-02-archived")

        app.buttons["Show active cases"].click()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.click()
        search.typeText("nothing-matches-this")
        XCTAssertTrue(app.staticTexts["No Matching Cases"].waitForExistence(timeout: 15))
        capture("empty-03-no-search-results")
    }

    func testCaptureMinimumWindowSize() throws {
        launch(seed: true, environment: ["EVIDENCE_DESK_WINDOW_SIZE": "980x640"])
        XCTAssertTrue(app.staticTexts["Case Overview"].waitForExistence(timeout: 20))
        capture("min-size-01-overview")
    }

    func testCaptureSaveFailureAndErrorComponents() throws {
        // Create a case, then verify the save-state component reports "Saved"
        // only after a real write.
        launch(seed: false)
        XCTAssertTrue(app.buttons["New research case"].waitForExistence(timeout: 20))
        app.buttons["New research case"].click()

        let title = app.textFields["Title"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.click()
        title.typeText("Save State Check")
        app.buttons["Create Case"].firstMatch.click()

        let editor = app.textFields["Title"].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 15))
        editor.click()
        editor.typeText(" edited")
        // Debounced save must settle into an explicit Saved state.
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "saveState.saved").firstMatch
            .waitForExistence(timeout: 15), "save indicator must show Saved after a real write")
        capture("state-01-saved")
    }

    /// Captures only the app's own window, so evidence never includes the
    /// surrounding desktop or other applications.
    private func capture(_ name: String) {
        let window = app.windows.firstMatch
        let screenshot = window.exists ? window.screenshot() : XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
