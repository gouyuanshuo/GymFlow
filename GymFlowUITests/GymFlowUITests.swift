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
        allowRestTimerNotificationsIfNeeded()

        let completeSet = app.buttons["Complete set 1"]
        XCTAssertTrue(completeSet.waitForExistence(timeout: 10))
        completeSet.tap()
        XCTAssertTrue(app.staticTexts["Rest"].waitForExistence(timeout: 5))

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["Complete set 2"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Rest"].waitForExistence(timeout: 5))

        app.buttons["Minimize"].tap()
        XCTAssertTrue(app.buttons["Resume Workout"].waitForExistence(timeout: 5))
        app.buttons["Resume Workout"].tap()
        XCTAssertTrue(app.buttons["Complete set 2"].waitForExistence(timeout: 5))

        cancelActiveWorkout(in: app)
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testActiveWorkoutCardLayoutAndSetActions() throws {
        let app = XCUIApplication()
        app.launch()

        openActiveWorkout(in: app)

        let firstCard = app.otherElements["workout-set-card-1"]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Set 1"].exists)
        XCTAssertTrue(app.textFields["Set 1 weight"].exists)
        XCTAssertTrue(app.textFields["Set 1 repetitions"].exists)
        XCTAssertTrue(
            app.buttons["Complete set 1"].exists
                || app.buttons["Mark set 1 incomplete"].exists
        )
        XCTAssertFalse(app.staticTexts["Done"].exists)

        let warmup = app.buttons["Set 1 warm-up"]
        XCTAssertTrue(warmup.exists)
        let initialWarmupValue = warmup.value as? String
        warmup.tap()
        XCTAssertNotEqual(warmup.value as? String, initialWarmupValue)

        assertElement(app.textFields["Set 1 weight"], isInside: firstCard)
        assertElement(app.textFields["Set 1 repetitions"], isInside: firstCard)
        let initialCompletionButton = app.buttons["Complete set 1"].exists
            ? app.buttons["Complete set 1"]
            : app.buttons["Mark set 1 incomplete"]
        assertElement(initialCompletionButton, isInside: firstCard)
        assertElement(warmup, isInside: firstCard)
        keepScreenshot(named: "Active Workout set card")

        let setCards = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'workout-set-card-'")
        )
        let initialSetCount = setCards.count
        let firstNewSetNumber = initialSetCount + 1
        addSet(number: firstNewSetNumber, in: app)

        let newestSetNumber = initialSetCount + 2
        addSet(number: newestSetNumber, in: app)
        let newestCard = app.otherElements["workout-set-card-\(newestSetNumber)"]
        scrollToElement(newestCard, in: app)
        XCTAssertTrue(newestCard.exists)
        XCTAssertTrue(app.staticTexts["Set \(newestSetNumber)"].exists)
        keepScreenshot(named: "Active Workout six sets")

        let newestSetActions = app.buttons["set-actions-\(newestSetNumber)"]
        XCTAssertTrue(newestSetActions.waitForExistence(timeout: 5))
        newestSetActions.tap()
        let removeSet = app.buttons["Remove Set"]
        XCTAssertTrue(removeSet.waitForExistence(timeout: 3))
        removeSet.tap()
        XCTAssertFalse(
            app.otherElements["workout-set-card-\(newestSetNumber)"].waitForExistence(timeout: 2)
        )

        let markIncomplete = app.buttons["Mark set 1 incomplete"]
        if markIncomplete.exists {
            scrollToElement(markIncomplete, in: app)
            markIncomplete.tap()
        }
        let completeSet = app.buttons["Complete set 1"]
        scrollToElement(completeSet, in: app)
        completeSet.tap()
        let restLabel = app.staticTexts["Rest"]
        XCTAssertTrue(restLabel.waitForExistence(timeout: 5))
        let addThirtySeconds = app.buttons["+30 sec"]
        let skipRest = app.buttons["Skip Rest"]
        scrollToElement(skipRest, in: app)
        XCTAssertTrue(addThirtySeconds.isHittable)

        let previousExercise = app.buttons["Previous Exercise"]
        let nextExercise = app.buttons["Next Exercise"]
        XCTAssertTrue(previousExercise.exists)
        XCTAssertTrue(nextExercise.exists)
        XCTAssertLessThanOrEqual(nextExercise.frame.maxY, app.frame.maxY)
        keepScreenshot(named: "Active Workout rest timer")

        app.terminate()
    }

    @MainActor
    func testPhysicalActiveWorkoutPresentationWithExistingData() throws {
        let app = XCUIApplication()
        app.launch()

        let hadExistingSession = app.buttons["Resume Workout"].waitForExistence(timeout: 3)
        openActiveWorkout(in: app)

        let firstCard = app.otherElements["workout-set-card-1"]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Set 1"].exists)
        XCTAssertTrue(app.textFields["Set 1 weight"].exists)
        XCTAssertTrue(app.textFields["Set 1 repetitions"].exists)
        XCTAssertTrue(app.buttons["Set 1 warm-up"].exists)
        XCTAssertFalse(app.staticTexts["Done"].exists)
        XCTAssertTrue(app.buttons["Previous Exercise"].exists)
        XCTAssertTrue(app.buttons["Next Exercise"].exists)
        XCTAssertTrue(app.staticTexts["active-exercise-name"].exists)

        if !hadExistingSession {
            let setCards = app.otherElements.matching(
                NSPredicate(format: "identifier BEGINSWITH 'workout-set-card-'")
            )
            let initialSetCount = setCards.count
            if initialSetCount < 4 {
                for setNumber in (initialSetCount + 1) ... 4 {
                    addSet(number: setNumber, in: app)
                }
            }
            let fourthCard = app.otherElements["workout-set-card-4"]
            scrollToElement(fourthCard, in: app)
            XCTAssertTrue(app.staticTexts["Set 4"].exists)
            XCTAssertTrue(app.textFields["Set 4 weight"].exists)
            XCTAssertTrue(app.textFields["Set 4 repetitions"].exists)
            keepScreenshot(named: "Physical Active Workout four sets")
            scrollToElement(firstCard, in: app)
        }

        let previousPerformance = app.otherElements["previous-performance-card"]
        let miniPlayer = app.otherElements["music-mini-player"]
        var startedPlaybackForVerification = false
        if previousPerformance.exists {
            XCTAssertGreaterThan(previousPerformance.frame.height, 0)
        }
        if miniPlayer.exists {
            XCTAssertTrue(app.buttons["Play"].exists || app.buttons["Pause"].exists)
            XCTAssertTrue(app.buttons["Previous"].exists)
            XCTAssertTrue(app.buttons["Next"].exists)
            XCTAssertLessThanOrEqual(miniPlayer.frame.maxY, app.frame.maxY)
            if app.buttons["Play"].exists {
                app.buttons["Play"].tap()
                XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 5))
                startedPlaybackForVerification = true
            }
        }

        keepScreenshot(named: "Physical Active Workout")

        if startedPlaybackForVerification {
            app.buttons["Pause"].tap()
        }

        if hadExistingSession {
            app.buttons["Minimize"].tap()
            XCTAssertTrue(app.buttons["Resume Workout"].waitForExistence(timeout: 5))
        } else {
            let completeSet = app.buttons["Complete set 1"]
            XCTAssertTrue(completeSet.waitForExistence(timeout: 5))
            completeSet.tap()
            XCTAssertTrue(app.staticTexts["Rest"].waitForExistence(timeout: 5))
            cancelActiveWorkout(in: app)
        }
    }

    @MainActor
    func testPlanSelectionOpensExistingPlanOnFirstTapAndCreateIsExplicit() throws {
        let app = XCUIApplication()
        app.launch()

        openPlansTab(in: app)
        let planRows = app.buttons.matching(identifier: "workout-plan-row")
        XCTAssertTrue(planRows.firstMatch.waitForExistence(timeout: 5))
        let originalPlanCount = planRows.count
        verifyExistingPlanOpens(at: 0, in: app)
        if planRows.count > 1 {
            verifyExistingPlanOpens(at: 1, in: app)
        }
        verifyExistingPlanOpens(at: 0, in: app)

        app.terminate()
        app.launch()
        openPlansTab(in: app)
        verifyExistingPlanOpens(at: 0, in: app)

        let createPlan = app.buttons["Create workout plan"]
        XCTAssertTrue(createPlan.waitForExistence(timeout: 5))
        createPlan.tap()
        XCTAssertTrue(app.navigationBars["New Plan"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Workout Plans"].waitForExistence(timeout: 5))
        XCTAssertEqual(
            app.buttons.matching(identifier: "workout-plan-row").count,
            originalPlanCount
        )
    }

    @MainActor
    func testNowPlayingRemainsPresentedUntilExplicitDismissalWhenMusicExists() throws {
        let app = XCUIApplication()
        app.launch()

        var openNowPlaying = app.buttons["open-now-playing"].firstMatch
        if !openNowPlaying.waitForExistence(timeout: 3) {
            let musicTab = app.tabBars.buttons["Music"]
            XCTAssertTrue(musicTab.waitForExistence(timeout: 10))
            musicTab.tap()
            XCTAssertTrue(app.navigationBars["Music"].waitForExistence(timeout: 5))

            let firstTrack = app.buttons["music-library-track"].firstMatch
            guard firstTrack.waitForExistence(timeout: 3) else {
                throw XCTSkip("Now Playing UI verification requires at least one imported local track.")
            }
            firstTrack.tap()
            openNowPlaying = app.buttons["open-now-playing"].firstMatch
            XCTAssertTrue(openNowPlaying.waitForExistence(timeout: 5))
        }

        openNowPlaying.tap()
        assertNowPlayingIsPresented(in: app)

        let tenSeconds = expectation(description: "Now Playing remains open for ten seconds")
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { tenSeconds.fulfill() }
        wait(for: [tenSeconds], timeout: 11)
        assertNowPlayingIsPresented(in: app)

        let pause = app.buttons["Pause"].firstMatch
        if pause.exists {
            pause.tap()
            assertNowPlayingIsPresented(in: app)
        }
        let play = app.buttons["Play"].firstMatch
        if play.exists {
            play.tap()
            assertNowPlayingIsPresented(in: app)
        }

        for control in ["Next", "Previous", "Shuffle"] {
            let button = app.buttons[control].firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 3))
            button.tap()
            assertNowPlayingIsPresented(in: app)
        }

        let repeatButton = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Repeat '")
        ).firstMatch
        XCTAssertTrue(repeatButton.waitForExistence(timeout: 3))
        repeatButton.tap()
        assertNowPlayingIsPresented(in: app)

        app.buttons["Done"].tap()
        XCTAssertFalse(app.navigationBars["Now Playing"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["open-now-playing"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testTodayEstimateReportsHistoricalSourceWhenAvailable() throws {
        let app = XCUIApplication()
        app.launch()

        let estimate = app.descendants(matching: .any).matching(
            identifier: "workout-duration-estimate"
        ).firstMatch
        XCTAssertTrue(estimate.waitForExistence(timeout: 10))
        XCTAssertTrue(estimate.label.hasPrefix("About "))

        let source = estimate.value as? String ?? ""
        guard source.hasPrefix("Based on "), source != "Based on plan targets" else {
            throw XCTSkip("The currently selected workout plan has no valid completed history.")
        }
        XCTAssertTrue(source.hasSuffix("recent workouts"))
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
        let cancelAction = app.buttons["Cancel Workout"].firstMatch
        XCTAssertTrue(cancelAction.waitForExistence(timeout: 3))
        cancelAction.tap()
        let confirmation = app.buttons.matching(
            identifier: "confirm-cancel-workout"
        ).firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openActiveWorkout(in app: XCUIApplication) {
        let resume = app.buttons["Resume Workout"]
        if resume.waitForExistence(timeout: 3) {
            resume.tap()
            allowRestTimerNotificationsIfNeeded()
            return
        }

        let start = app.buttons["Start Workout"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertTrue(start.isEnabled)
        start.tap()
        allowRestTimerNotificationsIfNeeded()
    }

    @MainActor
    private func allowRestTimerNotificationsIfNeeded() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 2) {
            allow.tap()
        }
    }

    @MainActor
    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication) {
        let scrollView = app.scrollViews.firstMatch
        let visibleTop = app.frame.minY + 110
        let miniPlayer = app.otherElements["music-mini-player"]
        let navigationTop = app.buttons["Next Exercise"].frame.minY - 20
        let visibleBottom = miniPlayer.exists ? miniPlayer.frame.minY - 6 : navigationTop
        var attempts = 0

        while attempts < 20 {
            guard element.exists else {
                scrollView.swipeUp()
                attempts += 1
                continue
            }

            if element.frame.maxY > visibleBottom {
                scrollView.swipeUp()
            } else if element.frame.minY < visibleTop {
                scrollView.swipeDown()
            } else {
                break
            }
            attempts += 1
        }

        XCTAssertTrue(element.exists, "\(element.identifier) should remain in the scrollable workout")
        XCTAssertTrue(element.isHittable, "\(element.identifier) should be reachable by scrolling")
        XCTAssertGreaterThanOrEqual(element.frame.minY, visibleTop)
        XCTAssertLessThanOrEqual(element.frame.maxY, visibleBottom)
    }

    @MainActor
    private func addSet(number: Int, in app: XCUIApplication) {
        let expectedCard = app.otherElements["workout-set-card-\(number)"]
        var attempts = 0
        while !expectedCard.exists, attempts < 2 {
            let addSet = app.buttons["add-workout-set"]
            scrollToElement(addSet, in: app)
            addSet.tap()
            _ = expectedCard.waitForExistence(timeout: 3)
            attempts += 1
        }
        XCTAssertTrue(expectedCard.exists, "Add Set should create Set \(number)")
    }

    @MainActor
    private func assertElement(_ element: XCUIElement, isInside container: XCUIElement) {
        XCTAssertTrue(element.exists)
        XCTAssertTrue(container.frame.contains(element.frame))
        XCTAssertGreaterThanOrEqual(
            element.frame.height,
            44,
            "\(element.identifier) should expose at least a 44-point touch target"
        )
    }

    @MainActor
    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func openPlansTab(in app: XCUIApplication) {
        let plansTab = app.tabBars.buttons["Plans"]
        XCTAssertTrue(plansTab.waitForExistence(timeout: 10))
        plansTab.tap()
        XCTAssertTrue(app.navigationBars["Workout Plans"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func verifyExistingPlanOpens(at index: Int, in app: XCUIApplication) {
        let planRow = app.buttons.matching(
            identifier: "workout-plan-row"
        ).element(boundBy: index)
        XCTAssertTrue(planRow.waitForExistence(timeout: 5))
        let visiblePlanName = planRow.staticTexts.firstMatch
        XCTAssertTrue(visiblePlanName.waitForExistence(timeout: 3))
        let expectedName = visiblePlanName.label
        planRow.tap()

        XCTAssertTrue(app.navigationBars["Edit Plan"].waitForExistence(timeout: 5))
        let nameField = app.textFields["Plan name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        XCTAssertEqual(nameField.value as? String, expectedName)

        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Workout Plans"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func assertNowPlayingIsPresented(in app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Now Playing"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["open-now-playing"].exists)
    }
}
