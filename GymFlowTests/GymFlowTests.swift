import Foundation
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
        let original = WorkoutPlan(name: "Legs", notes: "Original", exercises: [exercise])
        let copy = WorkoutService.duplicate(plan: original, now: Date(timeIntervalSince1970: 100))

        #expect(copy.id != original.id)
        #expect(copy.name == "Legs Copy")
        #expect(copy.exercises.count == 1)
        #expect(copy.exercises[0].id != exercise.id)
        #expect(copy.exercises[0].targetWeight == 80)

        copy.exercises[0].targetWeight = 100
        #expect(original.exercises[0].targetWeight == 80)
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

        let session = WorkoutService.makeSession(from: plan, now: start)

        #expect(session.workoutPlanID == plan.id)
        #expect(session.planNameSnapshot == "Back")
        #expect(session.status == .active)
        #expect(session.startedAt == start)
        #expect(session.orderedExerciseRecords.map(\.exerciseNameSnapshot) == ["Pulldown", "Row"])
        #expect(session.orderedExerciseRecords[0].sets.count == 3)
        #expect(session.orderedExerciseRecords[0].orderedSets[0].weight == 55)
        #expect(session.orderedExerciseRecords[0].orderedSets[0].repetitions == 10)
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

    @Test("Rest timer remaining time uses a deadline and rounds up")
    func restTimerRemainingTime() {
        let now = Date(timeIntervalSince1970: 1_000)
        #expect(RestTimerService.remaining(until: now.addingTimeInterval(30), now: now) == 30)
        #expect(RestTimerService.remaining(until: now.addingTimeInterval(0.2), now: now) == 1)
        #expect(RestTimerService.remaining(until: now.addingTimeInterval(-5), now: now) == 0)
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

    @Test("Playlist navigation handles boundaries and repeat")
    func playlistNextAndPrevious() {
        #expect(PlaylistEngine.nextIndex(
            current: 0, count: 3, shuffle: false, repeatMode: .off, automatic: true
        ) == 1)
        #expect(PlaylistEngine.nextIndex(
            current: 2, count: 3, shuffle: false, repeatMode: .off, automatic: true
        ) == nil)
        #expect(PlaylistEngine.nextIndex(
            current: 2, count: 3, shuffle: false, repeatMode: .all, automatic: true
        ) == 0)
        #expect(PlaylistEngine.previousIndex(current: 0, count: 3) == 2)
        #expect(PlaylistEngine.previousIndex(current: 2, count: 3) == 1)
    }

    @Test("Playlist repeat-one and deterministic shuffle are testable")
    func shuffleAndRepeatLogic() {
        #expect(PlaylistEngine.nextIndex(
            current: 1, count: 4, shuffle: false, repeatMode: .one, automatic: true
        ) == 1)
        let shuffled = PlaylistEngine.nextIndex(
            current: 1,
            count: 4,
            shuffle: true,
            repeatMode: .off,
            automatic: true,
            randomIndex: { _ in 1 }
        )
        #expect(shuffled == 2)
        #expect(shuffled != 1)
        #expect(RepeatMode.off.next == .one)
        #expect(RepeatMode.one.next == .all)
        #expect(RepeatMode.all.next == .off)
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
