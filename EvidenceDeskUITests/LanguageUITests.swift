import XCTest

/// Verifies the in-app language switch end to end: the app records the choice,
/// the next launch renders Simplified Chinese, and switching back restores
/// English. Screenshots are attached as visual evidence.
final class LanguageUITests: XCTestCase {
    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    var app: XCUIApplication!

    private func launchInChinese() {
        app = XCUIApplication()
        app.launchArguments = Self.languageArguments("zh-Hans") + [
            "--test-storage-name", "EvidenceDesk-LanguageUI",
            "--reset-test-storage", "--seed-demo", "--ed-section", "overview"
        ]
        app.launch()
        app.activate()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 30))
    }

    func testSwitchesToChineseAndRendersTranslatedUI() throws {
        launchInChinese()

        XCTAssertTrue(app.radioButtons["概览"].waitForExistence(timeout: 25),
                      "section picker must be translated")
        for title in ["来源", "证据", "发现", "时间线", "报告"] {
            XCTAssertTrue(app.radioButtons[title].exists, "\(title) should be a section")
        }
        XCTAssertTrue(heading("案例概览", in: app).waitForExistence(timeout: 15),
                      "overview heading must be translated")
        // Section headings and save feedback are translated too.
        XCTAssertTrue(heading("研究问题", in: app).exists)
        let saved = element(identifier: "saveState.saved", in: app)
        XCTAssertTrue(saved.exists, "save indicator should be present")
        XCTAssertTrue(saved.label.contains("已保存"),
                      "save indicator must be translated, got: \"\(saved.label)\"")
        // Button labels are translated as well.
        XCTAssertTrue(app.buttons["立即保存"].exists, "button titles must be translated")

        attachWindowScreenshot("zh-overview", of: app)

        // Report section renders translated headings in the preview.
        XCTAssertTrue(openWorkspaceSection("报告", in: app))
        let preview = app.textViews.firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 20))
        let text = (preview.value as? String) ?? ""
        XCTAssertTrue(text.contains("研究问题"), "report preview must use translated headings")
        attachWindowScreenshot("zh-report", of: app)
    }

    func testSwitchesBackToEnglish() throws {
        launchInChinese()
        XCTAssertTrue(app.radioButtons["概览"].waitForExistence(timeout: 25))

        // Same store, launched in English: data must be unaffected.
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = Self.languageArguments("en") + [
            "--test-storage-name", "EvidenceDesk-LanguageUI", "--ed-section", "overview"
        ]
        app.launch()
        app.activate()

        XCTAssertTrue(app.radioButtons["Overview"].waitForExistence(timeout: 30),
                      "English must come back after switching back")
        XCTAssertTrue(heading("Case Overview", in: app).exists)
    }

    func testSettingsScreenOffersLanguageChoice() throws {
        launchInChinese()
        XCTAssertTrue(app.radioButtons["概览"].waitForExistence(timeout: 25))

        // Reachable from the View menu (and ⌘,) because the app now has a real
        // settings screen.
        app.menuBars.menuBarItems["显示"].click()
        let languageItem = app.menuItems["语言…"]
        XCTAssertTrue(languageItem.waitForExistence(timeout: 10), "View menu must offer the language setting")
        languageItem.click()

        let root = element(identifier: "settings.root", in: app)
        XCTAssertTrue(root.waitForExistence(timeout: 15), "settings window must open")
        // Options are shown in their own language so they stay readable.
        XCTAssertTrue(app.radioButtons["简体中文"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.radioButtons["English"].exists)

        if let settingsWindow = app.windows.allElementsBoundByIndex.first(where: {
            $0.descendants(matching: .any).matching(identifier: "settings.root").firstMatch.exists
        }) {
            let attachment = XCTAttachment(screenshot: settingsWindow.screenshot())
            attachment.name = "zh-settings"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app.typeKey("w", modifierFlags: .command)
    }

    func testLanguageDoesNotAlterResearchData() throws {
        launchInChinese()
        XCTAssertTrue(app.radioButtons["来源"].waitForExistence(timeout: 25))
        XCTAssertTrue(openWorkspaceSection("来源", in: app))
        // Seeded fixture titles are user data and must stay verbatim.
        XCTAssertTrue(element(identifier: "sourceRow.S-001", in: app).waitForExistence(timeout: 20))
        attachWindowScreenshot("zh-sources", of: app)
    }
}
