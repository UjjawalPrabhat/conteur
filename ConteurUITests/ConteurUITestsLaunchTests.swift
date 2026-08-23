import XCTest

/// Attaches a launch screenshot to the test report, per UI configuration.
///
/// Not an assertion — the app is a dark scene drawn in Canvas, and the thing most likely to
/// break in it is how it looks. A screenshot in the report is how that gets noticed.
final class ConteurUITestsLaunchTests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
