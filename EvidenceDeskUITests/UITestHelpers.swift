import XCTest

/// Shared helpers so every UI test addresses the app the same way.
///
/// Rules learned the hard way (see docs/DECISIONS.md D-013/D-014):
/// - Match text by **label predicate**, not `subscript`: once an element carries
///   an accessibility identifier, `app.staticTexts["Some text"]` matches the
///   *identifier* instead of the label.
/// - Sections are `radioButtons` (segmented control), not `buttons`.
/// - Confirmation dialogs and the save panel mirror onto the Touch Bar, so
///   queries must be scoped to a window/sheet.
extension XCTestCase {
    func staticText(label: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    func element(identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Selects a workspace section and confirms the picker actually switched.
    @discardableResult
    func openWorkspaceSection(_ title: String, in app: XCUIApplication) -> Bool {
        let radio = app.radioButtons[title]
        guard radio.waitForExistence(timeout: 20) else { return false }
        for _ in 1...4 {
            radio.click()
            if waitUntilSectionSelected(title, in: app, timeout: 4) { return true }
        }
        return false
    }

    func waitUntilSectionSelected(_ title: String, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let value = app.radioButtons[title].value
            if let number = value as? Int, number == 1 { return true }
            if let text = value as? String, text == "1" { return true }
            usleep(200_000)
        }
        return false
    }

    /// Polls until `element` reports as non-existent.
    func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists { return true }
            usleep(250_000)
        }
        return !element.exists
    }

    /// Captures only the app window, so evidence never includes the desktop.
    func attachWindowScreenshot(_ name: String, of app: XCUIApplication) {
        let window = app.windows.firstMatch
        let shot = window.exists ? window.screenshot() : XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

extension XCTestCase {
    /// The empty state is exposed as one element whose label is
    /// "<title>. <message>".
    func emptyState(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "emptyState").firstMatch
    }

    func assertEmptyState(_ title: String, in app: XCUIApplication, timeout: TimeInterval = 20,
                          file: StaticString = #filePath, line: UInt = #line) {
        // The library sidebar and the detail pane can both show an empty state,
        // so match any element whose composed label starts with the title.
        let state = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", title))
            .firstMatch
        XCTAssertTrue(state.waitForExistence(timeout: timeout),
                      "empty state for \"\(title)\" should appear", file: file, line: line)
    }

    /// Section headings are exposed with the `isHeader` trait, so they are not
    /// `staticTexts`; match them by label.
    func heading(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", title))
            .firstMatch
    }
}

extension XCTestCase {
    /// Launch arguments that pin the UI language for one process.
    ///
    /// `-AppleLanguages` lands in NSArgumentDomain, so it overrides whatever the
    /// app has persisted without writing any state — UI tests stay deterministic
    /// no matter what language the machine or a previous run left behind.
    static func languageArguments(_ identifier: String) -> [String] {
        ["-AppleLanguages", "(\(identifier))"]
    }
}
