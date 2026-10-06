import Foundation
import SwiftData
import Testing

@testable import GymFlow

@MainActor
struct DataSafetyTests {
    private struct ForcedFailure: Error {}

    @Test("A failed sample reset leaves saved user plans and definition identity intact")
    func resetPreparationFailurePreservesUserData() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let plan = WorkoutPlan(name: "User Plan")
        let definition = ExerciseDefinition(name: "Custom Lift", isCustom: true)
        context.insert(plan)
        context.insert(definition)
        try context.save()
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: SampleDataSeeder.seedingKey)
        defaults.set(
            SampleDataSeeder.currentExerciseLibraryVersion,
            forKey: SampleDataSeeder.exerciseLibraryVersionKey
        )

        #expect(throws: ForcedFailure.self) {
            try SampleDataSeeder.resetSamplePlans(
                context: context,
                defaults: defaults,
                makeSamplePlans: { throw ForcedFailure() }
            )
        }

        let persisted = ModelContext(container)
        #expect(try persisted.fetch(FetchDescriptor<WorkoutPlan>()).map(\.id) == [plan.id])
        #expect(
            try persisted.fetch(FetchDescriptor<ExerciseDefinition>()).map(\.id)
                == [definition.id]
        )
        #expect(defaults.bool(forKey: SampleDataSeeder.seedingKey))
    }

    @Test("A failed reset save rolls back staged deletion in the active context")
    func resetSaveFailureRollsBack() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let plan = WorkoutPlan(name: "User Plan")
        context.insert(plan)
        try context.save()
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: SampleDataSeeder.seedingKey)
        defaults.set(
            SampleDataSeeder.currentExerciseLibraryVersion,
            forKey: SampleDataSeeder.exerciseLibraryVersionKey
        )

        #expect(throws: ForcedFailure.self) {
            try SampleDataSeeder.resetSamplePlans(
                context: context,
                defaults: defaults,
                save: { _ in throw ForcedFailure() }
            )
        }

        #expect(try context.fetch(FetchDescriptor<WorkoutPlan>()).map(\.id) == [plan.id])
        #expect(
            try ModelContext(container).fetch(FetchDescriptor<WorkoutPlan>()).map(\.id)
                == [plan.id]
        )
        #expect(defaults.bool(forKey: SampleDataSeeder.seedingKey))
    }

    @Test("A failed reset does not discard unrelated pending context edits")
    func resetFailurePreservesPendingEdit() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let plan = WorkoutPlan(name: "User Plan")
        let definition = ExerciseDefinition(name: "Custom Lift", isCustom: true)
        context.insert(plan)
        context.insert(definition)
        try context.save()
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: SampleDataSeeder.seedingKey)
        defaults.set(
            SampleDataSeeder.currentExerciseLibraryVersion,
            forKey: SampleDataSeeder.exerciseLibraryVersionKey
        )
        definition.notes = "Pending user edit"

        #expect(throws: ForcedFailure.self) {
            try SampleDataSeeder.resetSamplePlans(
                context: context,
                defaults: defaults,
                save: { _ in throw ForcedFailure() }
            )
        }

        let persisted = ModelContext(container)
        #expect(
            try persisted.fetch(FetchDescriptor<ExerciseDefinition>()).first?.notes
                == "Pending user edit"
        )
        #expect(try persisted.fetch(FetchDescriptor<WorkoutPlan>()).map(\.id) == [plan.id])
    }

    @Test(
        "Failed workout ending preserves rest deadline and notification",
        arguments: [
            WorkoutSessionStatus.completed, .cancelled,
        ])
    func failedWorkoutEndingPreservesRest(status: WorkoutSessionStatus) throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let session = WorkoutSession(planNameSnapshot: "Active", status: .active)
        context.insert(session)
        try context.save()
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let scheduler = RecordingScheduler()
        let timerKey = RestTimerStorage.keyPrefix(for: session.id)
        let rest = RestTimerService(
            defaults: defaults,
            keyPrefix: timerKey,
            sessionID: session.id,
            notificationScheduler: scheduler
        )
        rest.start(duration: 120)
        let deadline = rest.deadline

        #expect(throws: ForcedFailure.self) {
            try WorkoutFinalizationService.persist(
                session: session,
                status: status,
                completedAt: Date(),
                restTimer: rest,
                save: { throw ForcedFailure() }
            )
        }

        #expect(session.status == .active)
        #expect(session.completedAt == nil)
        #expect(rest.isRunning)
        #expect(rest.deadline == deadline)
        #expect(scheduler.cancelled.isEmpty)
        #expect(
            RestTimerService.persistedActivityState(
                defaults: defaults, keyPrefix: timerKey
            ).deadline == deadline
        )
        rest.cancel()
    }

    @Test(
        "Successful workout ending persists status then cancels rest",
        arguments: [
            WorkoutSessionStatus.completed, .cancelled,
        ])
    func successfulWorkoutEndingCancelsRest(status: WorkoutSessionStatus) throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let session = WorkoutSession(planNameSnapshot: "Active", status: .active)
        context.insert(session)
        try context.save()
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let scheduler = RecordingScheduler()
        let rest = RestTimerService(
            defaults: defaults,
            keyPrefix: RestTimerStorage.keyPrefix(for: session.id),
            sessionID: session.id,
            notificationScheduler: scheduler
        )
        rest.start(duration: 120)

        try WorkoutFinalizationService.persist(
            session: session,
            status: status,
            completedAt: Date(),
            restTimer: rest,
            save: { try context.save() }
        )

        #expect(session.status == status)
        #expect(!rest.isRunning)
        #expect(rest.deadline == nil)
        #expect(scheduler.cancelled.count == 1)
        #expect(
            try ModelContext(container).fetch(FetchDescriptor<WorkoutSession>()).first?.status
                == status
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            WorkoutPlan.self, PlannedExercise.self, ExerciseDefinition.self,
            WorkoutSession.self, ExerciseRecord.self, WorkoutSetRecord.self,
        ])
        let configuration = ModelConfiguration(
            "DataSafetyTests", schema: schema,
            isStoredInMemoryOnly: true, cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suite = "GymFlow.DataSafetyTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (defaults, suite)
    }

    @MainActor
    private final class RecordingScheduler: RestTimerNotificationScheduling {
        var scheduled: [RestTimerNotificationPlan] = []
        var cancelled: [String] = []

        func schedule(_ plan: RestTimerNotificationPlan) { scheduled.append(plan) }
        func cancel(identifier: String) { cancelled.append(identifier) }
    }
}
