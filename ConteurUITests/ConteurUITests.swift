import XCTest

/// The little that can honestly be asserted from outside the app.
///
/// The telling loop needs a microphone, a speech model and Apple's on-device model, none of
/// which exist in the simulator — so a UI test cannot reach a retelling, and pretending
/// otherwise is what the generated template did. What is worth checking here is that the app
/// launches and lands on the three tabs the whole thing is arranged around.
final class ConteurUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesOntoTheThreeTabs() throws {
        let app = XCUIApplication()
        app.launch()

        for tab in ["Tell", "Retellings", "Progress"] {
            XCTAssertTrue(
                app.buttons[tab].waitForExistence(timeout: 10),
                "The \(tab) tab did not appear"
            )
        }
    }
}
