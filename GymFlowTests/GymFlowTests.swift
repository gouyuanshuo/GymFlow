import AVFoundation
import AppIntents
import Foundation
import MediaPlayer
import SwiftData
import Testing
@testable import GymFlow

@MainActor
struct GymFlowTests {
    @Test("Workout volume only includes completed sets")
    func workoutVolumeCalculation() {
        let completed = WorkoutSetRecord(setNumber: 1, weight: 60, repetitions: 8, isCompleted: true)
        let incomplete = WorkoutSetRecord(setNumber: 2, weight: 100, repetitions: 10)
        let secondCompleted = WorkoutSetRecord(setNumber: 3, weight: 20, repetitions: 12, isCompleted: true)
        let record = ExerciseRecord(exerciseNameSnapshot: "Bench", sets: [completed, incomplete, secondCompleted])
        let session = WorkoutSession(planNameSnapshot: "Test", status: .completed, exerciseRecords: [record])

        #expect(session.trainingVolume == 720)
        #expect(session.totalRepetitions == 20)
        #expect(session.completedSetCount == 2)
    }

    @Test("Plan duplication creates an independent deep copy")
    func planDuplication() {
        let exercise = PlannedExercise(
            exerciseNameSnapshot: "Squat",
            targetSets: 4,
            targetRepetitions: 8,
            targetWeight: 80,
            restSeconds: 180
        )
        let playlistID = UUID()
        let original = WorkoutPlan(
            name: "Legs",
            notes: "Original",
            assignedPlaylistID: playlistID,
            exercises: [exercise]
        )
        let copy = WorkoutService.duplicate(plan: original, now: Date(timeIntervalSince1970: 100))

        #expect(copy.id != original.id)
        #expect(copy.name == "Legs Copy")
        #expect(copy.exercises.count == 1)
        #expect(copy.exercises[0].id != exercise.id)
        #expect(copy.exercises[0].targetWeight == 80)
        #expect(copy.assignedPlaylistID == playlistID)

        copy.exercises[0].targetWeight = 100
        #expect(original.exercises[0].targetWeight == 80)
    }

    @Test("Selecting an existing plan does not create a new plan")
    func existingPlanEditorPresentationDoesNotCreatePlan() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WorkoutPlan.self, PlannedExercise.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let plan = WorkoutPlan(name: "Chest and Arms")
        context.insert(plan)
        try context.save()

        let countBeforeSelection = try context.fetchCount(FetchDescriptor<WorkoutPlan>())
        let editPresentation = PlanEditorPresentation.edit(plan)

        #expect(editPresentation.plan === plan)
        #expect(editPresentation.id == plan.id)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutPlan>()) == countBeforeSelection)

