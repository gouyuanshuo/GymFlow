import Foundation
import Testing
@testable import GymFlow

@MainActor
struct ExercisePerformanceServiceTests {
    private let exerciseID = UUID()

    @Test("Heaviest completed working-set weight is selected")
    func heaviestWeightCalculation() throws {
        let session = makeSession(sets: [set(60, 10), set(80, 2), set(75, 5)])

        let summary = ExercisePerformanceService.summary(
            exerciseID: exerciseID,
            exerciseName: "Bench Press",
            sessions: [session]
        )

        let record = try #require(summary.heaviestWeightRecord)
        #expect(record.weight == 80)
        #expect(record.repetitions == 2)
    }

    @Test("Estimated one-rep max uses Epley for one through fifteen reps")
    func estimatedOneRepMaxCalculation() throws {
        let estimate = try #require(
            ExercisePerformanceService.estimatedOneRepMax(weight: 80, repetitions: 5)
        )

        #expect(abs(estimate - 93.333_333) < 0.001)
        #expect(ExercisePerformanceService.estimatedOneRepMax(weight: 80, repetitions: 16) == nil)
        #expect(ExercisePerformanceService.estimatedOneRepMax(weight: 0, repetitions: 10) == nil)
    }

    @Test("Highest single-set volume is selected")
    func bestSetVolumeCalculation() throws {
        let session = makeSession(sets: [set(80, 5), set(70, 12), set(100, 3)])

        let summary = ExercisePerformanceService.summary(
            exerciseID: exerciseID,
            exerciseName: "Bench Press",
            sessions: [session]
        )

        let record = try #require(summary.bestSetVolumeRecord)
        #expect(record.weight == 70)
        #expect(record.repetitions == 12)
        #expect(record.setVolume == 840)
    }

    @Test("Warm-up sets are excluded from every Personal Best metric")
    func warmupSetsExcluded() throws {
        let session = makeSession(sets: [
            set(200, 20, isWarmup: true),
            set(70, 8)
        ])

        let summary = ExercisePerformanceService.summary(
            exerciseID: exerciseID,
            exerciseName: "Bench Press",
            sessions: [session]
        )

        let heaviest = try #require(summary.heaviestWeightRecord)
        let volume = try #require(summary.bestSetVolumeRecord)
        #expect(heaviest.weight == 70)
        #expect(volume.setVolume == 560)
    }

    @Test("Incomplete sets are excluded")
    func incompleteSetsExcluded() throws {
        let session = makeSession(sets: [
            set(120, 10, isCompleted: false),
            set(65, 10)
        ])

        let summary = ExercisePerformanceService.summary(
            exerciseID: exerciseID,
            exerciseName: "Bench Press",
            sessions: [session]
        )

        let heaviest = try #require(summary.heaviestWeightRecord)
        #expect(heaviest.weight == 65)
    }

    @Test("Cancelled sessions are excluded")
    func cancelledSessionsExcluded() throws {
        let cancelled = makeSession(status: .cancelled, sets: [set(150, 10)])
        let completed = makeSession(day: 2, sets: [set(60, 10)])

        let summary = ExercisePerformanceService.summary(
            exerciseID: exerciseID,
            exerciseName: "Bench Press",
            sessions: [cancelled, completed]
        )

        let heaviest = try #require(summary.heaviestWeightRecord)
        #expect(heaviest.weight == 60)
    }

    @Test("A different stable exercise identifier is excluded even when names match")
    func differentExerciseIDsExcluded() {
        let other = makeSession(exerciseID: UUID(), sets: [set(150, 5)])

        let summary = ExercisePerformanceService.summary(
            exerciseID: exerciseID,
            exerciseName: "Bench Press",
            sessions: [other]
        )

        #expect(summary.isEmpty)
    }

    @Test("Renaming an exercise preserves history through its stable identifier")
    func renamePreservesHistoryThroughID() throws {
        let historical = makeSession(name: "Original Bench Name", sets: [set(82.5, 5)])

        let summary = ExercisePerformanceService.summary(
            exerciseID: exerciseID,
            exerciseName: "Renamed Bench Press",
            sessions: [historical]
        )

        let heaviest = try #require(summary.heaviestWeightRecord)
        #expect(heaviest.weight == 82.5)
        #expect(summary.heaviestWeightRecord?.exerciseName == "Original Bench Name")
    }

    @Test("A new heavier set creates a Weight PR")
    func newWeightPRDetection() {
        let previous = makeSession(day: 1, sets: [set(70, 8)])
        let current = makeSession(day: 2, sets: [set(80, 5)])

        let events = ExercisePerformanceService.personalBestEvents(
            in: current,
            sessions: [previous, current]
        )

        #expect(events.contains { $0.types.contains(.weight) && $0.record.weight == 80 })
    }

    @Test("A stronger Epley result creates an Estimated 1RM PR")
    func newEstimatedOneRepMaxPRDetection() {
        let previous = makeSession(day: 1, sets: [set(80, 1)])
        let current = makeSession(day: 2, sets: [set(75, 10)])

        let events = ExercisePerformanceService.personalBestEvents(
            in: current,
            sessions: [previous, current]
        )

        #expect(events.contains { $0.types.contains(.estimatedOneRepMax) })
        #expect(events.allSatisfy { !$0.types.contains(.weight) })
    }

    @Test("A higher weight-times-reps result creates a Set Volume PR")
    func newSetVolumePRDetection() {
        let previous = makeSession(day: 1, sets: [set(80, 15)])
        let current = makeSession(day: 2, sets: [set(70, 20)])

        let events = ExercisePerformanceService.personalBestEvents(
            in: current,
            sessions: [previous, current]
        )

        #expect(events.contains { $0.types.contains(.setVolume) })
        #expect(events.allSatisfy { !$0.types.contains(.estimatedOneRepMax) })
    }

    @Test("More repetitions at a previously used weight creates a Rep PR")
    func newRepAtWeightPRDetection() {
        let previous = makeSession(day: 1, sets: [set(70, 8)])
        let current = makeSession(day: 2, sets: [set(70, 10)])

        let events = ExercisePerformanceService.personalBestEvents(
            in: current,
            sessions: [previous, current]
        )

        #expect(events.contains { $0.types.contains(.repetitionsAtWeight) })
        #expect(events.allSatisfy { !$0.types.contains(.weight) })
    }

    @Test("Best repetitions ignore very light sets below half of max load")
    func bestRepetitionsUseRelevantLoad() throws {
        let session = makeSession(sets: [set(20, 50), set(60, 12), set(100, 5)])

        let summary = ExercisePerformanceService.summary(
            exerciseID: exerciseID,
            exerciseName: "Bench Press",
            sessions: [session]
        )

        let bestRepetitions = try #require(summary.bestRepetitionRecord)
        #expect(bestRepetitions.weight == 60)
        #expect(bestRepetitions.repetitions == 12)
    }

    @Test("PR detection only returns records from the target workout")
    func oldRecordsDoNotBecomeNewPRs() {
        let previous = makeSession(day: 1, sets: [set(90, 5)])
        let current = makeSession(day: 2, sets: [set(80, 5)])
        let later = makeSession(day: 3, sets: [set(100, 5)])

        let events = ExercisePerformanceService.personalBestEvents(
            in: current,
            sessions: [previous, current, later]
        )

        #expect(events.isEmpty)
    }

    @Test("Legacy records use only exact normalized snapshot-name fallback")
    func legacyExerciseNameFallback() throws {
        let matching = makeSession(
            day: 1,
            usesLegacyExerciseIdentity: true,
            name: "  BENCH   PRESS ",
            sets: [set(77.5, 6)]
        )
        let unrelated = makeSession(
            day: 2,
            usesLegacyExerciseIdentity: true,
            name: "Incline Bench Press",
            sets: [set(120, 5)]
        )

        let summary = ExercisePerformanceService.summary(
            exerciseID: exerciseID,
            exerciseName: "Bench Press",
            sessions: [matching, unrelated]
        )

        let heaviest = try #require(summary.heaviestWeightRecord)
        #expect(heaviest.weight == 77.5)
    }

    @Test("A corrupt session completion timestamp is excluded")
    func corruptSessionTimestampExcluded() throws {
        let start = Date(timeIntervalSince1970: 500_000)
        let corrupt = WorkoutSession(
            planNameSnapshot: "Corrupt",
            startedAt: start,
            completedAt: start.addingTimeInterval(-60),
            status: .completed,
            exerciseRecords: [
                ExerciseRecord(
                    exerciseID: exerciseID,
                    exerciseNameSnapshot: "Bench Press",
                    sets: [set(200, 5)]
                )
            ]
        )
        let valid = makeSession(day: 10, sets: [set(60, 8)])

        let summary = ExercisePerformanceService.summary(
            exerciseID: exerciseID,
            exerciseName: "Bench Press",
            sessions: [corrupt, valid]
        )

        let heaviest = try #require(summary.heaviestWeightRecord)
        #expect(heaviest.weight == 60)
    }

    @Test("Bodyweight exercise records use repetitions without fake weight metrics")
    func bodyweightUsesRepetitionsOnly() throws {
        let session = makeSession(name: "Pull-up", sets: [set(0, 8), set(0, 12)])

        let summary = ExercisePerformanceService.summary(
            exerciseID: exerciseID,
            exerciseName: "Pull-up",
            sessions: [session]
        )

        #expect(summary.heaviestWeightRecord == nil)
        #expect(summary.estimatedOneRepMaxRecord == nil)
        #expect(summary.bestSetVolumeRecord == nil)
        let bestRepetitions = try #require(summary.bestRepetitionRecord)
        #expect(bestRepetitions.repetitions == 12)
    }

    private func makeSession(
        day: Int = 1,
        status: WorkoutSessionStatus = .completed,
        exerciseID: UUID? = nil,
        usesLegacyExerciseIdentity: Bool = false,
        name: String = "Bench Press",
        sets: [WorkoutSetRecord]
    ) -> WorkoutSession {
        let resolvedExerciseID = usesLegacyExerciseIdentity
            ? nil
            : (exerciseID ?? self.exerciseID)
        let startedAt = Date(timeIntervalSince1970: Double(day) * 86_400)
        return WorkoutSession(
            planNameSnapshot: "Test",
            startedAt: startedAt,
            completedAt: startedAt.addingTimeInterval(3_600),
            status: status,
            exerciseRecords: [
                ExerciseRecord(
                    exerciseID: resolvedExerciseID,
                    exerciseNameSnapshot: name,
                    sets: sets
                )
            ]
        )
    }

    private func set(
        _ weight: Double,
        _ repetitions: Int,
        isWarmup: Bool = false,
        isCompleted: Bool = true
    ) -> WorkoutSetRecord {
        WorkoutSetRecord(
            setNumber: 1,
            weight: weight,
            repetitions: repetitions,
            isCompleted: isCompleted,
            completedAt: isCompleted ? Date(timeIntervalSince1970: 100) : nil,
            isWarmup: isWarmup
        )
    }
}
