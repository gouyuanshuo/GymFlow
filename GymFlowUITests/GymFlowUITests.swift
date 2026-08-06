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
            cancelActiveWorkout(in: app)
        }
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertTrue(start.isEnabled)
        start.tap()

        let completeSet = app.buttons["Complete set 1"]
        XCTAssertTrue(completeSet.waitForExistence(timeout: 10))
        completeSet.tap()
        XCTAssertTrue(app.staticTexts["Rest Timer"].waitForExistence(timeout: 5))

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["Complete set 2"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Rest Timer"].waitForExistence(timeout: 5))

        app.buttons["Minimize"].tap()
        XCTAssertTrue(app.buttons["Resume Workout"].waitForExistence(timeout: 5))
        app.buttons["Resume Workout"].tap()
        XCTAssertTrue(app.buttons["Complete set 2"].waitForExistence(timeout: 5))

        cancelActiveWorkout(in: app)
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func cancelActiveWorkout(in app: XCUIApplication) {
        let cancelTimer = app.buttons["Cancel Timer"]
        if cancelTimer.exists {
            cancelTimer.tap()
        }
        let workoutOptions = app.buttons["Workout options"]
        XCTAssertTrue(workoutOptions.waitForExistence(timeout: 5))
        workoutOptions.tap()
        let cancelAction = app.buttons["cancel-workout-menu-action"]
        XCTAssertTrue(cancelAction.waitForExistence(timeout: 3))
        cancelAction.tap()
        let confirmation = app.buttons.matching(
            identifier: "confirm-cancel-workout"
        ).firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
    }
}
