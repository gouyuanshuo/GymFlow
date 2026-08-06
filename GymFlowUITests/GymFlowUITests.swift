import XCTest

final class GymFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testStartSetTimerAndCancelWorkout() throws {
        let app = XCUIApplication()
        app.launch()

        let resume = app.buttons["Resume Workout"]
        let start = app.buttons["Start Workout"]
        if resume.waitForExistence(timeout: 3) {
            resume.tap()
        } else {
            XCTAssertTrue(start.waitForExistence(timeout: 10))
            if start.isEnabled {
                start.tap()
            } else {
                XCTAssertTrue(resume.waitForExistence(timeout: 5))
                resume.tap()
            }
        }

        let completeSet = app.buttons["Complete set 1"]
        XCTAssertTrue(completeSet.waitForExistence(timeout: 10))
        completeSet.tap()
        XCTAssertTrue(app.staticTexts["Rest Timer"].waitForExistence(timeout: 5))

        app.buttons["Cancel"].tap()
        let cancelWorkout = app.buttons["Cancel Workout"]
        XCTAssertTrue(cancelWorkout.waitForExistence(timeout: 3))
        cancelWorkout.tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
    }
}
