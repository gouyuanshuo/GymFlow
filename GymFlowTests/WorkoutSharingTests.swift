import CoreGraphics
import Foundation
import Testing
import UIKit
import XCTest
@testable import GymFlow

@MainActor
struct WorkoutSharingTests {
    @Test("Share summary uses completed workout snapshot metrics")
    func shareSummaryGeneration() throws {
        let start = Date(timeIntervalSince1970: 10_000)
        let session = WorkoutSession(
            planNameSnapshot: "Chest + Arms",
            startedAt: start,
            completedAt: start.addingTimeInterval(4_680),
            notes: "Private note that must not be shared",
            status: .completed,
            exerciseRecords: [
                makeExercise(
                    name: "Bench Press",
                    order: 0,
                    sets: [
                        completedSet(number: 1, weight: 20, repetitions: 10, isWarmup: true),
                        completedSet(number: 2, weight: 70, repetitions: 8),
                        completedSet(number: 3, weight: 70, repetitions: 7)
                    ]
                ),
                makeExercise(
                    name: "Cable Fly",
                    order: 1,
                    sets: [completedSet(number: 1, weight: 20, repetitions: 12)]
                )
            ]
        )

        let summary = try WorkoutShareSummaryBuilder.build(from: session)

        #expect(summary.workoutName == "Chest + Arms")
        #expect(summary.date == start)
        #expect(summary.duration == 4_680)
        #expect(summary.exerciseCount == 2)
        #expect(summary.setCount == 4)
        #expect(summary.repetitionCount == 37)
        #expect(summary.trainingVolume == session.trainingVolume)
        #expect(summary.trainingVolume == 1_490)
        #expect(summary.exerciseHighlights.count == 2)
        #expect(!summary.accessibilityDescription.contains("Private note"))
    }

    @Test("Share duration formatting is concise")
    func shareDurationFormatting() {
        #expect(WorkoutShareFormatters.duration(30) == "<1m")
        #expect(WorkoutShareFormatters.duration(3_600) == "1h")
        #expect(WorkoutShareFormatters.duration(4_680) == "1h 18m")
        #expect(WorkoutShareFormatters.duration(9_000) == "2h 30m")
    }

    @Test("Share volume formatting supports exact, thousands, and millions")
    func shareVolumeFormatting() {
        #expect(WorkoutShareFormatters.compactVolume(840) == "840 kg")
        #expect(WorkoutShareFormatters.compactVolume(12_840) == "12.8K kg")
        #expect(WorkoutShareFormatters.compactVolume(1_250_000) == "1.2M kg")
        #expect(WorkoutShareFormatters.exactVolume(12_840).contains("12,840"))
    }

