import XCTest

/// Basic launch tests. Each launch uses a unique isolated storage name resolved
/// inside the app's own sandbox, so real user data is never touched.
final class LaunchTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--test-storage-name", "EvidenceDesk-Launch",
                               "--reset-test-storage"]
        app.launch()
        app.activate()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testAppLaunchesAndShowsWindow() throws {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 25),
                      "App should show a real window")
        XCTAssertTrue(app.windows.firstMatch.isHittable, "Window should be hittable")
    }

    func testFirstLaunchShowsEmptyState() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 25))
        XCTAssertTrue(app.staticTexts["No Research Cases"].waitForExistence(timeout: 15),
                      "First launch must explain the empty library")
        XCTAssertTrue(app.buttons["New Research Case"].firstMatch.exists,
                      "Empty state must offer a first action")
    }
}
