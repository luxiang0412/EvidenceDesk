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
        var args = Self.languageArguments("en") + ["--test-storage-name", storageName, "--reset-test-storage"]
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
        // Relaunch per section: the segmented picker is mirrored onto the Touch
        // Bar on this hardware and synthetic clicks on it are unreliable (D-013).
        let sections = ["overview", "sources", "evidence", "findings", "timeline", "report"]
        for section in sections {
            launch(seed: true, extraArguments: ["--ed-section", section])
            XCTAssertTrue(waitForSectionContent(section),
                          "section \(section) should render before capture")
            capture("light-\(section)")
        }
    }

    func testCaptureDarkAppearance() throws {
        launch(seed: true,
               extraArguments: ["--ed-section", "overview"],
               environment: ["EVIDENCE_DESK_APPEARANCE": "dark"])
        XCTAssertTrue(heading("Case Overview", in: app).waitForExistence(timeout: 25))
        capture("dark-01-overview")

        launch(seed: true,
               extraArguments: ["--ed-section", "findings"],
               environment: ["EVIDENCE_DESK_APPEARANCE": "dark"])
        XCTAssertTrue(element(identifier: "findingRow.F-001", in: app).waitForExistence(timeout: 25))
        capture("dark-02-findings")
    }

    func testCaptureEmptyStates() throws {
        // Empty library.
        launch(seed: false)
        assertEmptyState("No Research Cases", in: app, timeout: 25)
        capture("empty-01-library")

        // Archived library, entered through the app's QA launch state so the
        // capture does not depend on clicking a Touch Bar–mirrored toggle.
        launch(seed: false, extraArguments: ["--ed-show-archived"])
        assertEmptyState("No Archived Cases", in: app, timeout: 25)
        capture("empty-02-archived")

        // Search with no results, same rationale (typed input goes through the
        // user's input method and is not reproducible).
        launch(seed: true, extraArguments: ["--ed-search", "zzzz-no-such-case"])
        assertEmptyState("No Matching Cases", in: app, timeout: 25)
        capture("empty-03-no-search-results")
    }

    func testCapturePDFReader() throws {
        launch(seed: true, extraArguments: ["--ed-section", "sources"])
        let pdfRow = element(identifier: "sourceRow.S-003", in: app)
        XCTAssertTrue(pdfRow.waitForExistence(timeout: 25))
        pdfRow.click()
        XCTAssertTrue(app.buttons["New Evidence from Selection"].firstMatch
            .waitForExistence(timeout: 25), "PDF reader must load")
        // Window screenshots capture the composited contents, including PDFKit.
        capture("light-pdf-reader")
    }

    func testCaptureMinimumWindowSize() throws {
        launch(seed: true,
               extraArguments: ["--ed-section", "overview"],
               environment: ["EVIDENCE_DESK_WINDOW_SIZE": "980x640"])
        XCTAssertTrue(heading("Case Overview", in: app).waitForExistence(timeout: 25))
        capture("min-size-01-overview")
    }

    func testCaptureSavedState() throws {
        launch(seed: true, extraArguments: ["--ed-section", "overview"])
        XCTAssertTrue(app.textFields["Title"].firstMatch.waitForExistence(timeout: 25))
        // Editing marks the case dirty, then the debounced save settles.
        let title = app.textFields["Title"].firstMatch
        title.click()
        title.typeKey(.rightArrow, modifierFlags: [])
        title.typeText(" ")
        XCTAssertTrue(element(identifier: "saveState.saved", in: app).waitForExistence(timeout: 20),
                      "the indicator must report Saved only after a real write")
        capture("state-01-saved")
    }

    /// Confirms a section actually rendered its own content.
    private func waitForSectionContent(_ section: String) -> Bool {
        switch section {
        case "overview": return heading("Case Overview", in: app).waitForExistence(timeout: 25)
        case "sources": return element(identifier: "sourceRow.S-001", in: app).waitForExistence(timeout: 25)
        case "evidence": return element(identifier: "evidenceRow.E-001", in: app).waitForExistence(timeout: 25)
        case "findings": return element(identifier: "findingRow.F-001", in: app).waitForExistence(timeout: 25)
        case "timeline": return element(identifier: "timelineRow.Tender announced", in: app).waitForExistence(timeout: 25)
        case "report": return app.textViews.firstMatch.waitForExistence(timeout: 25)
        default: return false
        }
    }

    private func capture(_ name: String) {
        let window = app.windows.firstMatch
        let screenshot = window.exists ? window.screenshot() : XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
