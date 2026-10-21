import XCTest

/// Product-critical flows beyond navigation: evidence creation through the
/// editor, source deletion with both evidence policies, export commands, and the
/// PDF reader's selection contract.
///
/// Section selection is driven by the app's `--ed-section` launch argument
/// rather than by clicking the segmented picker. Picker clicks proved flaky
/// under automation (a Touch Bar mirror of the control competes for the click),
/// and the section a test needs is environmental, not the behaviour under test.
///
/// Known automation limits (docs/DECISIONS.md D-013):
/// - Dragging a text selection inside PDFKit cannot be synthesised, so the
///   selection→prefill half is covered by
///   `PDFTests.selectionExtractionReturnsTextAndOneBasedPage`.
/// - `NSSavePanel` runs out of process for a sandboxed app, so export *content*
///   is verified against real files in `ReportExporterPathTests` while this
///   suite verifies the commands are correctly wired.
final class EvidenceDeskCriticalFlowTests: XCTestCase {
    var app: XCUIApplication!
    let storageName = "EvidenceDesk-Critical"

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    /// Launches the seeded fixture with the given section already open.
    private func launch(section: String) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--test-storage-name", storageName,
            "--reset-test-storage",
            "--seed-demo",
            "--ed-section", section
        ]
        app.launch()
        app.activate()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 30))
        // The seeded case is auto-selected; wait for the section's own content.
        XCTAssertTrue(app.radioButtons[sectionTitle(section)].waitForExistence(timeout: 20))
    }

    private func sectionTitle(_ raw: String) -> String {
        switch raw {
        case "overview": return "Overview"
        case "sources": return "Sources"
        case "evidence": return "Evidence"
        case "findings": return "Findings"
        case "timeline": return "Timeline"
        case "report": return "Report"
        default: return raw
        }
    }

    // MARK: - Editor contract
    //
    // Creating evidence *through the sheet* is exercised by
    // `PersistenceTests`/`PersistenceRestartTests` at the model layer, but cannot
    // be asserted through XCUITest: dismissing the editor sheet while an
    // accessibility client is attached reproducibly crashes SwiftUI's
    // accessibility layer (docs/DECISIONS.md D-014). What is verified here is
    // the shell contract around it.

    func testEvidenceSectionExposesCreationEntryPoint() throws {
        launch(section: "evidence")

        let newEvidence = app.buttons["New Evidence"].firstMatch
        XCTAssertTrue(newEvidence.waitForExistence(timeout: 20))
        XCTAssertTrue(newEvidence.isEnabled)
        XCTAssertTrue(row("evidenceRow.E-001").waitForExistence(timeout: 20),
                      "seeded evidence must be listed")
        attachWindowScreenshot("evidence-section", of: app)
    }

    // MARK: - PDF reader contract

    func testPDFReaderOffersSelectionActionOnlyWhenTextIsSelected() throws {
        launch(section: "sources")
        selectSource("S-003")

        let newEvidence = app.buttons["New Evidence from Selection"].firstMatch
        XCTAssertTrue(newEvidence.waitForExistence(timeout: 20),
                      "reader must offer the selection action")
        XCTAssertFalse(newEvidence.isEnabled,
                       "the action must stay disabled until text is selected")

        XCTAssertTrue(app.buttons.matching(identifier: "minus.magnifyingglass").firstMatch.exists
                      || app.buttons["Zoom Out"].exists, "reader must offer zoom out")
        XCTAssertTrue(app.buttons.matching(identifier: "plus.magnifyingglass").firstMatch.exists
                      || app.buttons["Zoom In"].exists, "reader must offer zoom in")
        attachWindowScreenshot("pdf-reader", of: app)
    }

    // MARK: - Delete-source confirmation contract
    //
    // Executing the confirmation choices is covered at the model layer
    // (`PersistenceTests.deleteSourceKeepingEvidenceDetaches` and
    // `deleteSourceAlsoRemovesEvidence`). XCUITest cannot activate SwiftUI
    // `confirmationDialog` buttons here — the dialog mirrors onto the Touch Bar
    // and its in-window buttons ignore synthetic clicks — so this test asserts
    // that both policies are offered, which is the part users rely on to avoid
    // silent data loss.

    func testDeleteSourceOffersBothEvidencePolicies() throws {
        launch(section: "sources")
        selectSource("S-002")
        deleteSourceButton().click()

        XCTAssertTrue(dialogButton(label: "Delete Source and Keep Evidence").waitForExistence(timeout: 15),
                      "keeping the evidence must be offered")
        XCTAssertTrue(dialogButton(beginsWith: "Delete Source and Its Evidence").exists,
                      "deleting the evidence too must be offered separately")
        XCTAssertTrue(dialogButton(label: "Cancel").exists, "cancelling must always be possible")
        attachWindowScreenshot("delete-source-confirmation", of: app)
    }

    // MARK: - Export commands

    func testExportCommandsAreWiredAndDoNotDisturbData() throws {
        launch(section: "report")

        let exportMarkdown = row("report.exportMarkdown")
        XCTAssertTrue(exportMarkdown.waitForExistence(timeout: 25))
        XCTAssertEqual(exportMarkdown.isEnabled, true,
                       "export must be enabled once a preview exists")

        // Invoking the command opens the system save panel. It is an
        // out-of-process panel, so assert the app stays healthy and the report
        // survives a cancelled export.
        exportMarkdown.click()
        sleep(2)
        app.typeKey(.escape, modifierFlags: [])
        sleep(1)

        let reportText = app.textViews.firstMatch
        XCTAssertTrue(reportText.waitForExistence(timeout: 20))
        XCTAssertTrue(((reportText.value as? String) ?? "").contains("## Research Question"),
                      "preview must survive a cancelled export")

        let exportBundle = row("report.exportBundle")
        XCTAssertTrue(exportBundle.exists)
        XCTAssertTrue(exportBundle.isEnabled)
    }

    func testExportMenuShortcutDoesNotCrash() throws {
        launch(section: "overview")
        app.typeKey("e", modifierFlags: [.command, .shift])
        sleep(3)
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(app.windows.firstMatch.exists)
        XCTAssertTrue(app.radioButtons["Report"].exists, "the workspace must remain usable")
    }

    // MARK: - Helpers

    private func row(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Confirmation-dialog buttons are mirrored onto the Touch Bar, which cannot
    /// be clicked. Scope the query to the sheet/window first.
    private func dialogButton(label: String) -> XCUIElement {
        dialogQuery { query in
            query.matching(NSPredicate(format: "label == %@", label))
        }
    }

    private func dialogButton(beginsWith prefix: String) -> XCUIElement {
        dialogQuery { query in
            query.matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
        }
    }

    /// The predicate is built inside the closure so it never crosses an
    /// isolation boundary (NSPredicate is not Sendable under Swift 6).
    private func dialogQuery(
        _ filter: (XCUIElementQuery) -> XCUIElementQuery
    ) -> XCUIElement {
        let sheet = app.sheets.firstMatch
        if sheet.exists {
            let candidate = filter(sheet.buttons).firstMatch
            if candidate.exists { return candidate }
        }
        return filter(app.windows.firstMatch.buttons).firstMatch
    }

    private func selectSource(_ code: String) {
        let source = row("sourceRow.\(code)")
        XCTAssertTrue(source.waitForExistence(timeout: 20), "\(code) must be listed")
        source.click()
        XCTAssertTrue(deleteSourceButton().waitForExistence(timeout: 15),
                      "source detail must expose its delete action")
    }

    private func deleteSourceButton() -> XCUIElement {
        app.windows.firstMatch.descendants(matching: .any)
            .matching(identifier: "source.delete").firstMatch
    }

}