    @Test("Exercise highlights prioritize exercise volume then workout order")
    func exerciseHighlightSelection() throws {
        let session = completedSession(exercises: [
            makeExercise(
                name: "Bench Press",
                order: 0,
                sets: [completedSet(number: 1, weight: 70, repetitions: 8)]
            ),
            makeExercise(
                name: "Seated Cable Row",
                order: 1,
                sets: [completedSet(number: 1, weight: 50, repetitions: 12)]
            ),
            makeExercise(
                name: "Cable Curl",
                order: 2,
                sets: [completedSet(number: 1, weight: 30, repetitions: 10)]
            ),
            makeExercise(
                name: "Plank",
                order: 3,
                sets: [completedSet(number: 1, weight: 0, repetitions: 1)]
            )
        ])

        let summary = try WorkoutShareSummaryBuilder.build(from: session)

        #expect(summary.exerciseHighlights.map(\.name) == [
            "Seated Cable Row", "Bench Press", "Cable Curl"
        ])
        #expect(summary.exerciseHighlights[0].topSetDescription == "50 kg × 12")
    }

    @Test("Empty and unfinished workouts cannot create share cards")
    func invalidWorkoutHandling() {
        let active = WorkoutSession(planNameSnapshot: "Active", status: .active)
        #expect(throws: WorkoutShareError.workoutNotCompleted) {
            try WorkoutShareSummaryBuilder.build(from: active)
        }

        let empty = WorkoutSession(
            planNameSnapshot: "Empty",
            completedAt: Date(),
            status: .completed
        )
        #expect(throws: WorkoutShareError.noCompletedSets) {
            try WorkoutShareSummaryBuilder.build(from: empty)
        }
    }

    @Test("Long workout names get a stable card display name")
    func longWorkoutNameHandling() throws {
        let longName = "  Extremely Long Saturday Strength and Conditioning Session With Additional Mobility Work  "
        let session = completedSession(name: longName, exercises: [
            makeExercise(
                name: "Squat",
                order: 0,
                sets: [completedSet(number: 1, weight: 100, repetitions: 5)]
            )
        ])

        let summary = try WorkoutShareSummaryBuilder.build(from: session)

        #expect(summary.workoutName == longName.trimmingCharacters(in: .whitespaces))
        #expect(summary.displayWorkoutName.count <= WorkoutShareSummaryBuilder.maximumDisplayNameLength)
        #expect(summary.displayWorkoutName.hasSuffix("…"))
    }

    @Test("Random background selection avoids an immediate repeat")
    func backgroundRandomizationAvoidsRepeat() {
        var selection = WorkoutShareBackgroundSelection(initialIndex: 0)
        let original = selection.selected

        selection.randomize(index: 0)

        #expect(selection.selected != original)
        #expect(selection.available.count == 10)
    }

    @Test("Background remains stable until explicitly changed")
    func backgroundSelectionStability() {
        var selection = WorkoutShareBackgroundSelection(initialIndex: 4)
        let original = selection.selected
        #expect(selection.selected == original)
        #expect(selection.selected == original)

        selection.select(.evergreen)
        #expect(selection.selected == .evergreen)
    }

    @Test("An old completed session produces a valid share summary")
    func historicalSessionSharing() throws {
        let oldDate = Date(timeIntervalSince1970: 1_500_000_000)
        let session = WorkoutSession(
            planNameSnapshot: "Legacy Push Day",
            startedAt: oldDate,
            completedAt: oldDate.addingTimeInterval(3_000),
            status: .completed,
            exerciseRecords: [
                makeExercise(
                    name: "DB Bench",
                    order: 0,
                    sets: [completedSet(number: 1, weight: 30, repetitions: 10)]
                )
            ]
        )

        let summary = try WorkoutShareSummaryBuilder.build(from: session)

        #expect(summary.workoutName == "Legacy Push Day")
        #expect(summary.date == oldDate)
        #expect(summary.exerciseHighlights.first?.name == "DB Bench")
    }

    @Test("Plan changes cannot rewrite a historical share summary")
    func planChangesDoNotAffectHistoricalShare() throws {
        let planned = PlannedExercise(
            exerciseNameSnapshot: "Bench Press",
            targetSets: 1,
            targetRepetitions: 8,
            targetWeight: 60
        )
        let plan = WorkoutPlan(name: "Chest Day", exercises: [planned])
        let session = WorkoutService.makeSession(
            from: plan,
            now: Date(timeIntervalSince1970: 20_000)
        )
        let set = try #require(session.orderedExerciseRecords.first?.orderedSets.first)
        set.isCompleted = true
        session.status = .completed
        session.completedAt = session.startedAt.addingTimeInterval(2_400)

        plan.name = "Renamed Plan"
        planned.exerciseNameSnapshot = "Renamed Exercise"
        planned.targetWeight = 100

        let summary = try WorkoutShareSummaryBuilder.build(from: session)

        #expect(summary.workoutName == "Chest Day")
        #expect(summary.exerciseHighlights.first?.name == "Bench Press")
        #expect(summary.exerciseHighlights.first?.weight == 60)
    }

    @Test("Share renderer exports a sharp 4 by 5 image")
    func renderedImageDimensions() throws {
        let summary = try WorkoutShareSummaryBuilder.build(from: completedSession(exercises: [
            makeExercise(
                name: "Bench Press",
                order: 0,
                sets: [completedSet(number: 1, weight: 70, repetitions: 8)]
            )
        ]))

        let image = try WorkoutShareRenderer.render(summary: summary, background: .blackGold)

        #expect(image.cgImage?.width == 1_080)
        #expect(image.cgImage?.height == 1_350)
    }

    @Test("Share renderer handles long and large workout results")
    func renderedImageStressContent() throws {
        let summary = WorkoutShareSummary(
            workoutName: String(repeating: "Long Strength Session ", count: 8),
            date: Date(timeIntervalSince1970: 50_000),
            duration: 14_760,
            exerciseCount: 18,
            setCount: 124,
            repetitionCount: 2_048,
            trainingVolume: 1_250_000,
            exerciseHighlights: [
                .init(name: String(repeating: "Single Arm Cable Row ", count: 4), weight: 125.5, repetitions: 12, exerciseVolume: 12_000, sortOrder: 0),
                .init(name: "Romanian Deadlift", weight: 205, repetitions: 8, exerciseVolume: 9_840, sortOrder: 1),
                .init(name: "Bulgarian Split Squat", weight: 42.5, repetitions: 20, exerciseVolume: 6_800, sortOrder: 2)
            ]
        )

        for background in WorkoutShareBackground.allCases {
            let image = try WorkoutShareRenderer.render(summary: summary, background: background)
            #expect(image.cgImage?.width == 1_080)
            #expect(image.cgImage?.height == 1_350)
        }
    }

    private func completedSession(
        name: String = "Test Workout",
        exercises: [ExerciseRecord]
    ) -> WorkoutSession {
        let start = Date(timeIntervalSince1970: 50_000)
        return WorkoutSession(
            planNameSnapshot: name,
            startedAt: start,
            completedAt: start.addingTimeInterval(3_600),
            status: .completed,
            exerciseRecords: exercises
        )
    }

    private func makeExercise(
        name: String,
        order: Int,
        sets: [WorkoutSetRecord]
    ) -> ExerciseRecord {
        ExerciseRecord(
            exerciseNameSnapshot: name,
            sortOrder: order,
            sets: sets
        )
    }

    private func completedSet(
        number: Int,
        weight: Double,
        repetitions: Int,
        isWarmup: Bool = false
    ) -> WorkoutSetRecord {
        WorkoutSetRecord(
            setNumber: number,
            weight: weight,
            repetitions: repetitions,
            isCompleted: true,
            completedAt: Date(timeIntervalSince1970: 60_000),
            isWarmup: isWarmup
        )
    }
}

@MainActor
final class WorkoutShareRenderingAttachmentTests: XCTestCase {
    func testExportedCardIsFourByFive() throws {
        let summary = WorkoutShareSummary(
            workoutName: "Chest + Arms Performance Session",
            date: Date(timeIntervalSince1970: 1_786_651_200),
            duration: 4_680,
            exerciseCount: 5,
            setCount: 19,
            repetitionCount: 168,
            trainingVolume: 12_840,
            exerciseHighlights: [
                .init(name: "Barbell Bench Press", weight: 70, repetitions: 8, exerciseVolume: 2_100, sortOrder: 0),
                .init(name: "Incline Dumbbell Press", weight: 24, repetitions: 10, exerciseVolume: 960, sortOrder: 1),
                .init(name: "Cable Fly", weight: 20, repetitions: 12, exerciseVolume: 720, sortOrder: 2)
            ]
        )

        let image = try WorkoutShareRenderer.render(summary: summary, background: .ultraviolet)
        let attachment = XCTAttachment(image: image)
        attachment.name = "Rendered Workout Share Card 1080x1350"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertEqual(image.cgImage?.width, 1_080)
        XCTAssertEqual(image.cgImage?.height, 1_350)
    }
}
