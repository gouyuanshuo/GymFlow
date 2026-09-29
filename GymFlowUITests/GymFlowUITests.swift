import UIKit
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
        XCTAssertTrue(app.buttons["set-1-weight-picker"].exists)
        XCTAssertTrue(app.buttons["set-1-repetitions-picker"].exists)
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

        assertElement(app.buttons["set-1-weight-picker"], isInside: firstCard)
        assertElement(app.buttons["set-1-repetitions-picker"], isInside: firstCard)
        let initialCompletionButton = app.buttons["Complete set 1"].exists
            ? app.buttons["Complete set 1"]
            : app.buttons["Mark set 1 incomplete"]
        assertElement(initialCompletionButton, isInside: firstCard)
        assertElement(warmup, isInside: firstCard)

        let weightButton = app.buttons["set-1-weight-picker"]
        let initialWeight = weightButton.value as? String
        weightButton.tap()
        let weightWheel = app.pickerWheels.firstMatch
        XCTAssertTrue(weightWheel.waitForExistence(timeout: 5))
        weightWheel.adjust(toPickerWheelValue: "72.5")
        dismissWorkoutValuePicker(using: "cancel-workout-value", in: app)
        XCTAssertEqual(weightButton.value as? String, initialWeight)

        weightButton.tap()
        XCTAssertTrue(weightWheel.waitForExistence(timeout: 5))
        weightWheel.adjust(toPickerWheelValue: "72.5")
        dismissWorkoutValuePicker(using: "confirm-workout-value", in: app)
        XCTAssertEqual(weightButton.value as? String, "72.5 kilograms")

        weightButton.tap()
        XCTAssertTrue(weightWheel.waitForExistence(timeout: 5))
        XCTAssertEqual(weightWheel.value as? String, "72.5")
        dismissWorkoutValuePicker(using: "cancel-workout-value", in: app)

        let repetitionsButton = app.buttons["set-1-repetitions-picker"]
        repetitionsButton.tap()
        let repetitionsWheel = app.pickerWheels.firstMatch
        XCTAssertTrue(repetitionsWheel.waitForExistence(timeout: 5))
        repetitionsWheel.adjust(toPickerWheelValue: "10")
        dismissWorkoutValuePicker(using: "confirm-workout-value", in: app)
        XCTAssertEqual(repetitionsButton.value as? String, "10 repetitions")

        repetitionsButton.tap()
        XCTAssertTrue(repetitionsWheel.waitForExistence(timeout: 5))
        repetitionsWheel.adjust(toPickerWheelValue: "11")
        dismissWorkoutValuePicker(using: "cancel-workout-value", in: app)
        XCTAssertEqual(repetitionsButton.value as? String, "10 repetitions")
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
        XCTAssertTrue(app.staticTexts["Rest time remaining"].exists)
        XCTAssertTrue(app.buttons["More timer options"].exists)
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
    func testPlateCalculatorTargetFollowsSelectedBar() throws {
        let app = XCUIApplication()
        app.launch()
        openActiveWorkout(in: app)

        let weightButton = app.buttons["set-1-weight-picker"]
        scrollToElement(weightButton, in: app, useMeasuredDrag: true)
        weightButton.tap()
        let weightWheel = app.pickerWheels.firstMatch
        XCTAssertTrue(weightWheel.waitForExistence(timeout: 5))
        if weightWheel.value as? String != "20" {
            weightWheel.adjust(toPickerWheelValue: "20")
        }
        dismissWorkoutValuePicker(using: "confirm-workout-value", in: app)

        let calculator = app.otherElements["workout-set-card-1"]
            .buttons["set-1-plate-calculator"]
        scrollToElement(calculator, in: app, useMeasuredDrag: true)
        calculator.tap()
        XCTAssertTrue(app.navigationBars["Plate Calculator"].waitForExistence(timeout: 5))

        let target = app.staticTexts["plate-target-weight"]
        XCTAssertEqual(target.label, "20")

        selectBar("15 kg (Women's)", in: app)

        let decrease = app.buttons["-5"]
        scrollPlateSheetToVisible(decrease, in: app)
        decrease.tap()
        waitForLabel("15", on: target)

        selectBar("20 kg (Olympic)", in: app)
        waitForLabel("20", on: target)
        keepScreenshot(named: "Plate calculator after heavier bar selection")

        app.buttons["Done"].tap()
        cancelActiveWorkout(in: app)
    }

    @MainActor
    func testCompletedSetHistoryCanScrollToSixthSet() throws {
        let app = XCUIApplication()
        app.launch()
        if app.buttons["Resume Workout"].waitForExistence(timeout: 3) {
            app.buttons["Resume Workout"].tap()
            cancelActiveWorkout(in: app)
        }
        openActiveWorkout(in: app)

        let setCards = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'workout-set-card-'")
        )
        if setCards.count < 6 {
            for number in (setCards.count + 1)...6 {
                addSet(number: number, in: app)
            }
        }
        let completedCount = app.staticTexts["workout-completed-set-count"]
        XCTAssertEqual(completedCount.label, "0 completed")
        let firstExerciseName = app.staticTexts["active-exercise-name"].label
        let nextExercise = app.staticTexts.matching(NSPredicate(
            format: "identifier == %@ AND label != %@",
            "active-exercise-name", firstExerciseName
        )).firstMatch
        for number in 1...6 {
            let completion = app.buttons["set-completion-\(number)"]
            scrollToElement(completion, in: app)
            completion.tap()
            let expectedCount = app.staticTexts.matching(NSPredicate(
                format: "identifier == %@ AND label == %@",
                "workout-completed-set-count", "\(number) completed"
            )).firstMatch
            if number < 6 {
                if !expectedCount.waitForExistence(timeout: 3) {
                    scrollToElement(completion, in: app)
                    completion.press(forDuration: 0.15)
                }
                XCTAssertTrue(expectedCount.waitForExistence(timeout: 3),
                              "Set \(number) completes")
            } else {
                // Completing the final set can advance to the next exercise, removing this card.
                if !nextExercise.waitForExistence(timeout: 3) && !expectedCount.exists {
                    scrollToElement(completion, in: app)
                    completion.press(forDuration: 0.15)
                }
                XCTAssertTrue(nextExercise.waitForExistence(timeout: 3) || expectedCount.exists,
                              "Set 6 completes or advances to the next exercise")
            }
        }

        app.buttons["Finish"].tap()
        let confirmFinish = app.buttons["Finish Workout"].firstMatch
        XCTAssertTrue(confirmFinish.waitForExistence(timeout: 5))
        confirmFinish.tap()
        XCTAssertTrue(app.staticTexts["Workout Complete"].waitForExistence(timeout: 10))
        let saveAndReturn = app.buttons["Save and Return to Today"]
        scrollToHittable(saveAndReturn, in: app)
        saveAndReturn.tap()

        app.tabBars.buttons["History"].tap()
        let latestWorkout = app.buttons.matching(identifier: "history-workout-row").firstMatch
        XCTAssertTrue(latestWorkout.waitForExistence(timeout: 5))
        latestWorkout.tap()
        let viewProgress = app.buttons["View Exercise Progress"].firstMatch
        scrollToHittable(viewProgress, in: app)
        viewProgress.tap()

        let setRow = app.scrollViews.matching(NSPredicate(
            format: "identifier BEGINSWITH 'completed-sets-scroll-'"
        )).firstMatch
        XCTAssertTrue(setRow.waitForExistence(timeout: 5))
        let progressScroll = app.scrollViews["exercise-progress-scroll"]
        keepScreenshot(named: "Exercise progress chart before scrolling")
        let chart = progressScroll.otherElements.matching(
            identifier: "strength-progression-chart"
        ).firstMatch
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let reset = app.buttons["Reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5), "Tapping the chart selects a data point")
        reset.tap()
        XCTAssertFalse(reset.exists)

        for _ in 0..<5 {
            if setRow.isHittable { break }
            progressScroll.swipeUp()
        }
        XCTAssertTrue(setRow.isHittable)
        XCTAssertFalse(app.buttons["Reset"].exists, "Scrolling should not select a chart point")
        let capsules = setRow.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH 'history-set-'"
        ))
        XCTAssertEqual(capsules.count, 6)
        XCTAssertEqual(Set(capsules.allElementsBoundByIndex.map(\.identifier)).count, 6)
        let sixthSet = capsules.element(boundBy: 5)
        for _ in 0..<5 {
            if sixthSet.isHittable, setRow.frame.contains(sixthSet.frame) { break }
            setRow.swipeLeft()
        }
        XCTAssertTrue(sixthSet.isHittable)
        XCTAssertTrue(setRow.frame.contains(sixthSet.frame), "The whole sixth set should be visible")
        keepScreenshot(named: "Exercise progress sixth completed set")
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
        XCTAssertTrue(app.buttons["set-1-weight-picker"].exists)
        XCTAssertTrue(app.buttons["set-1-repetitions-picker"].exists)
        XCTAssertTrue(app.buttons["Set 1 warm-up"].exists)
        XCTAssertFalse(app.staticTexts["Done"].exists)
        XCTAssertTrue(app.buttons["Previous Exercise"].exists)
        XCTAssertTrue(app.buttons["Next Exercise"].exists)
        XCTAssertTrue(app.staticTexts["active-exercise-name"].exists)

        let weightButton = app.buttons["set-1-weight-picker"]
        weightButton.tap()
        let weightWheel = app.pickerWheels.firstMatch
        XCTAssertTrue(weightWheel.waitForExistence(timeout: 5))
        XCTAssertEqual(app.keyboards.count, 0)
        if hadExistingSession {
            dismissWorkoutValuePicker(using: "cancel-workout-value", in: app)
            app.buttons["set-1-repetitions-picker"].tap()
            XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 5))
            XCTAssertEqual(app.keyboards.count, 0)
            dismissWorkoutValuePicker(using: "cancel-workout-value", in: app)
        } else {
            weightWheel.adjust(toPickerWheelValue: "72.5")
            dismissWorkoutValuePicker(using: "confirm-workout-value", in: app)
            XCTAssertEqual(weightButton.value as? String, "72.5 kilograms")

            let repetitionsButton = app.buttons["set-1-repetitions-picker"]
            repetitionsButton.tap()
            let repetitionsWheel = app.pickerWheels.firstMatch
            XCTAssertTrue(repetitionsWheel.waitForExistence(timeout: 5))
            repetitionsWheel.adjust(toPickerWheelValue: "10")
            dismissWorkoutValuePicker(using: "confirm-workout-value", in: app)
            XCTAssertEqual(repetitionsButton.value as? String, "10 repetitions")

            repetitionsButton.tap()
            XCTAssertTrue(repetitionsWheel.waitForExistence(timeout: 5))
            repetitionsWheel.adjust(toPickerWheelValue: "11")
            dismissWorkoutValuePicker(using: "cancel-workout-value", in: app)
            XCTAssertEqual(repetitionsButton.value as? String, "10 repetitions")
        }

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
            XCTAssertTrue(app.buttons["set-4-weight-picker"].exists)
            XCTAssertTrue(app.buttons["set-4-repetitions-picker"].exists)
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
    func testExerciseLibraryAndCalendarNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10))
        settingsTab.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let exerciseLibrary = app.buttons["Exercise Library"]
        var settingsScrollAttempts = 0
        while !exerciseLibrary.isHittable, settingsScrollAttempts < 4 {
            app.swipeUp()
            settingsScrollAttempts += 1
        }
        XCTAssertTrue(exerciseLibrary.waitForExistence(timeout: 5))
        XCTAssertTrue(exerciseLibrary.isHittable)
        keepScreenshot(named: "Settings before opening Exercise Library")
        exerciseLibrary.press(forDuration: 0.15)
        XCTAssertTrue(app.navigationBars["Exercise Library"].waitForExistence(timeout: 5))
        keepScreenshot(named: "Exercise Library after opening")

        let search = app.searchFields["Exercise name"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Bench Press")
        let rows = app.buttons.matching(identifier: "exercise-library-row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        rows.firstMatch.tap()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 5))
        keepScreenshot(named: "Exercise Library detail")

        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(app.scrollViews["workout-calendar"].waitForExistence(timeout: 5))

        let nextMonth = app.buttons["Next Month"]
        let previousMonth = app.buttons["Previous Month"]
        XCTAssertTrue(nextMonth.exists)
        XCTAssertTrue(previousMonth.exists)
        previousMonth.tap()
        XCTAssertTrue(app.buttons["Return to Current Month"].waitForExistence(timeout: 3))
        nextMonth.tap()
        keepScreenshot(named: "Workout Calendar month")

        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let todayIdentifier = "calendar-day-\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        let today = app.buttons[todayIdentifier]
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        let workoutDay = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'calendar-day-' AND NOT label CONTAINS[c] 'no workouts'"
        )).firstMatch
        let expectsWorkout = workoutDay.waitForExistence(timeout: 2)
        (expectsWorkout ? workoutDay : today).tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        if expectsWorkout {
            XCTAssertTrue(app.buttons["Open Workout Details"].firstMatch.waitForExistence(timeout: 5))
        } else {
            XCTAssertTrue(app.staticTexts["No Workout Recorded"].waitForExistence(timeout: 5))
        }
        keepScreenshot(named: "Workout Calendar day")
        app.buttons["Done"].tap()
    }

    @MainActor
    func testReducedMotionTimerAndCompletion() throws {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        let reduceMotion = openReduceMotionSettings(in: settings)
        let wasEnabled = reduceMotion.value as? String == "1"
        let app = XCUIApplication()
        addTeardownBlock {
            await MainActor.run {
                app.terminate()
                settings.activate()
                let restoredSwitch = self.openReduceMotionSettings(in: settings)
                self.setReduceMotion(wasEnabled, using: restoredSwitch)
                settings.terminate()
            }
        }
        setReduceMotion(true, using: reduceMotion)
        keepScreenshot(named: "Reduce Motion enabled in Settings")
        app.launch()
        runReducedMotionTimerAndCompletion(in: app)
    }

    @MainActor
    func testLargeTextReducedMotionTimerAndCompletion() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-GymFlowReduceMotionUITest")
        app.launch()
        runReducedMotionTimerAndCompletion(in: app, captureSetFields: true)
    }

    @MainActor
    private func runReducedMotionTimerAndCompletion(
        in app: XCUIApplication,
        captureSetFields: Bool = false
    ) {
        if app.buttons["Resume Workout"].waitForExistence(timeout: 3) {
            app.buttons["Resume Workout"].tap()
            cancelActiveWorkout(in: app)
        }
        openActiveWorkout(in: app)
        keepScreenshot(named: "Reduced Motion active workout")
        if captureSetFields {
            let repetitions = app.buttons["set-1-repetitions-picker"]
            scrollToElement(repetitions, in: app, useMeasuredDrag: true)
            keepScreenshot(named: "Large-text workout set values")
        }
        let completeSet = app.buttons["Complete set 1"]
        XCTAssertTrue(completeSet.waitForExistence(timeout: 10))
        scrollToElement(completeSet, in: app)
        completeSet.tap()

        let pause = app.buttons["Pause Rest"]
        scrollToElement(pause, in: app)
        XCTAssertTrue(app.staticTexts["Rest time remaining"].exists)
        keepScreenshot(named: "Reduced Motion rest countdown")
        pause.tap()
        XCTAssertTrue(app.buttons["Resume Rest"].waitForExistence(timeout: 5))
        let addThirtySeconds = app.buttons["+30 sec"]
        scrollToElement(addThirtySeconds, in: app)
        addThirtySeconds.tap()
        let skip = app.buttons["Skip Rest"]
        scrollToElement(skip, in: app)
        XCTAssertTrue(app.buttons["More timer options"].isHittable)
        keepScreenshot(named: "Reduced Motion paused timer controls")
        skip.tap()

        app.buttons["Finish"].tap()
        let confirmFinish = app.buttons["Finish Workout"].firstMatch
        XCTAssertTrue(confirmFinish.waitForExistence(timeout: 5))
        confirmFinish.tap()
        XCTAssertTrue(app.staticTexts["Workout Complete"].waitForExistence(timeout: 10))
        keepScreenshot(named: "Reduced Motion static workout celebration")
        let saveAndReturn = app.buttons["Save and Return to Today"]
        scrollToHittable(saveAndReturn, in: app)
        XCTAssertTrue(saveAndReturn.isHittable)
        keepScreenshot(named: "Reduced Motion completion actions")
        saveAndReturn.tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testWorkoutSharingFromCompletionAndHistory() throws {
        let app = XCUIApplication()
        app.launch()

        let resume = app.buttons["Resume Workout"]
        if resume.waitForExistence(timeout: 3) {
            resume.tap()
            cancelActiveWorkout(in: app)
        }

        let start = app.buttons["Start Workout"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        allowRestTimerNotificationsIfNeeded()

        let completeSet = app.buttons["Complete set 1"]
        XCTAssertTrue(completeSet.waitForExistence(timeout: 10))
        completeSet.tap()

        let finish = app.buttons["Finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
        let confirmFinish = app.buttons["Finish Workout"].firstMatch
        XCTAssertTrue(confirmFinish.waitForExistence(timeout: 5))
        confirmFinish.tap()
        XCTAssertTrue(app.staticTexts["Workout Complete"].waitForExistence(timeout: 10))

        let completionShare = app.buttons["share-completed-workout"]
        scrollToHittable(completionShare, in: app)
        completionShare.tap()
        verifySharePreviewAndOpenActivitySheet(in: app, randomize: true)
        dismissActivitySheet(in: app)
        app.navigationBars["Share Preview"].buttons["Done"].tap()

        let saveAndReturn = app.buttons["Save and Return to Today"]
        scrollToHittable(saveAndReturn, in: app)
        saveAndReturn.tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 10))

        let historyTab = app.tabBars.buttons["History"]
        historyTab.tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        let firstWorkout = app.buttons.matching(identifier: "history-workout-row").firstMatch
        XCTAssertTrue(firstWorkout.waitForExistence(timeout: 5))
        firstWorkout.tap()

        let historyShare = app.buttons["share-history-workout"]
        scrollToHittable(historyShare, in: app)
        historyShare.tap()
        verifySharePreviewAndOpenActivitySheet(in: app, randomize: true)
        dismissActivitySheet(in: app)
    }

    @MainActor
    private func selectBar(_ label: String, in app: XCUIApplication) {
        let option = app.buttons[label]
        scrollPlateSheetToVisible(option, in: app)
        XCTAssertFalse(option.isSelected)
        option.tap()
        XCTAssertTrue(option.isSelected)
    }

    @MainActor
    private func waitForLabel(_ label: String, on element: XCUIElement) {
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
    }

    @MainActor
    private func scrollPlateSheetToVisible(_ element: XCUIElement, in app: XCUIApplication) {
        let navigationBar = app.navigationBars["Plate Calculator"]
        let visibleBottom = app.frame.maxY - 44
        let origin = app.coordinate(withNormalizedOffset: .zero)
        for _ in 0..<15 {
            let visibleTop = navigationBar.frame.maxY + 8
            if element.exists,
                element.frame.minY >= visibleTop,
                element.frame.maxY <= visibleBottom,
                element.isHittable
            {
                break
            }
            // The sheet ScrollView reports an AX frame above the visible medium sheet.
            // Use screen coordinates inside the content to scroll or expand it.
            let start = origin.withOffset(CGVector(dx: app.frame.midX, dy: visibleBottom - 40))
            let end = start.withOffset(CGVector(dx: 0, dy: -220))
            start.press(
                forDuration: 0.05, thenDragTo: end,
                withVelocity: .slow, thenHoldForDuration: 0.2
            )
        }
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable, "\(element.identifier) should be reachable by scrolling")
        XCTAssertGreaterThanOrEqual(element.frame.minY, navigationBar.frame.maxY + 8)
        XCTAssertLessThanOrEqual(element.frame.maxY, visibleBottom)
    }

    @MainActor
    private func openReduceMotionSettings(in settings: XCUIApplication) -> XCUIElement {
        let reduceMotion = settings.switches["Reduce Motion"]
        if reduceMotion.waitForExistence(timeout: 2) { return reduceMotion }

        if !settings.navigationBars["Accessibility"].exists {
            let accessibility = settings.buttons["com.apple.settings.accessibility"]
            let search = settings.searchFields.firstMatch
            scrollToVisible(
                accessibility, in: settings.collectionViews.firstMatch,
                top: settings.navigationBars.firstMatch.frame.maxY + 8,
                bottom: search.exists
                    ? min(settings.frame.maxY - 44, search.frame.minY - 8)
                    : settings.frame.maxY - 44,
                horizontalPosition: 0.97
            )
            accessibility.tap()
            XCTAssertTrue(settings.navigationBars["Accessibility"].waitForExistence(timeout: 5))
        }
        let accessibilityTable = settings.tables.firstMatch
        let motion = accessibilityTable.cells.containing(
            .staticText, identifier: "Motion"
        ).firstMatch
        scrollToVisible(
            motion, in: accessibilityTable,
            top: settings.navigationBars.firstMatch.frame.maxY + 8,
            bottom: settings.frame.midY + 100,
            horizontalPosition: 0.97
        )
        motion.buttons["MOTION_TITLE"].tap()
        // A touch during Settings' large-text scrolling can be consumed without navigation.
        for horizontalPosition in [0.32, 0.5, 0.15] {
            if reduceMotion.waitForExistence(timeout: 2) { break }
            motion.coordinate(withNormalizedOffset: CGVector(dx: horizontalPosition, dy: 0.5))
                .press(forDuration: 0.2)
        }
        XCTAssertTrue(settings.navigationBars["Motion"].waitForExistence(timeout: 5))
        XCTAssertTrue(reduceMotion.waitForExistence(timeout: 5))
        return reduceMotion
    }

    @MainActor
    private func setReduceMotion(_ enabled: Bool, using toggle: XCUIElement) {
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertTrue(toggle.isHittable)
        let expectedValue = enabled ? "1" : "0"
        if toggle.value as? String != expectedValue {
            // Settings exposes the entire row as the switch. Its center misses the control.
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        let switchChanged = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expectedValue),
            object: toggle
        )
        XCTAssertEqual(XCTWaiter.wait(for: [switchChanged], timeout: 5), .completed)
    }

    @MainActor
    private func dismissWorkoutValuePicker(using identifier: String, in app: XCUIApplication) {
        let sheet = app.otherElements["workout-value-picker-sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        for _ in 0..<3 {
            let control = app.buttons[identifier]
            XCTAssertTrue(control.waitForExistence(timeout: 3))
            control.tap()
            let dismissed = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"),
                object: sheet
            )
            if XCTWaiter.wait(for: [dismissed], timeout: 5) == .completed { return }
        }
        XCTFail("Value picker should close after \(identifier)")
    }

    @MainActor
    private func cancelActiveWorkout(in app: XCUIApplication) {
        let cancelTimer = app.buttons["Cancel Timer"]
        if cancelTimer.exists {
            cancelTimer.tap()
        }
        let cancelControl = app.buttons["cancel-workout-toolbar"]
        XCTAssertTrue(cancelControl.waitForExistence(timeout: 5))
        cancelControl.tap()
        let confirmation = app.buttons.matching(
            identifier: "confirm-cancel-workout"
        ).firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func verifySharePreviewAndOpenActivitySheet(
        in app: XCUIApplication,
        randomize: Bool
    ) {
        XCTAssertTrue(app.navigationBars["Share Preview"].waitForExistence(timeout: 10))
        let card = app.otherElements["workout-share-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let workoutDescription = card.label
        XCTAssertFalse(workoutDescription.isEmpty)

        let selectedBackgrounds = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'share-background-' AND value == 'Selected'"
        ))
        XCTAssertEqual(selectedBackgrounds.count, 1)
        let initialBackground = selectedBackgrounds.firstMatch.identifier

        let manualBackground = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'share-background-' AND value == 'Not selected'"
        )).firstMatch
        XCTAssertTrue(manualBackground.waitForExistence(timeout: 5))
        XCTAssertNotEqual(manualBackground.identifier, initialBackground)
        let previewScroll = app.scrollViews["workout-share-preview-scroll"]
        let shareButton = app.buttons["share-workout-image"]
        scrollToVisible(
            manualBackground,
            in: previewScroll,
            top: app.navigationBars["Share Preview"].frame.maxY + 8,
            bottom: shareButton.frame.minY - 8
        )
        let manuallySelectedIdentifier = manualBackground.identifier
        manualBackground.tap()
        let selectedManualBackground = app.buttons.matching(NSPredicate(
            format: "identifier == %@ AND value == 'Selected'",
            manuallySelectedIdentifier
        )).firstMatch
        XCTAssertTrue(selectedManualBackground.waitForExistence(timeout: 5))
        XCTAssertEqual(card.label, workoutDescription)

        if randomize {
            app.buttons["randomize-share-background"].tap()
            let changedBackground = app.buttons.matching(NSPredicate(
                format: "identifier BEGINSWITH 'share-background-' AND value == 'Selected' AND identifier != %@",
                manuallySelectedIdentifier
            )).firstMatch
            XCTAssertTrue(changedBackground.waitForExistence(timeout: 5))
            XCTAssertEqual(card.label, workoutDescription)
        }

        keepScreenshot(named: "Workout share preview")
        app.buttons["share-workout-image"].tap()
        let activityList = app.otherElements["ActivityListView"]
        if !activityList.waitForExistence(timeout: 10) {
            XCTAssertTrue(
                app.buttons["Copy"].exists
                    || app.buttons["Save to Files"].exists
                    || app.buttons["Close"].exists,
                "The native iOS activity sheet should open"
            )
        }
        keepScreenshot(named: "Workout native share sheet")
    }

    @MainActor
    private func dismissActivitySheet(in app: XCUIApplication) {
        let close = app.otherElements["ActivityListView"].buttons["header.closeButton"]
        if close.waitForExistence(timeout: 2) {
            close.tap()
        } else {
            // The activity controller can run outside GymFlow's process.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.13)).tap()
        }
        let done = app.navigationBars["Share Preview"].buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(done.isHittable, "The native share sheet should be dismissed")
    }

    @MainActor
    private func scrollToVisible(
        _ element: XCUIElement,
        in scrollView: XCUIElement,
        top: @autoclosure () -> CGFloat,
        bottom: @autoclosure () -> CGFloat,
        horizontalPosition: CGFloat = 0.5
    ) {
        // Use measured drags so inertial swipes cannot repeatedly overshoot a large-text row.
        for _ in 0..<10 {
            let visibleTop = max(top(), scrollView.frame.minY)
            let visibleBottom = min(bottom(), scrollView.frame.maxY)
            let visibleHeight = visibleBottom - visibleTop
            guard visibleHeight > 80 else {
                XCTFail("Invalid scroll viewport: \(visibleTop)...\(visibleBottom)")
                return
            }
            let frame = element.exists ? element.frame : .zero
            let hasFrame = frame.width > 0 && frame.height > 0
            if hasFrame, frame.minY >= visibleTop, frame.maxY <= visibleBottom {
                break
            }

            let scrollUp = !hasFrame || frame.maxY > visibleBottom
            let overflow = scrollUp ? frame.maxY - visibleBottom : visibleTop - frame.minY
            let distance = hasFrame
                ? min(max(overflow + 12, 44), visibleHeight * 0.45)
                : visibleHeight * 0.45
            // A medium sheet can expose a full-screen accessibility frame. Start
            // near its visible bottom edge so the drag reaches its scroll content.
            let edgeMargin = min(40, visibleHeight * 0.1)
            let startY = visibleBottom - edgeMargin - (scrollUp ? 0 : distance)
            let origin = scrollView.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(
                dx: scrollView.frame.width * horizontalPosition,
                dy: startY - scrollView.frame.minY
            ))
            let end = start.withOffset(CGVector(dx: 0, dy: scrollUp ? -distance : distance))
            start.press(
                forDuration: 0.05, thenDragTo: end,
                withVelocity: .slow, thenHoldForDuration: 0.2
            )
        }
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable, "\(element.identifier) should be reachable by scrolling")
        XCTAssertGreaterThanOrEqual(element.frame.minY, top())
        XCTAssertLessThanOrEqual(element.frame.maxY, bottom())
    }

    @MainActor
    private func scrollToHittable(_ element: XCUIElement, in app: XCUIApplication) {
        let scrollView = app.scrollViews.firstMatch.exists
            ? app.scrollViews.firstMatch
            : app.collectionViews.firstMatch
        var attempts = 0
        while !element.isHittable, attempts < 10 {
            scrollView.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable)
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
    private func scrollToElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        useMeasuredDrag: Bool = false
    ) {
        let scrollView = app.scrollViews.firstMatch
        let visibleTop = app.frame.minY + 110
        let miniPlayer = app.otherElements["music-mini-player"]
        let navigationTop = app.buttons["Next Exercise"].frame.minY - 20
        let visibleBottom = miniPlayer.exists ? miniPlayer.frame.minY - 6 : navigationTop
        if useMeasuredDrag {
            scrollToVisible(element, in: scrollView, top: visibleTop, bottom: visibleBottom)
            return
        }

        // Fast swipes remain reliable while adding many large-text set cards.
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
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable)
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