        let createPresentation = PlanEditorPresentation.create()
        #expect(createPresentation.plan == nil)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutPlan>()) == countBeforeSelection)
    }

    @Test("A workout session is created from ordered plan targets")
    func workoutSessionCreation() {
        let later = PlannedExercise(
            exerciseNameSnapshot: "Row",
            targetSets: 2,
            targetRepetitions: 12,
            targetWeight: 30,
            restSeconds: 75,
            sortOrder: 1
        )
        let first = PlannedExercise(
            exerciseNameSnapshot: "Pulldown",
            targetSets: 3,
            targetRepetitions: 10,
            targetWeight: 55,
            restSeconds: 120,
            sortOrder: 0
        )
        let plan = WorkoutPlan(name: "Back", exercises: [later, first])
        let start = Date(timeIntervalSince1970: 1_000)

        let playlist = Playlist(name: "Back Day")
        let session = WorkoutService.makeSession(from: plan, playlist: playlist, now: start)

        #expect(session.workoutPlanID == plan.id)
        #expect(session.planNameSnapshot == "Back")
        #expect(session.status == .active)
        #expect(session.startedAt == start)
        #expect(session.currentExerciseIndex == 0)
        #expect(session.currentSetNumber == 1)
        #expect(session.playlistID == playlist.id)
        #expect(session.playlistNameSnapshot == "Back Day")
        #expect(session.orderedExerciseRecords.map(\.exerciseNameSnapshot) == ["Pulldown", "Row"])
        #expect(session.orderedExerciseRecords[0].sets.count == 3)
        #expect(session.orderedExerciseRecords[0].orderedSets[0].weight == 55)
        #expect(session.orderedExerciseRecords[0].orderedSets[0].repetitions == 10)
    }

    @Test("New sessions prefill the latest completed set and retain target fallbacks")
    func workoutSessionPreviousValuePrefill() {
        let exerciseID = UUID()
        let planned = PlannedExercise(
            exerciseID: exerciseID,
            exerciseNameSnapshot: "Bench Press",
            targetSets: 2,
            targetRepetitions: 8,
            targetWeight: 60
        )
        let plan = WorkoutPlan(name: "Chest", exercises: [planned])
        let previousRecord = ExerciseRecord(
            exerciseID: exerciseID,
            exerciseNameSnapshot: "Bench Press",
            sets: [
                WorkoutSetRecord(
                    setNumber: 1,
                    weight: 72.5,
                    repetitions: 6,
                    isCompleted: true
                ),
                WorkoutSetRecord(setNumber: 2, weight: 70, repetitions: 7)
            ]
        )
        let previous = WorkoutSession(
            planNameSnapshot: "Chest",
            startedAt: Date(timeIntervalSince1970: 500),
            status: .completed,
            exerciseRecords: [previousRecord]
        )

        let session = WorkoutService.makeSession(from: plan, previousSessions: [previous])
        let sets = session.orderedExerciseRecords[0].orderedSets
        #expect(sets[0].weight == 72.5)
        #expect(sets[0].repetitions == 6)
        #expect(sets[1].weight == 60)
        #expect(sets[1].repetitions == 8)
    }

    @Test("Historical snapshots survive plan changes")
    func historySnapshotsRemainValid() {
        let planned = PlannedExercise(exerciseNameSnapshot: "Bench Press", targetWeight: 60)
        let plan = WorkoutPlan(name: "Chest", exercises: [planned])
        let session = WorkoutService.makeSession(from: plan)

        plan.name = "Renamed Plan"
        planned.exerciseNameSnapshot = "Renamed Exercise"
        planned.targetWeight = 90

        #expect(session.planNameSnapshot == "Chest")
        #expect(session.orderedExerciseRecords[0].exerciseNameSnapshot == "Bench Press")
        #expect(session.orderedExerciseRecords[0].orderedSets[0].weight == 60)
    }

    @Test("Workout duration uses the static plan estimate without valid history")
    func workoutDurationStaticFallback() {
        let exercise = PlannedExercise(
            exerciseNameSnapshot: "Bench Press",
            targetSets: 2,
            restSeconds: 60
        )
        let plan = WorkoutPlan(name: "Chest", exercises: [exercise])

        let estimate = WorkoutDurationEstimator.estimate(for: plan, sessions: [])

        #expect(estimate.source == .staticPlan)
        #expect(estimate.sampleCount == 0)
        #expect(estimate.roundedMinutes == plan.expectedDurationMinutes)
    }

    @Test("One and two historical workouts use the duration and arithmetic mean")
    func workoutDurationSmallHistorySamples() {
        let plan = WorkoutPlan(name: "Chest")
        let baseDate = Date(timeIntervalSince1970: 100_000)
        let sixty = makeDurationSession(
            planID: plan.id,
            minutes: 60,
            completedAt: baseDate
        )
        let seventy = makeDurationSession(
            planID: plan.id,
            minutes: 70,
            completedAt: baseDate.addingTimeInterval(86_400)
        )

        let oneSession = WorkoutDurationEstimator.estimate(for: plan, sessions: [sixty])
        #expect(oneSession.source == .history)
        #expect(oneSession.sampleCount == 1)
        #expect(oneSession.roundedMinutes == 60)

        let twoSessions = WorkoutDurationEstimator.estimate(
            for: plan,
            sessions: [sixty, seventy]
        )
        #expect(twoSessions.source == .history)
        #expect(twoSessions.sampleCount == 2)
        #expect(twoSessions.roundedMinutes == 65)
    }

    @Test("A newly completed workout immediately participates in the estimate")
    func workoutDurationRefreshAfterCompletion() {
        let plan = WorkoutPlan(name: "Chest")
        var sessions: [WorkoutSession] = []
        let initial = WorkoutDurationEstimator.estimate(for: plan, sessions: sessions)
        #expect(initial.source == .staticPlan)

        sessions.append(makeDurationSession(
            planID: plan.id,
            minutes: 74,
            completedAt: Date(timeIntervalSince1970: 150_000)
        ))
        let refreshed = WorkoutDurationEstimator.estimate(for: plan, sessions: sessions)

        #expect(refreshed.source == .history)
        #expect(refreshed.sampleCount == 1)
        #expect(refreshed.roundedMinutes == 74)
    }

    @Test("Three to five historical workouts use the median")
    func workoutDurationMedian() {
        let plan = WorkoutPlan(name: "Chest")
        let baseDate = Date(timeIntervalSince1970: 200_000)
        let threeSessions = [60, 70, 65].enumerated().map { index, minutes in
            makeDurationSession(
                planID: plan.id,
                minutes: minutes,
                completedAt: baseDate.addingTimeInterval(TimeInterval(index * 86_400))
            )
        }
        let fiveSessions = [60, 62, 65, 120, 64].enumerated().map { index, minutes in
            makeDurationSession(
                planID: plan.id,
                minutes: minutes,
                completedAt: baseDate.addingTimeInterval(TimeInterval(index * 86_400))
            )
        }

        #expect(WorkoutDurationEstimator.estimate(
            for: plan,
            sessions: threeSessions
        ).roundedMinutes == 65)
        #expect(WorkoutDurationEstimator.estimate(
            for: plan,
            sessions: fiveSessions
        ).roundedMinutes == 64)
    }

    @Test("Workout duration only uses the five most recent valid sessions")
    func workoutDurationRecentFive() {
        let plan = WorkoutPlan(name: "Chest")
        let baseDate = Date(timeIntervalSince1970: 300_000)
        let durations = [300, 10, 20, 30, 40, 50]
        let sessions = durations.enumerated().map { index, minutes in
            makeDurationSession(
                planID: plan.id,
                minutes: minutes,
                completedAt: baseDate.addingTimeInterval(TimeInterval(index * 86_400))
            )
        }

        let estimate = WorkoutDurationEstimator.estimate(for: plan, sessions: sessions)

        #expect(estimate.source == .history)
        #expect(estimate.sampleCount == 5)
        #expect(estimate.roundedMinutes == 30)
    }

    @Test("Workout duration ignores invalid, unfinished, cancelled, and other-plan sessions")
    func workoutDurationFiltersInvalidSessions() {
        let plan = WorkoutPlan(name: "Chest")
        let otherPlan = WorkoutPlan(name: "Other")
        let completedAt = Date(timeIntervalSince1970: 400_000)
        let valid = makeDurationSession(
            planID: plan.id,
            minutes: 60,
            completedAt: completedAt
        )
        let cancelled = makeDurationSession(
            planID: plan.id,
            minutes: 120,
            completedAt: completedAt.addingTimeInterval(100),
            status: .cancelled
        )
        let active = WorkoutSession(
            workoutPlanID: plan.id,
            planNameSnapshot: plan.name,
            startedAt: completedAt,
            status: .active
        )
        let zeroDuration = WorkoutSession(
            workoutPlanID: plan.id,
            planNameSnapshot: plan.name,
            startedAt: completedAt,
            completedAt: completedAt,
            status: .completed
        )
        let negativeDuration = WorkoutSession(
            workoutPlanID: plan.id,
            planNameSnapshot: plan.name,
            startedAt: completedAt,
            completedAt: completedAt.addingTimeInterval(-60),
            status: .completed
        )
        let corrupted = makeDurationSession(
            planID: plan.id,
            minutes: 9 * 60,
            completedAt: completedAt.addingTimeInterval(200)
        )
        let other = makeDurationSession(
            planID: otherPlan.id,
            minutes: 90,
            completedAt: completedAt.addingTimeInterval(300)
        )
        let missingPlanID = makeDurationSession(
            planID: nil,
            minutes: 75,
            completedAt: completedAt.addingTimeInterval(400)
        )

        let estimate = WorkoutDurationEstimator.estimate(
            for: plan,
            sessions: [
                valid,
                cancelled,
                active,
                zeroDuration,
                negativeDuration,
                corrupted,
                other,
                missingPlanID
            ]
        )

        #expect(estimate.source == .history)
        #expect(estimate.sampleCount == 1)
        #expect(estimate.roundedMinutes == 60)
    }

    @Test("Rest timer remaining time uses a deadline and rounds up")
    func restTimerRemainingTime() {
        let now = Date(timeIntervalSince1970: 1_000)
        #expect(RestTimerService.remaining(until: now.addingTimeInterval(30), now: now) == 30)
        #expect(RestTimerService.remaining(until: now.addingTimeInterval(0.2), now: now) == 1)
        #expect(RestTimerService.remaining(until: now.addingTimeInterval(-5), now: now) == 0)
    }

    @Test("Rest timer restores paused state and uses elapsed wall time")
    func restTimerPersistenceAndRecovery() {
        let suiteName = "GymFlowTests.RestTimer.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated UserDefaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let start = Date(timeIntervalSince1970: 1_000)
        let running = RestTimerService(defaults: defaults, keyPrefix: "testTimer")
        running.start(duration: 120, now: start)
        running.refresh(now: start.addingTimeInterval(40))
        #expect(running.remainingSeconds == 80)

        running.pause(now: start.addingTimeInterval(40))
        let restored = RestTimerService(defaults: defaults, keyPrefix: "testTimer")
        #expect(restored.isPaused)
        #expect(restored.remainingSeconds == 80)

        restored.resume(now: start.addingTimeInterval(100))
        restored.refresh(now: start.addingTimeInterval(130))
        #expect(restored.remainingSeconds == 50)
    }

    @Test("Rest timer migrates an interrupted workout from the legacy storage key")
    func restTimerStorageMigration() {
        let suiteName = "GymFlowTests.RestTimerMigration.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated UserDefaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let start = Date(timeIntervalSince1970: 1_000)
        let legacy = RestTimerService(defaults: defaults, keyPrefix: "restTimer")
        legacy.start(duration: 90, now: start)
        legacy.pause(now: start.addingTimeInterval(20))

        let restored = RestTimerService(
            defaults: defaults,
            keyPrefix: "restTimer.session-id",
            migrationKeyPrefix: "restTimer"
        )
        #expect(restored.isPaused)
        #expect(restored.remainingSeconds == 70)
        #expect(defaults.object(forKey: "restTimer.pausedRemaining") == nil)
        #expect(defaults.integer(forKey: "restTimer.session-id.pausedRemaining") == 70)
    }

    @Test("Complete Current Set persists one set and advances to the next set")
    func completeCurrentSetAction() {
        let now = Date(timeIntervalSince1970: 2_000)
        let session = makeActionSession(restSeconds: 75, setCounts: [2])
        let sets = session.orderedExerciseRecords[0].orderedSets

        let result = WorkoutActionService.completeCurrentSet(
            in: session,
            expectedSetID: sets[0].id,
            now: now
        )

        #expect(result.disposition == .completed)
        #expect(result.restDuration == 75)
        #expect(sets[0].isCompleted)
        #expect(sets[0].completedAt == now)
        #expect(!sets[1].isCompleted)
        #expect(session.currentExerciseIndex == 0)
        #expect(session.currentSetNumber == 2)
        #expect(result.currentSetID == sets[1].id)
    }

    @Test("Completing the same set twice never completes the following set")
    func completeCurrentSetOnlyOnce() {
        let session = makeActionSession(restSeconds: 90, setCounts: [2])
        let sets = session.orderedExerciseRecords[0].orderedSets

        let first = WorkoutActionService.completeCurrentSet(
            in: session,
            expectedSetID: sets[0].id
        )
        let duplicate = WorkoutActionService.completeCurrentSet(
            in: session,
            expectedSetID: sets[0].id
        )

        #expect(first.didCompleteSet)
        #expect(duplicate.disposition == .alreadyCompleted)
        #expect(session.completedSetCount == 1)
        #expect(!sets[1].isCompleted)
    }

    @Test("Final set of an exercise advances to the next exercise")
    func finalSetOfExerciseAdvances() {
        let session = makeActionSession(restSeconds: 60, setCounts: [1, 2])
        let firstSet = session.orderedExerciseRecords[0].orderedSets[0]
        let nextSet = session.orderedExerciseRecords[1].orderedSets[0]

        let result = WorkoutActionService.completeCurrentSet(
            in: session,
            expectedSetID: firstSet.id
        )

        #expect(result.exerciseCompleted)
        #expect(!result.workoutReadyToFinish)
        #expect(session.currentExerciseIndex == 1)
        #expect(session.currentSetNumber == 1)
        #expect(result.currentSetID == nextSet.id)
    }

    @Test("Final set of the final exercise leaves the workout ready to finish")
    func finalSetOfFinalExercise() {
        let session = makeActionSession(restSeconds: 30, setCounts: [1])
        let finalSet = session.orderedExerciseRecords[0].orderedSets[0]

        let result = WorkoutActionService.completeCurrentSet(
            in: session,
            expectedSetID: finalSet.id
        )

        #expect(result.didCompleteSet)
        #expect(result.workoutReadyToFinish)
        #expect(result.currentSetID == nil)
        #expect(session.status == .active)
        #expect(session.completedAt == nil)
    }

    @Test("A stale Live Activity set identifier cannot complete a different set")
    func staleLiveActivitySetID() {
        let session = makeActionSession(restSeconds: 90, setCounts: [2])
        let sets = session.orderedExerciseRecords[0].orderedSets

        let result = WorkoutActionService.completeCurrentSet(
            in: session,
            expectedSetID: sets[1].id
        )

        #expect(result.disposition == .staleSet)
        #expect(session.completedSetCount == 0)
        #expect(session.currentSetNumber == 1)
    }

    @Test("Duplicate completion after state advancement is idempotent")
    func duplicateCompletionRequest() {
        let session = makeActionSession(restSeconds: 90, setCounts: [3])
        let originalSetID = session.orderedExerciseRecords[0].orderedSets[0].id

        _ = WorkoutActionService.completeCurrentSet(
            in: session,
            expectedSetID: originalSetID
        )
        let delayedRequest = WorkoutActionService.completeCurrentSet(
            in: session,
            expectedSetID: originalSetID
        )

        #expect(delayedRequest.disposition == .alreadyCompleted)
        #expect(session.completedSetCount == 1)
        #expect(session.currentSetNumber == 2)
    }

    @Test("Adding 30 seconds reschedules the stable rest notification")
    func restTimerAddThirtyReschedulesNotification() {
        let suiteName = "GymFlowTests.RestTimerAdd.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated UserDefaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let scheduler = RecordingRestTimerScheduler()
        let sessionID = UUID()
        let start = Date(timeIntervalSince1970: 4_000)
        let timer = RestTimerService(
            defaults: defaults,
            keyPrefix: "restTimer.\(sessionID.uuidString)",
            sessionID: sessionID,
            notificationScheduler: scheduler
        )
        timer.start(duration: 60, now: start)
        timer.addThirtySeconds(now: start.addingTimeInterval(10))

        #expect(timer.deadline == start.addingTimeInterval(90))
        #expect(timer.remainingSeconds == 80)
        #expect(scheduler.scheduled.count == 2)
        #expect(scheduler.scheduled.last?.endDate == start.addingTimeInterval(90))
        #expect(scheduler.scheduled.last?.identifier
            == RestTimerNotificationScheduler.identifier(for: sessionID))
    }

    @Test("Skipping rest cancels its notification and records completion")
    func restTimerSkipCancelsNotification() {
        let suiteName = "GymFlowTests.RestTimerSkip.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated UserDefaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let scheduler = RecordingRestTimerScheduler()
        let sessionID = UUID()
        let timer = RestTimerService(
            defaults: defaults,
            keyPrefix: "restTimer.\(sessionID.uuidString)",
            sessionID: sessionID,
            notificationScheduler: scheduler
        )
        timer.start(duration: 90, now: Date(timeIntervalSince1970: 5_000))
        timer.skip()

        #expect(timer.didComplete)
        #expect(!timer.isRunning)
        #expect(timer.deadline == nil)
        #expect(scheduler.cancelled.last
            == RestTimerNotificationScheduler.identifier(for: sessionID))
    }

    @Test("Pausing and cancelling rest remove pending notifications")
    func restTimerNotificationCancellation() {
        let suiteName = "GymFlowTests.RestTimerCancel.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated UserDefaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let scheduler = RecordingRestTimerScheduler()
        let sessionID = UUID()
        let start = Date(timeIntervalSince1970: 6_000)
        let timer = RestTimerService(
            defaults: defaults,
            keyPrefix: "restTimer.\(sessionID.uuidString)",
            sessionID: sessionID,
            notificationScheduler: scheduler
        )
        timer.start(duration: 120, now: start)
        timer.pause(now: start.addingTimeInterval(20))
        timer.resume(now: start.addingTimeInterval(40))
        timer.cancel()

        #expect(scheduler.scheduled.count == 2)
        #expect(scheduler.cancelled.count == 2)
        #expect(!timer.isRunning)
        #expect(!timer.isPaused)
    }

    @Test("Rest alert settings independently control sound and haptic")
    func restTimerAlertConfigurationState() {
        let soundOnly = RestTimerAlertConfiguration(soundEnabled: true, hapticEnabled: false)
        let hapticOnly = RestTimerAlertConfiguration(soundEnabled: false, hapticEnabled: true)
        let alertData = RestTimerAlertService.twoToneAlertData()

        #expect(soundOnly.soundEnabled)
        #expect(!soundOnly.hapticEnabled)
        #expect(!hapticOnly.soundEnabled)
        #expect(hapticOnly.hapticEnabled)
        #expect(String(data: alertData.prefix(4), encoding: .ascii) == "RIFF")
        #expect(alertData.count > 44_000)
        #expect(alertData.count < 100_000)
    }

    @Test("Audio destinations do not overwrite existing imports")
    func audioFileDestinationNaming() {
        let existing: Set<String> = ["Workout Mix.mp3", "Workout Mix-2.mp3"]
        let name = AudioFileStore.availableDestinationFileName(
            originalFileName: "Workout Mix.MP3",
            existingNames: existing
        )
        #expect(name == "Workout Mix-3.mp3")
        #expect(AudioFileStore.availableDestinationFileName(
            originalFileName: "New Song.m4a",
            existingNames: existing
        ) == "New Song.m4a")
    }

    @Test("Playlist CRUD preserves shared imported tracks and ordering")
    func playlistManagement() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ImportedTrack.self, Playlist.self, PlaylistTrack.self,
            WorkoutPlan.self, PlannedExercise.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let first = ImportedTrack(
            title: "First",
            storedFileName: "first.mp3",
            originalFileName: "first.mp3",
            fileExtension: "mp3"
        )
        let second = ImportedTrack(
            title: "Second",
            storedFileName: "second.mp3",
            originalFileName: "second.mp3",
            fileExtension: "mp3"
        )
        context.insert(first)
        context.insert(second)

        let playlist = try PlaylistService.create(name: "Training", playlists: [], context: context)
        let assignedPlan = WorkoutPlan(name: "Assigned", assignedPlaylistID: playlist.id)
        context.insert(assignedPlan)
        try PlaylistService.add(
            trackIDs: [second.id, first.id],
            to: playlist,
            memberships: [],
            context: context
        )
        let memberships = try context.fetch(FetchDescriptor<PlaylistTrack>())
        #expect(PlaylistService.orderedTracks(
            for: playlist.id,
            memberships: memberships,
            tracks: [first, second]
        ).map(\.title) == ["Second", "First"])

        let copy = try PlaylistService.duplicate(
            playlist,
            playlists: [playlist],
            memberships: memberships,
            context: context
        )
        let membershipsAfterCopy = try context.fetch(FetchDescriptor<PlaylistTrack>())
        #expect(copy.name == "Training Copy")
        #expect(membershipsAfterCopy.filter { $0.playlistID == copy.id }.count == 2)

        try PlaylistService.delete(
            playlist,
            memberships: membershipsAfterCopy,
            assignedPlans: [assignedPlan],
            context: context
        )
        #expect(try context.fetchCount(FetchDescriptor<ImportedTrack>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<Playlist>()) == 1)
        #expect(assignedPlan.assignedPlaylistID == nil)
    }

    @Test("Playlist names are validated")
    func playlistValidation() throws {
        #expect(throws: PlaylistError.emptyName) {
            try PlaylistService.validatedName("  ", playlists: [])
        }
        let existing = Playlist(name: "Cardio")
        #expect(throws: PlaylistError.duplicateName) {
            try PlaylistService.validatedName("cardio", playlists: [existing])
        }
    }

    @Test("FLAC is accepted as a supported local audio format")
    func flacImportSupport() {
        #expect(AudioFileStore.supportedExtensions.contains("flac"))
        #expect(AudioFileStore.availableDestinationFileName(
            originalFileName: "Workout Mix.FLAC",
            existingNames: []
        ) == "Workout Mix.flac")
    }

    @Test("A FLAC file can be copied and decoded")
    func flacFileImportAndDecode() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GymFlow-FLAC-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("Test Track.FLAC")
        try writeSilentFLAC(to: source)

        let destination = root.appendingPathComponent("Imported", isDirectory: true)
        let store = try AudioFileStore(directoryURL: destination)
        let imported = try store.importAudio(from: source)

        #expect(imported.fileExtension == "flac")
        #expect(imported.storedFileName == "Test Track.flac")
        #expect(imported.duration != nil)
        #expect(FileManager.default.fileExists(atPath: store.fileURL(for: imported.storedFileName).path))
    }

    @Test("Audio service creates complete Now Playing metadata")
    func nowPlayingMetadata() {
        let track = ImportedTrack(
            title: "Control Center",
            artist: "GymFlow Tests",
            album: "Integration",
            storedFileName: "control-center.flac",
            originalFileName: "Control Center.flac",
            fileExtension: "flac",
            duration: 180
        )
        let info = AudioPlayerService.makeNowPlayingInfo(
            track: track,
            queueName: "Test Queue",
            duration: 180,
            progress: 42,
            isPlaying: true
        )
        #expect(info[MPMediaItemPropertyTitle] as? String == "Control Center")
        #expect(info[MPMediaItemPropertyArtist] as? String == "GymFlow Tests")
        #expect(info[MPMediaItemPropertyAlbumTitle] as? String == "Integration")
        #expect(info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval == 42)
        #expect(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 1)
        #expect(info[MPMediaItemPropertyArtwork] is MPMediaItemArtwork)
    }

    @Test("Audio service configures playback without a launch error")
    func audioSessionLaunchConfiguration() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GymFlow-AudioSession-\(UUID().uuidString)", isDirectory: true)
        let suiteName = "GymFlowTests.AudioSession.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated UserDefaults")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: root)
        }

        let store = try AudioFileStore(directoryURL: root)
        let audioPlayer = AudioPlayerService(defaults: defaults, fileStore: store)

        #expect(audioPlayer.lastError == nil)
        #expect(AVAudioSession.sharedInstance().category == .playback)
    }

    @Test("Live Activity state is compact and round-trips")
    func liveActivityPayload() throws {
        let expiration = Date(timeIntervalSince1970: 29_800)
        let state = WorkoutActivityAttributes.ContentState(
            exerciseName: "Barbell Bench Press",
            currentSetID: UUID(),
            currentSet: 3,
            totalSets: 4,
            targetWeight: 70,
            targetRepetitions: 8,
            lastCompletedExerciseName: "Barbell Bench Press",
            lastCompletedSetNumber: 2,
            completedExercises: 1,
            totalExercises: 5,
            workoutStartDate: Date(timeIntervalSince1970: 1_000),
            restEndDate: Date(timeIntervalSince1970: 1_180),
            pausedRestSeconds: 0,
            restComplete: false,
            workoutReadyToFinish: false,
            workoutExpiresAt: expiration
        )
        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(
            WorkoutActivityAttributes.ContentState.self,
            from: data
        )
        #expect(restored == state)
        #expect(data.count < 4_096)
    }

    @Test("Live Activity actions use the least restrictive intent policy")
    func liveActivityActionsUseAlwaysAllowedIntentPolicy() {
        #expect(CompleteCurrentSetIntent.authenticationPolicy == .alwaysAllowed)
        #expect(AddThirtySecondsRestIntent.authenticationPolicy == .alwaysAllowed)
        #expect(SkipRestIntent.authenticationPolicy == .alwaysAllowed)
        #expect(!CompleteCurrentSetIntent.openAppWhenRun)
        #expect(!AddThirtySecondsRestIntent.openAppWhenRun)
        #expect(!SkipRestIntent.openAppWhenRun)
    }

    @Test("Mini-player is visible only when its shared track is loaded")
    func miniPlayerVisibility() {
        #expect(!MiniPlayerPresentationPolicy.showsGlobalPlayer(
            hasLoadedTrack: false,
            isWorkoutPresented: false
        ))
        #expect(MiniPlayerPresentationPolicy.showsGlobalPlayer(
            hasLoadedTrack: true,
            isWorkoutPresented: false
        ))
        #expect(!MiniPlayerPresentationPolicy.showsGlobalPlayer(
            hasLoadedTrack: true,
            isWorkoutPresented: true
        ))
        #expect(MiniPlayerPresentationPolicy.showsWorkoutPlayer(
            hasLoadedTrack: true,
            isWorkoutPresented: true
        ))
        #expect(!MiniPlayerPresentationPolicy.showsWorkoutPlayer(
            hasLoadedTrack: false,
            isWorkoutPresented: true
        ))
        #expect(!MiniPlayerPresentationPolicy.showsGlobalPlayer(
            hasLoadedTrack: true,
            isWorkoutPresented: false,
            isNowPlayingPresented: true
        ))
        #expect(!MiniPlayerPresentationPolicy.showsWorkoutPlayer(
            hasLoadedTrack: true,
            isWorkoutPresented: true,
            isNowPlayingPresented: true
        ))
    }

    @Test("Now Playing stays presented until the presentation host dismisses it")
    func nowPlayingPresentationState() {
        var presentation = NowPlayingPresentationState()
        #expect(!presentation.isPresented)

        presentation.present()
        #expect(presentation.isPresented)

        // Audio state changes have no path to this independent presentation state.
        #expect(presentation.isPresented)

        presentation.updateSystemPresentation(false)
        #expect(!presentation.isPresented)
    }

    @Test("The shared audio service retains its queue across tab selection")
    func sharedAudioAcrossTabSelection() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GymFlow-MiniPlayer-\(UUID().uuidString)", isDirectory: true)
        let suiteName = "GymFlowTests.MiniPlayer.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated UserDefaults")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("Shared Track.flac")
        try writeSilentFLAC(to: source)
        let store = try AudioFileStore(directoryURL: root.appendingPathComponent("Imported"))
        let imported = try store.importAudio(from: source)
        let track = ImportedTrack(
            title: imported.title,
            artist: imported.artist,
            storedFileName: imported.storedFileName,
            originalFileName: imported.originalFileName,
            fileExtension: imported.fileExtension,
            duration: imported.duration
        )
        let audioPlayer = AudioPlayerService(defaults: defaults, fileStore: store)
        audioPlayer.setQueue([track], autoplay: false)

        var selectedTab = AppTab.today
        for tab in [AppTab.today, .plans, .history, .music, .settings] {
            selectedTab = tab
            #expect(audioPlayer.playlist.map(\.id) == [track.id])
        }
        #expect(selectedTab == .settings)
    }

    @Test("No active workout terminates every existing activity")
    func noWorkoutEndsActivities() {
        let firstSessionID = UUID()
        let secondSessionID = UUID()
        let plan = WorkoutActivityReconciler.plan(
            session: nil,
            activities: [
                ExistingWorkoutActivity(activityID: "first", sessionID: firstSessionID),
                ExistingWorkoutActivity(activityID: "second", sessionID: secondSessionID)
            ],
            persistedActivityID: "first",
            now: Date(timeIntervalSince1970: 10_000)
        )

        #expect(plan.activityIDsToEnd == ["first", "second"])
        #expect(plan.invalidReason == .noActiveWorkout)
        #expect(!plan.shouldStartActivity)
    }

    @Test("A matching activity is preserved and duplicate activities are removed")
    func matchingActivityAndDuplicateCleanup() {
        let now = Date(timeIntervalSince1970: 10_000)
        let session = makeActivitySession(startedAt: now.addingTimeInterval(-600))
        let unrelatedSessionID = UUID()
        let plan = WorkoutActivityReconciler.plan(
            session: session,
            activities: [
                ExistingWorkoutActivity(activityID: "duplicate", sessionID: session.sessionID),
                ExistingWorkoutActivity(activityID: "matching", sessionID: session.sessionID),
                ExistingWorkoutActivity(activityID: "orphan", sessionID: unrelatedSessionID)
            ],
            persistedActivityID: "matching",
            now: now
        )

        #expect(plan.activityIDToKeep == "matching")
        #expect(plan.activityIDsToEnd == ["duplicate", "orphan"])
        #expect(plan.shouldUpdateActivity)
        #expect(!plan.shouldStartActivity)
    }

    @Test("Completed and cancelled workouts terminate their activities")
    func inactiveWorkoutsEndActivities() {
        let now = Date(timeIntervalSince1970: 10_000)
        for disposition in [
            WorkoutActivitySessionDisposition.completed,
            WorkoutActivitySessionDisposition.cancelled
        ] {
            let session = makeActivitySession(
                disposition: disposition,
                startedAt: now.addingTimeInterval(-600)
            )
            let plan = WorkoutActivityReconciler.plan(
                session: session,
                activities: [ExistingWorkoutActivity(
                    activityID: "activity",
                    sessionID: session.sessionID
                )],
                persistedActivityID: "activity",
                now: now
            )
            #expect(plan.invalidReason == .inactiveWorkout)
            #expect(plan.activityIDsToEnd == ["activity"])
        }
    }

    @Test("A workout older than the maximum lifetime is invalid")
    func expiredWorkoutEndsActivity() {
        let now = Date(timeIntervalSince1970: 50_000)
        let session = makeActivitySession(
            startedAt: now.addingTimeInterval(-WorkoutActivityPolicy.maximumDuration)
        )
        let plan = WorkoutActivityReconciler.plan(
            session: session,
            activities: [ExistingWorkoutActivity(
                activityID: "expired",
                sessionID: session.sessionID
            )],
            persistedActivityID: "expired",
            now: now
        )

        #expect(plan.invalidReason == .expiredWorkout)
        #expect(plan.activityIDsToEnd == ["expired"])
    }

    @Test("Live Activity status distinguishes rest, training, and stale content")
    func liveActivityDisplayState() {
        let now = Date(timeIntervalSince1970: 10_000)
        var state = makeActivityContentState(
            now: now,
            restEndDate: now.addingTimeInterval(90)
        )
        #expect(WorkoutActivityPolicy.displayState(
            for: state,
            isStale: false,
            now: now
        ) == .resting(endDate: now.addingTimeInterval(90)))
        #expect(WorkoutActivityPolicy.nextStaleDate(for: state) == now.addingTimeInterval(90))

        state.restEndDate = nil
        #expect(WorkoutActivityPolicy.displayState(
            for: state,
            isStale: false,
            now: now
        ) == .training(currentSet: 3, totalSets: 4))

        state.workoutExpiresAt = now.addingTimeInterval(-1)
        #expect(WorkoutActivityPolicy.displayState(
            for: state,
            isStale: true,
            now: now
        ) == .stale)
    }

    private func makeActionSession(
        restSeconds: Int,
        setCounts: [Int]
    ) -> WorkoutSession {
        let exercises = setCounts.enumerated().map { exerciseIndex, setCount in
            ExerciseRecord(
                exerciseNameSnapshot: "Exercise \(exerciseIndex + 1)",
                sortOrder: exerciseIndex,
                restSeconds: restSeconds,
                sets: (1...max(1, setCount)).map { setNumber in
                    WorkoutSetRecord(
                        setNumber: setNumber,
                        weight: Double(40 + exerciseIndex * 10),
                        repetitions: 8
                    )
                }
            )
        }
        return WorkoutSession(
            planNameSnapshot: "Action Test",
            currentExerciseIndex: 0,
            currentSetNumber: 1,
            status: .active,
            exerciseRecords: exercises
        )
    }

    private final class RecordingRestTimerScheduler: RestTimerNotificationScheduling {
        private(set) var scheduled: [RestTimerNotificationPlan] = []
        private(set) var cancelled: [String] = []

        func schedule(_ plan: RestTimerNotificationPlan) {
            scheduled.append(plan)
        }

        func cancel(identifier: String) {
            cancelled.append(identifier)
        }
    }

    private func makeActivitySession(
        disposition: WorkoutActivitySessionDisposition = .active,
        startedAt: Date
    ) -> WorkoutActivitySessionState {
        let content = makeActivityContentState(now: startedAt, restEndDate: nil)
        let snapshot = WorkoutActivitySnapshot(
            exerciseName: content.exerciseName,
            currentSetID: content.currentSetID,
            currentSet: content.currentSet,
            totalSets: content.totalSets,
            targetWeight: content.targetWeight,
            targetRepetitions: content.targetRepetitions,
            lastCompletedExerciseName: content.lastCompletedExerciseName,
            lastCompletedSetNumber: content.lastCompletedSetNumber,
            completedExercises: content.completedExercises,
            totalExercises: content.totalExercises,
            workoutStartDate: startedAt,
            restEndDate: nil,
            pausedRestSeconds: 0,
            restComplete: false,
            workoutReadyToFinish: false
        )
        return WorkoutActivitySessionState(
            sessionID: UUID(),
            workoutName: "Chest Day",
            disposition: disposition,
            startedAt: startedAt,
            hasValidWorkoutData: true,
            snapshot: snapshot
        )
    }

    private func makeDurationSession(
        planID: UUID?,
        minutes: Int,
        completedAt: Date,
        status: WorkoutSessionStatus = .completed
    ) -> WorkoutSession {
        WorkoutSession(
            workoutPlanID: planID,
            planNameSnapshot: "Duration Test",
            startedAt: completedAt.addingTimeInterval(-TimeInterval(minutes * 60)),
            completedAt: completedAt,
            status: status
        )
    }

    private func makeActivityContentState(
        now: Date,
        restEndDate: Date?
    ) -> WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            exerciseName: "Barbell Bench Press",
            currentSetID: UUID(),
            currentSet: 3,
            totalSets: 4,
            targetWeight: 70,
            targetRepetitions: 8,
            lastCompletedExerciseName: "Barbell Bench Press",
            lastCompletedSetNumber: 2,
            completedExercises: 1,
            totalExercises: 5,
            workoutStartDate: now.addingTimeInterval(-600),
            restEndDate: restEndDate,
            pausedRestSeconds: 0,
            restComplete: false,
            workoutReadyToFinish: false,
            workoutExpiresAt: now.addingTimeInterval(WorkoutActivityPolicy.maximumDuration)
        )
    }

    private func writeSilentFLAC(to url: URL) throws {
        let sampleRate = 44_100.0
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatFLAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_410) else {
            throw CocoaError(.fileWriteUnknown)
        }
        buffer.frameLength = 4_410
        try file.write(from: buffer)
    }

    @Test("Playlist navigation handles boundaries and repeat")
    func playlistNextAndPrevious() {
        #expect(PlaylistEngine.nextIndex(
            current: 0, count: 3, repeatMode: .off, automatic: true
        ) == 1)
        #expect(PlaylistEngine.nextIndex(
            current: 2, count: 3, repeatMode: .off, automatic: true
        ) == nil)
        #expect(PlaylistEngine.nextIndex(
            current: 2, count: 3, repeatMode: .all, automatic: true
        ) == 0)
        #expect(PlaylistEngine.previousIndex(current: 0, count: 3) == 2)
        #expect(PlaylistEngine.previousIndex(current: 2, count: 3) == 1)
    }

    @Test("Playlist repeat-one and deterministic shuffle are testable")
    func shuffleAndRepeatLogic() {
        #expect(PlaylistEngine.nextIndex(
            current: 1, count: 4, repeatMode: .one, automatic: true
        ) == 1)
        let ids = (0..<4).map { _ in UUID() }
        let shuffled = PlaylistEngine.makeQueue(
            sourceTrackIDs: ids,
            shuffle: true,
            currentTrackID: ids[1],
            shuffler: { $0.reversed() }
        )
        #expect(shuffled == [ids[1], ids[3], ids[2], ids[0]])
        #expect(Set(shuffled).count == ids.count)
        #expect(RepeatMode.off.next == .one)
        #expect(RepeatMode.one.next == .all)
        #expect(RepeatMode.all.next == .off)
    }

    @Test("Playback snapshot preserves queue context")
    func playbackSnapshotPersistence() throws {
        let ids = [UUID(), UUID(), UUID()]
        let snapshot = PlaybackSnapshot(
            sourceTrackIDs: ids,
            queueTrackIDs: [ids[1], ids[2], ids[0]],
            currentTrackID: ids[2],
            currentTime: 42.5,
            queueName: "Workout",
            playlistID: UUID(),
            shuffleEnabled: true,
            repeatMode: .all
        )
        let encoded = try JSONEncoder().encode(snapshot)
        let restored = try JSONDecoder().decode(PlaybackSnapshot.self, from: encoded)
        #expect(restored == snapshot)
    }

    @Test("Validation rejects invalid plan and target values")
    func validationRules() {
        #expect(throws: ValidationError.emptyPlanName) {
            try InputValidator.validatePlanName("  \n")
        }
        #expect(throws: ValidationError.emptyExerciseName) {
            try InputValidator.validateExerciseName("")
        }
        #expect(throws: ValidationError.invalidSetCount) {
            try InputValidator.validate(sets: 0, repetitions: 10, weight: 10, restSeconds: 60)
        }
        #expect(throws: ValidationError.negativeRepetitions) {
            try InputValidator.validate(sets: 1, repetitions: -1, weight: 10, restSeconds: 60)
        }
        #expect(throws: ValidationError.negativeWeight) {
            try InputValidator.validate(sets: 1, repetitions: 1, weight: -0.1, restSeconds: 60)
        }
        #expect(throws: ValidationError.negativeRestTime) {
            try InputValidator.validate(sets: 1, repetitions: 1, weight: 0, restSeconds: -1)
        }
    }
}
