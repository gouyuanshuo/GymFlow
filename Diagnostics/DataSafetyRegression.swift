#if DEBUG
    import Foundation
    import SwiftData

    @MainActor
    private final class RecordingScheduler: RestTimerNotificationScheduling {
        var plans: [RestTimerNotificationPlan] = []
        var cancellations: [String] = []

        func schedule(_ plan: RestTimerNotificationPlan) { plans.append(plan) }
        func cancel(identifier: String) { cancellations.append(identifier) }
    }

    private struct ForcedFailure: Error {}

    @main
    @MainActor
    enum DataSafetyRegression {
        static func main() throws {
            try sampleResetPreservesPlansWhenPreparationFails()
            try sampleResetRollsBackWhenSaveFails()
            try sampleResetFailureKeepsPendingUnrelatedEdit()
            try successfulSampleResetPreservesHistoryIdentity()
            try failedWorkoutEndingPreservesRest(.completed)
            try failedWorkoutEndingPreservesRest(.cancelled)
            try successfulWorkoutEndingCancelsRest(.completed)
            try successfulWorkoutEndingCancelsRest(.cancelled)
            print("Data safety regression checks passed")
        }

        private static func makeContainer() throws -> ModelContainer {
            let schema = Schema([
                WorkoutPlan.self, PlannedExercise.self, ExerciseDefinition.self,
                WorkoutSession.self, ExerciseRecord.self, WorkoutSetRecord.self,
            ])
            let configuration = ModelConfiguration(
                "DataSafetyRegression", schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        }

        private static func makeDefaults() throws -> (UserDefaults, String) {
            let suite = "GymFlow.DataSafetyRegression.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suite) else {
                throw ForcedFailure()
            }
            return (defaults, suite)
        }

        private static func sampleResetPreservesPlansWhenPreparationFails() throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            let (defaults, suite) = try makeDefaults()
            defer { defaults.removePersistentDomain(forName: suite) }
            let definition = ExerciseDefinition(name: "User Exercise", isCustom: true)
            let plan = WorkoutPlan(name: "User Plan")
            context.insert(definition)
            context.insert(plan)
            try context.save()
            defaults.set(true, forKey: SampleDataSeeder.seedingKey)
            defaults.set(
                SampleDataSeeder.currentExerciseLibraryVersion,
                forKey: SampleDataSeeder.exerciseLibraryVersionKey
            )

            do {
                try SampleDataSeeder.resetSamplePlans(
                    context: context,
                    defaults: defaults,
                    makeSamplePlans: { throw ForcedFailure() }
                )
                preconditionFailure("Preparation failure was not surfaced")
            } catch is ForcedFailure {
                let savedPlans = try ModelContext(container).fetch(FetchDescriptor<WorkoutPlan>())
                let savedDefinitions = try ModelContext(container).fetch(
                    FetchDescriptor<ExerciseDefinition>()
                )
                precondition(savedPlans.map(\.id) == [plan.id], "Reset lost the user's plan")
                precondition(savedDefinitions.map(\.id) == [definition.id])
                precondition(defaults.bool(forKey: SampleDataSeeder.seedingKey))
            }
        }

        private static func sampleResetRollsBackWhenSaveFails() throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            let (defaults, suite) = try makeDefaults()
            defer { defaults.removePersistentDomain(forName: suite) }
            let plan = WorkoutPlan(name: "User Plan")
            context.insert(plan)
            try context.save()
            defaults.set(true, forKey: SampleDataSeeder.seedingKey)
            defaults.set(
                SampleDataSeeder.currentExerciseLibraryVersion,
                forKey: SampleDataSeeder.exerciseLibraryVersionKey
            )

            do {
                try SampleDataSeeder.resetSamplePlans(
                    context: context,
                    defaults: defaults,
                    save: { _ in throw ForcedFailure() }
                )
                preconditionFailure("Save failure was not surfaced")
            } catch is ForcedFailure {
                let currentPlans = try context.fetch(FetchDescriptor<WorkoutPlan>())
                let savedPlans = try ModelContext(container).fetch(FetchDescriptor<WorkoutPlan>())
                precondition(currentPlans.map(\.id) == [plan.id], "Context retained deletion")
                precondition(savedPlans.map(\.id) == [plan.id], "Store lost the user's plan")
                precondition(defaults.bool(forKey: SampleDataSeeder.seedingKey))
            }
        }

        private static func failedWorkoutEndingPreservesRest(_ status: WorkoutSessionStatus) throws
        {
            let container = try makeContainer()
            let context = ModelContext(container)
            let session = WorkoutSession(planNameSnapshot: "Active", status: .active)
            context.insert(session)
            try context.save()
            let (defaults, suite) = try makeDefaults()
            defer { defaults.removePersistentDomain(forName: suite) }
            let scheduler = RecordingScheduler()
            let keyPrefix = RestTimerStorage.keyPrefix(for: session.id)
            let rest = RestTimerService(
                defaults: defaults,
                keyPrefix: keyPrefix,
                sessionID: session.id,
                notificationScheduler: scheduler
            )
            rest.start(duration: 120)
            let originalDeadline = rest.deadline

            do {
                try WorkoutFinalizationService.persist(
                    session: session,
                    status: status,
                    completedAt: Date(),
                    restTimer: rest,
                    save: { throw ForcedFailure() }
                )
                preconditionFailure("Save failure was not surfaced")
            } catch is ForcedFailure {
                precondition(session.status == .active)
                precondition(session.completedAt == nil)
                precondition(rest.isRunning)
                precondition(rest.deadline == originalDeadline)
                precondition(scheduler.cancellations.isEmpty)
                precondition(
                    RestTimerService.persistedActivityState(
                        defaults: defaults,
                        keyPrefix: keyPrefix
                    ).deadline == originalDeadline
                )
            }
            rest.cancel()
        }

        private static func successfulWorkoutEndingCancelsRest(_ status: WorkoutSessionStatus)
            throws
        {
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

            precondition(session.status == status)
            precondition(!rest.isRunning)
            precondition(rest.deadline == nil)
            precondition(scheduler.cancellations.count == 1)
            let persisted = try ModelContext(container).fetch(FetchDescriptor<WorkoutSession>())
            precondition(persisted.first?.status == status)
        }

        private static func sampleResetFailureKeepsPendingUnrelatedEdit() throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            let (defaults, suite) = try makeDefaults()
            defer { defaults.removePersistentDomain(forName: suite) }
            let plan = WorkoutPlan(name: "User Plan")
            let definition = ExerciseDefinition(name: "User Exercise", isCustom: true)
            context.insert(plan)
            context.insert(definition)
            try context.save()
            defaults.set(true, forKey: SampleDataSeeder.seedingKey)
            defaults.set(
                SampleDataSeeder.currentExerciseLibraryVersion,
                forKey: SampleDataSeeder.exerciseLibraryVersionKey
            )
            definition.notes = "Pending user edit"

            do {
                try SampleDataSeeder.resetSamplePlans(
                    context: context,
                    defaults: defaults,
                    save: { _ in throw ForcedFailure() }
                )
                preconditionFailure("Save failure was not surfaced")
            } catch is ForcedFailure {
                let persisted = ModelContext(container)
                let savedDefinition = try persisted.fetch(
                    FetchDescriptor<ExerciseDefinition>()
                ).first
                let savedPlans = try persisted.fetch(FetchDescriptor<WorkoutPlan>())
                precondition(savedDefinition?.notes == "Pending user edit")
                precondition(savedPlans.map(\.id) == [plan.id])
            }
        }
        private static func successfulSampleResetPreservesHistoryIdentity() throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            let (defaults, suite) = try makeDefaults()
            defer { defaults.removePersistentDomain(forName: suite) }
            let definition = ExerciseDefinition(name: "Barbell Bench Press")
            let userPlan = WorkoutPlan(name: "User Plan")
            let completedSet = WorkoutSetRecord(
                setNumber: 1, weight: 80, repetitions: 5, isCompleted: true
            )
            let record = ExerciseRecord(
                exerciseID: definition.id,
                exerciseNameSnapshot: "Old Bench Name",
                sets: [completedSet]
            )
            let historicalSession = WorkoutSession(
                planNameSnapshot: "Old Plan",
                status: .completed,
                exerciseRecords: [record]
            )
            context.insert(definition)
            context.insert(userPlan)
            context.insert(historicalSession)
            try context.save()
            defaults.set(true, forKey: SampleDataSeeder.seedingKey)
            defaults.set(
                SampleDataSeeder.currentExerciseLibraryVersion,
                forKey: SampleDataSeeder.exerciseLibraryVersionKey
            )

            try SampleDataSeeder.resetSamplePlans(context: context, defaults: defaults)

            let persisted = ModelContext(container)
            let plans = try persisted.fetch(FetchDescriptor<WorkoutPlan>())
            let definitions = try persisted.fetch(FetchDescriptor<ExerciseDefinition>())
            let sessions = try persisted.fetch(FetchDescriptor<WorkoutSession>())
            precondition(plans.count == 3)
            precondition(!plans.contains { $0.id == userPlan.id })
            precondition(definitions.contains { $0.id == definition.id })
            precondition(sessions.count == 1)
            precondition(sessions[0].exerciseRecords.first?.exerciseID == definition.id)
            precondition(sessions[0].exerciseRecords.first?.sets.first?.weight == 80)
        }
    }
#endif
