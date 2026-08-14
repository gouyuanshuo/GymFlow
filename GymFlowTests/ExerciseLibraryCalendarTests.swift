import Foundation
import SwiftData
import Testing
@testable import GymFlow

@MainActor
struct ExerciseLibraryCalendarTests {
    @Test("A custom exercise is trimmed and created with editable metadata")
    func customExerciseCreation() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let definition = try ExerciseLibraryService.create(
            input: makeInput(
                name: "  Incline Press  ",
                muscleGroup: "Chest",
                equipment: "Dumbbell",
                defaultRestSeconds: 120,
                defaultSets: 4,
                defaultRepetitions: 8,
                notes: "  Controlled lowering  "
            ),
            existingDefinitions: [],
            now: now
        )

        #expect(definition.name == "Incline Press")
        #expect(definition.isCustom)
        #expect(!definition.isArchived)
        #expect(definition.defaultRestSeconds == 120)
        #expect(definition.defaultSets == 4)
        #expect(definition.defaultRepetitions == 8)
        #expect(definition.notes == "Controlled lowering")
        #expect(definition.createdAt == now)
        #expect(definition.updatedAt == now)
    }

    @Test("Exercise names reject case, whitespace, and diacritic duplicates")
    func duplicateExerciseNameValidation() {
        let existing = ExerciseDefinition(name: "Bénch   Press")

        #expect(throws: ExerciseLibraryError.duplicateName("bench press")) {
            try ExerciseLibraryService.create(
                input: makeInput(name: " bench press "),
                existingDefinitions: [existing]
            )
        }
    }

    @Test("Exercise archive and restore preserve the definition")
    func archiveAndRestore() {
        let definition = ExerciseDefinition(name: "Cable Curl")
        let archivedAt = Date(timeIntervalSince1970: 2_000)
        ExerciseLibraryService.setArchived(true, for: definition, now: archivedAt)
        #expect(definition.isArchived)
        #expect(definition.updatedAt == archivedAt)

        let restoredAt = Date(timeIntervalSince1970: 3_000)
        ExerciseLibraryService.setArchived(false, for: definition, now: restoredAt)
        #expect(!definition.isArchived)
        #expect(definition.updatedAt == restoredAt)
    }

    @Test("Exercise defaults seed a new planned exercise")
    func exerciseDefaultsSeedPlanDraft() {
        let definition = ExerciseDefinition(
            name: "Bench Press",
            defaultRestSeconds: 180,
            defaultSets: 5,
            defaultRepetitions: 6
        )
        let draft = PlannedExerciseDraft(definition: definition, restSeconds: 75)

        #expect(draft.exerciseID == definition.id)
        #expect(draft.name == "Bench Press")
        #expect(draft.targetSets == 5)
        #expect(draft.targetRepetitions == 6)
        #expect(draft.restSeconds == 180)
    }

    @Test("Plan-specific overrides remain independent from definition defaults")
    func planOverridesRemainIndependent() {
        let definition = ExerciseDefinition(
            name: "Bench Press",
            defaultRestSeconds: 180,
            defaultSets: 4,
            defaultRepetitions: 8
        )
        var draft = PlannedExerciseDraft(definition: definition)
        draft.targetSets = 5
        draft.targetRepetitions = 5
        draft.restSeconds = 240
        let planned = PlannedExercise(
            exerciseID: draft.exerciseID,
            exerciseNameSnapshot: draft.name,
            targetSets: draft.targetSets,
            targetRepetitions: draft.targetRepetitions,
            restSeconds: draft.restSeconds
        )

        definition.defaultSets = 3
        definition.defaultRepetitions = 12
        definition.defaultRestSeconds = 60

        #expect(planned.targetSets == 5)
        #expect(planned.targetRepetitions == 5)
        #expect(planned.restSeconds == 240)
    }

    @Test("Renaming a definition updates current plans but not workout history")
    func exerciseRenamePreservesHistorySnapshot() throws {
        let definition = ExerciseDefinition(name: "DB Bench", isCustom: true)
        let planned = PlannedExercise(
            exerciseID: definition.id,
            exerciseNameSnapshot: definition.name
        )
        let plan = WorkoutPlan(name: "Push", exercises: [planned])
        let session = WorkoutService.makeSession(from: plan)

        try ExerciseLibraryService.update(
            definition,
            input: makeInput(name: "Incline Dumbbell Bench Press"),
            existingDefinitions: [definition],
            plans: [plan],
            now: Date(timeIntervalSince1970: 4_000)
        )

        #expect(definition.name == "Incline Dumbbell Bench Press")
        #expect(planned.exerciseNameSnapshot == "Incline Dumbbell Bench Press")
        #expect(session.orderedExerciseRecords[0].exerciseNameSnapshot == "DB Bench")
    }

    @Test("Archived exercises remain readable wherever they are already used")
    func archivedExerciseRemainsReadable() {
        let definition = ExerciseDefinition(name: "Cable Curl", isCustom: true)
        let planned = PlannedExercise(
            exerciseID: definition.id,
            exerciseNameSnapshot: definition.name
        )
        let plan = WorkoutPlan(name: "Arms", exercises: [planned])
        let session = WorkoutService.makeSession(from: plan)
        session.status = .completed
        session.completedAt = session.startedAt.addingTimeInterval(1_800)

        ExerciseLibraryService.setArchived(true, for: definition)

        #expect(definition.isArchived)
        #expect(plan.orderedExercises[0].exerciseNameSnapshot == "Cable Curl")
        #expect(session.orderedExerciseRecords[0].exerciseNameSnapshot == "Cable Curl")
        #expect(ExerciseLibraryService.isUsed(definition, plans: [plan], sessions: [session]))
    }

    @Test("Built-in seeding is idempotent and links exact legacy plan names")
    func idempotentExerciseSeedingAndLegacyLinking() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WorkoutPlan.self, PlannedExercise.self, ExerciseDefinition.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let legacyExercise = PlannedExercise(exerciseNameSnapshot: "Barbell Bench Press")
        context.insert(WorkoutPlan(name: "Legacy", exercises: [legacyExercise]))
        let suiteName = "ExerciseLibraryCalendarTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        try SampleDataSeeder.seedIfNeeded(context: context, defaults: defaults)
        let firstCount = try context.fetchCount(FetchDescriptor<ExerciseDefinition>())
        try SampleDataSeeder.seedIfNeeded(context: context, defaults: defaults)
        let definitions = try context.fetch(FetchDescriptor<ExerciseDefinition>())

        #expect(definitions.count == firstCount)
        #expect(Set(definitions.map { ExerciseLibraryService.normalizedName($0.name) }).count == definitions.count)
        #expect(legacyExercise.exerciseID != nil)

        let removedBuiltIn = try #require(definitions.first(where: { $0.name == "Rowing Machine" }))
        context.delete(removedBuiltIn)
        try context.save()
        let countAfterExplicitDeletion = try context.fetchCount(FetchDescriptor<ExerciseDefinition>())
        try SampleDataSeeder.seedIfNeeded(context: context, defaults: defaults)
        #expect(try context.fetchCount(FetchDescriptor<ExerciseDefinition>()) == countAfterExplicitDeletion)
    }

    @Test("Exercise edits and archive state persist across model contexts")
    func exerciseEditsPersist() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ExerciseDefinition.self,
            configurations: configuration
        )
        let firstContext = ModelContext(container)
        let definition = ExerciseDefinition(name: "Persistence Test", isCustom: true)
        firstContext.insert(definition)
        try firstContext.save()

        try ExerciseLibraryService.update(
            definition,
            input: makeInput(
                name: "Persistent Exercise",
                defaultRestSeconds: 210,
                notes: "Persisted note"
            ),
            existingDefinitions: [definition],
            plans: []
        )
        ExerciseLibraryService.setArchived(true, for: definition)
        try firstContext.save()

        let secondContext = ModelContext(container)
        let restored = try #require(secondContext.fetch(FetchDescriptor<ExerciseDefinition>()).first)
        #expect(restored.name == "Persistent Exercise")
        #expect(restored.defaultRestSeconds == 210)
        #expect(restored.notes == "Persisted note")
        #expect(restored.isArchived)
    }

    @Test("Completed sessions group by local calendar day")
    func calendarGroupsByLocalDay() throws {
        let calendar = testCalendar
        let start = try date(2026, 8, 14, 8, 30, calendar: calendar)
        let session = makeSession(startedAt: start, completedAt: start.addingTimeInterval(3_600))
        let grouped = WorkoutHistoryGrouper.groupCompletedSessions([session], calendar: calendar)

        #expect(grouped[calendar.startOfDay(for: start)]?.map(\.id) == [session.id])
    }

    @Test("Multiple completed sessions share one training day")
    func multipleSessionsOnOneDay() throws {
        let calendar = testCalendar
        let morning = try date(2026, 8, 14, 7, 0, calendar: calendar)
        let evening = try date(2026, 8, 14, 18, 0, calendar: calendar)
        let first = makeSession(startedAt: morning, completedAt: morning.addingTimeInterval(1_800))
        let second = makeSession(startedAt: evening, completedAt: evening.addingTimeInterval(2_400))
        let grouped = WorkoutHistoryGrouper.groupCompletedSessions([second, first], calendar: calendar)

        #expect(grouped[calendar.startOfDay(for: morning)]?.map(\.id) == [first.id, second.id])
    }

    @Test("Cancelled, active, and planned sessions are excluded from calendar history")
    func nonCompletedSessionsAreExcluded() throws {
        let calendar = testCalendar
        let start = try date(2026, 8, 14, 9, 0, calendar: calendar)
        let cancelled = makeSession(startedAt: start, status: .cancelled)
        let active = makeSession(startedAt: start, status: .active)
        let planned = makeSession(startedAt: start, status: .planned)

        #expect(WorkoutHistoryGrouper.groupCompletedSessions(
            [cancelled, active, planned],
            calendar: calendar
        ).isEmpty)
    }

    @Test("A cross-midnight workout belongs to its local start date")
    func crossMidnightUsesStartDate() throws {
        let calendar = testCalendar
        let start = try date(2026, 8, 14, 23, 30, calendar: calendar)
        let completion = try date(2026, 8, 15, 0, 45, calendar: calendar)
        let session = makeSession(startedAt: start, completedAt: completion)
        let grouped = WorkoutHistoryGrouper.groupCompletedSessions([session], calendar: calendar)

        #expect(grouped[try date(2026, 8, 14, calendar: calendar)]?.count == 1)
        #expect(grouped[try date(2026, 8, 15, calendar: calendar)] == nil)
    }

    @Test("Month filtering keeps workouts in the correct month")
    func calendarMonthFiltering() throws {
        let calendar = testCalendar
        let augustDate = try date(2026, 8, 20, calendar: calendar)
        let july = makeSession(startedAt: try date(2026, 7, 31, 20, 0, calendar: calendar))
        let august = makeSession(startedAt: try date(2026, 8, 1, 8, 0, calendar: calendar))
        let september = makeSession(startedAt: try date(2026, 9, 1, 7, 0, calendar: calendar))

        let result = WorkoutHistoryGrouper.completedSessions(
            inMonthContaining: augustDate,
            from: [july, august, september],
            calendar: calendar
        )
        #expect(result.map(\.id) == [august.id])
    }

    @Test("Monthly summary counts workouts, training days, duration, and volume")
    func calendarMonthlySummary() throws {
        let calendar = testCalendar
        let firstStart = try date(2026, 8, 3, 8, 0, calendar: calendar)
        let secondStart = try date(2026, 8, 3, 18, 0, calendar: calendar)
        let thirdStart = try date(2026, 8, 5, 8, 0, calendar: calendar)
        let first = makeSession(startedAt: firstStart, completedAt: firstStart.addingTimeInterval(1_800))
        let second = makeSession(startedAt: secondStart, completedAt: secondStart.addingTimeInterval(2_400))
        let third = makeSession(startedAt: thirdStart, completedAt: thirdStart.addingTimeInterval(3_000))

        let summary = WorkoutHistoryGrouper.summary(
            inMonthContaining: firstStart,
            sessions: [first, second, third],
            calendar: calendar
        )
        #expect(summary.workoutCount == 3)
        #expect(summary.trainingDayCount == 2)
        #expect(summary.totalDuration == 7_200)
    }

    @Test("Empty history produces no calendar groups or monthly statistics")
    func emptyCalendarHistory() throws {
        let calendar = testCalendar
        let month = try date(2026, 8, 1, calendar: calendar)

        #expect(WorkoutHistoryGrouper.groupCompletedSessions([], calendar: calendar).isEmpty)
        #expect(WorkoutHistoryGrouper.summary(
            inMonthContaining: month,
            sessions: [],
            calendar: calendar
        ) == .empty)
    }

    @Test("Month grid follows a Monday-first local calendar")
    func mondayFirstMonthGrid() throws {
        let calendar = testCalendar
        let month = try date(2026, 8, 14, calendar: calendar)
        let grid = WorkoutHistoryGrouper.monthGridDates(containing: month, calendar: calendar)
        let firstDay = try date(2026, 8, 1, calendar: calendar)

        #expect(grid.count == 42)
        #expect(grid.prefix(5).allSatisfy { $0 == nil })
        #expect(grid[5] == firstDay)
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_AU")
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }

    private func makeInput(
        name: String,
        muscleGroup: String = "Other",
        equipment: String = "Other",
        defaultRestSeconds: Int? = nil,
        defaultSets: Int? = nil,
        defaultRepetitions: Int? = nil,
        notes: String = ""
    ) -> ExerciseDefinitionInput {
        ExerciseDefinitionInput(
            name: name,
            muscleGroup: muscleGroup,
            secondaryMuscleGroups: [],
            equipment: equipment,
            defaultRestSeconds: defaultRestSeconds,
            defaultSets: defaultSets,
            defaultRepetitions: defaultRepetitions,
            notes: notes
        )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 0,
        _ minute: Int = 0,
        calendar: Calendar
    ) throws -> Date {
        try #require(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }

    private func makeSession(
        startedAt: Date,
        completedAt: Date? = nil,
        status: WorkoutSessionStatus = .completed
    ) -> WorkoutSession {
        let completionDate: Date?
        if let completedAt {
            completionDate = completedAt
        } else if status == .completed {
            completionDate = startedAt.addingTimeInterval(1_800)
        } else {
            completionDate = nil
        }
        let set = WorkoutSetRecord(
            setNumber: 1,
            weight: 50,
            repetitions: 10,
            isCompleted: status == .completed
        )
        let record = ExerciseRecord(exerciseNameSnapshot: "Test Exercise", sets: [set])
        return WorkoutSession(
            planNameSnapshot: "Test Workout",
            startedAt: startedAt,
            completedAt: completionDate,
            status: status,
            exerciseRecords: [record]
        )
    }
}
