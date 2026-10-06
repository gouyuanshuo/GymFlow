#if DEBUG
    import Foundation
    import SwiftData

    /// Standalone diagnostic. Compile with the real model and service sources; never opens the app store.
    @main
    @MainActor
    enum DeepAuditBenchmark {
        static func main() throws {
            let sessionCount = max(1, Int(CommandLine.arguments.dropFirst().first ?? "500") ?? 500)
            let schema = Schema([
                ExerciseDefinition.self, WorkoutPlan.self, PlannedExercise.self,
                WorkoutSession.self, ExerciseRecord.self, WorkoutSetRecord.self,
                ImportedTrack.self, Playlist.self, PlaylistTrack.self,
            ])
            let configuration = ModelConfiguration(
                "DeepAuditBenchmark", schema: schema, isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

            let definitions = (0..<200).map { index in
                ExerciseDefinition(
                    id: fixedID(1, index), name: "Exercise \(index)",
                    isCustom: true, createdAt: baseDate
                )
            }
            for definition in definitions { context.insert(definition) }
            let plans = (0..<50).map { index in
                let exercises = (0..<5).map { offset in
                    let definition = definitions[(index * 5 + offset) % definitions.count]
                    return PlannedExercise(
                        id: fixedID(3, index * 5 + offset),
                        exerciseID: definition.id, exerciseNameSnapshot: definition.name,
                        targetSets: 2, targetRepetitions: 8, targetWeight: 50,
                        sortOrder: offset
                    )
                }
                return WorkoutPlan(
                    id: fixedID(2, index), name: "Plan \(index)",
                    sortOrder: index, exercises: exercises
                )
            }
            for plan in plans { context.insert(plan) }
            let sessions = (0..<sessionCount).map { index in
                let plan = plans[index % plans.count]
                let records = plan.orderedExercises.enumerated().map { offset, planned in
                    let sets = (1...2).map { number in
                        WorkoutSetRecord(
                            id: fixedID(6, index * 10 + offset * 2 + number - 1),
                            setNumber: number, weight: Double(50 + index % 25),
                            repetitions: 8, isCompleted: true,
                            completedAt: baseDate.addingTimeInterval(Double(index) * 86_400 + 1_800)
                        )
                    }
                    return ExerciseRecord(
                        id: fixedID(5, index * 5 + offset),
                        exerciseID: planned.exerciseID,
                        exerciseNameSnapshot: planned.exerciseNameSnapshot,
                        sortOrder: offset, sets: sets
                    )
                }
                return WorkoutSession(
                    id: fixedID(4, index),
                    workoutPlanID: plan.id, planNameSnapshot: plan.name,
                    startedAt: baseDate.addingTimeInterval(Double(index) * 86_400),
                    completedAt: baseDate.addingTimeInterval(Double(index) * 86_400 + 1_800),
                    status: .completed, exerciseRecords: records
                )
            }
            for session in sessions { context.insert(session) }
            try context.save()
            print(
                "fixture: 200 exercises, 50 plans, \(sessionCount) sessions, \(sessionCount * 10) sets; in-memory only"
            )

            var fetchedDefinitions: [ExerciseDefinition] = []
            measure("library fetch") {
                fetchedDefinitions = try context.fetch(FetchDescriptor<ExerciseDefinition>())
                return fetchedDefinitions.count
            }
            measure("library search") {
                fetchedDefinitions.filter { $0.name.localizedCaseInsensitiveContains("exercise 1") }
                    .count
            }
            var fetchedPlans: [WorkoutPlan] = []
            measure("plan fetch/open") {
                fetchedPlans = try context.fetch(FetchDescriptor<WorkoutPlan>())
                return fetchedPlans.first?.orderedExercises.count ?? 0
            }
            var fetchedSessions: [WorkoutSession] = []
            measure("completed history fetch") {
                fetchedSessions = try context.fetch(
                    FetchDescriptor<WorkoutSession>(
                        predicate: WorkoutSession.predicate(status: .completed),
                        sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
                    ))
                return fetchedSessions.count
            }
            let exercise = definitions[0]
            measure("exercise detail PB") {
                let candidates = try context.fetch(
                    FetchDescriptor<WorkoutSession>(
                        predicate: WorkoutSession.predicate(candidatesForExerciseID: exercise.id)
                    ))
                return ExercisePerformanceService.summary(for: exercise, sessions: candidates)
                    .personalBestEvents.count
            }
            measure("exercise progress scan") {
                let identity = ExerciseIdentity(exercise)
                return fetchedSessions.reduce(0) { count, session in
                    count
                        + ExerciseProgressHistory.completedWorkingSets(
                            matching: identity, in: session
                        ).count
                }
            }
            measure("calendar month") {
                WorkoutHistoryGrouper.monthOverview(
                    containing: baseDate.addingTimeInterval(86_400 * 480),
                    sessions: fetchedSessions
                ).summary.workoutCount
            }
            measure("workout prefill") {
                WorkoutService.makeSession(from: plans[0], previousSessions: fetchedSessions)
                    .exerciseRecords.count
            }
            let unmatchedPlan = WorkoutPlan(
                name: "Unmatched",
                exercises: [
                    PlannedExercise(
                        exerciseNameSnapshot: "Never Logged", targetSets: 5,
                        targetRepetitions: 8, targetWeight: 50
                    )
                ]
            )
            measure("workout prefill absent exercise") {
                WorkoutService.makeSession(
                    from: unmatchedPlan, previousSessions: fetchedSessions
                ).exerciseRecords.count
            }
            measure("share summary") {
                try WorkoutShareSummaryBuilder.build(
                    from: sessions[sessionCount - 1], sessions: fetchedSessions
                ).setCount
            }
            let duplicateIdentity = ExerciseIdentity(definitions[0])
            let first = ExerciseRecord(
                exerciseID: definitions[0].id,
                exerciseNameSnapshot: definitions[0].name,
                sortOrder: 0,
                sets: [WorkoutSetRecord(setNumber: 1)]
            )
            let second = ExerciseRecord(
                exerciseID: definitions[0].id,
                exerciseNameSnapshot: definitions[0].name,
                sortOrder: 1,
                sets: [WorkoutSetRecord(setNumber: 1, isCompleted: true)]
            )
            let duplicateSession = WorkoutSession(
                planNameSnapshot: "Duplicate entries", status: .completed,
                exerciseRecords: [first, second]
            )
            let detailFindsCompleted =
                duplicateSession.orderedExerciseRecords
                .first(where: duplicateIdentity.matches)?
                .orderedSets.contains(where: \.isCompleted) ?? false
            let progressFindsCompleted = !ExerciseProgressHistory.completedSets(
                matching: duplicateIdentity, in: duplicateSession
            ).isEmpty
            let recent = ExerciseProgressHistory.recentCompletedSessions(
                matching: duplicateIdentity, in: [duplicateSession], limit: 8
            )
            precondition(!detailFindsCompleted && progressFindsCompleted)
            precondition(recent.first?.completedSets.count == 1)
            print("duplicate-entry check: recent history includes later completed record")
            try verifyPersonalBestSemantics()
            try verifyCandidateQuery(context: context)
            verifyPrefillSemantics()
        }

        private static func verifyPersonalBestSemantics() throws {
            let exerciseID = fixedID(7, 1)
            let otherID = fixedID(7, 2)
            func session(
                day: Int, exerciseID: UUID?, name: String,
                weight: Double, repetitions: Int
            ) -> WorkoutSession {
                let started = Date(timeIntervalSince1970: Double(day) * 86_400)
                return WorkoutSession(
                    planNameSnapshot: "Semantics check",
                    startedAt: started,
                    completedAt: started.addingTimeInterval(3_600),
                    status: .completed,
                    exerciseRecords: [
                        ExerciseRecord(
                            exerciseID: exerciseID,
                            exerciseNameSnapshot: name,
                            sets: [
                                WorkoutSetRecord(
                                    setNumber: 1, weight: weight,
                                    repetitions: repetitions, isCompleted: true
                                )
                            ]
                        )
                    ]
                )
            }
            let old = session(
                day: 1, exerciseID: exerciseID, name: "Old Bench",
                weight: 70, repetitions: 8
            )
            let legacy = session(
                day: 2, exerciseID: nil, name: "  BENCH   PRESS  ",
                weight: 80, repetitions: 5
            )
            let unrelated = session(
                day: 3, exerciseID: otherID, name: "Bench Press",
                weight: 300, repetitions: 1
            )
            let current = session(
                day: 4, exerciseID: exerciseID, name: "Bench Press",
                weight: 90, repetitions: 3
            )
            let sessions = [current, unrelated, old, legacy]
            let best = ExercisePerformanceService.summary(
                exerciseID: exerciseID,
                exerciseName: "Bench Press",
                sessions: sessions
            )
            precondition(best.heaviestWeightRecord?.weight == 90)
            precondition(best.bestSetVolumeRecord?.setVolume == 560)
            precondition(best.bestRepetitionRecord?.repetitions == 8)
            precondition(abs((best.estimatedOneRepMaxRecord?.estimatedOneRepMax ?? 0) - 99) < 0.001)
            let events = ExercisePerformanceService.personalBestEvents(
                in: current, sessions: sessions
            )
            precondition(events.contains { $0.types.contains(.weight) })
            precondition(events.contains { $0.types.contains(.estimatedOneRepMax) })
            precondition(events.allSatisfy { !$0.types.contains(.setVolume) })
            let share = try WorkoutShareSummaryBuilder.build(from: current, sessions: sessions)
            precondition(share.personalBestHighlight?.typeTitle == "Weight PR")
            print(
                "PB/share semantics check: stable ID, legacy fallback, unrelated ID and PR types pass"
            )
        }

        private static func verifyCandidateQuery(context: ModelContext) throws {
            let targetID = fixedID(8, 1)
            let otherID = fixedID(8, 2)
            func session(_ id: UUID?, _ name: String, _ day: Int) -> WorkoutSession {
                let started = Date(timeIntervalSince1970: Double(day) * 86_400)
                return WorkoutSession(
                    planNameSnapshot: "Candidate query",
                    startedAt: started,
                    completedAt: started.addingTimeInterval(3_600),
                    status: .completed,
                    exerciseRecords: [
                        ExerciseRecord(
                            exerciseID: id, exerciseNameSnapshot: name,
                            sets: [
                                WorkoutSetRecord(
                                    setNumber: 1, weight: Double(day * 10),
                                    repetitions: 8, isCompleted: true
                                )
                            ]
                        )
                    ]
                )
            }
            let renamed = session(targetID, "Old Bench", 7)
            let legacy = session(nil, "  BENCH  PRESS  ", 8)
            let unrelated = session(otherID, "Bench Press", 9)
            for item in [renamed, legacy, unrelated] { context.insert(item) }
            try context.save()
            let candidates = try context.fetch(
                FetchDescriptor<WorkoutSession>(
                    predicate: WorkoutSession.predicate(candidatesForExerciseID: targetID)
                ))
            let ids = Set(candidates.map(\.id))
            precondition(ids.contains(renamed.id) && ids.contains(legacy.id))
            precondition(!ids.contains(unrelated.id))
            let summary = ExercisePerformanceService.summary(
                exerciseID: targetID, exerciseName: "Bench Press", sessions: candidates
            )
            precondition(summary.heaviestWeightRecord?.weight == 80)
            print(
                "PB candidate query check: renamed ID and normalized legacy match; other ID excluded"
            )
        }

        private static func verifyPrefillSemantics() {
            let targetID = fixedID(9, 1)
            let otherID = fixedID(9, 2)
            let plan = WorkoutPlan(
                name: "Prefill",
                exercises: [
                    PlannedExercise(
                        exerciseID: targetID, exerciseNameSnapshot: "New Bench",
                        targetSets: 3, targetRepetitions: 8, targetWeight: 40
                    )
                ])
            func record(_ id: UUID?, _ name: String, _ weights: [Double]) -> ExerciseRecord {
                ExerciseRecord(
                    exerciseID: id, exerciseNameSnapshot: name,
                    sets: weights.enumerated().map { index, weight in
                        WorkoutSetRecord(
                            setNumber: index + 1, weight: weight,
                            repetitions: 8, isCompleted: true
                        )
                    }
                )
            }
            let older = WorkoutSession(
                planNameSnapshot: "Older", startedAt: Date(timeIntervalSince1970: 1_000),
                status: .completed,
                exerciseRecords: [record(targetID, "Old Bench", [50, 55, 60])]
            )
            let newer = WorkoutSession(
                planNameSnapshot: "Newer", startedAt: Date(timeIntervalSince1970: 2_000),
                status: .completed,
                exerciseRecords: [
                    ExerciseRecord(
                        exerciseID: targetID, exerciseNameSnapshot: "Old Bench",
                        sets: [WorkoutSetRecord(setNumber: 1, weight: 100, repetitions: 3)]
                    ),
                    record(nil, " New  Bench ", [70, 75]),
                    record(otherID, "New Bench", [120, 120, 120]),
                ]
            )
            let result = WorkoutService.makeSession(
                from: plan, previousSessions: [older, newer]
            ).orderedExerciseRecords[0].orderedSets
            precondition(result.map(\.weight) == [70, 75, 60])
            let absent = WorkoutService.makeSession(
                from: plan, previousSessions: []
            ).orderedExerciseRecords[0].orderedSets
            precondition(absent.map(\.weight) == [40, 40, 40])
            print(
                "prefill semantics check: older valid, multiple sets, renamed ID, legacy and fallback pass"
            )
        }

        private static func fixedID(_ category: Int, _ index: Int) -> UUID {
            UUID(
                uuid: (
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    UInt8(truncatingIfNeeded: category),
                    UInt8(truncatingIfNeeded: index >> 24),
                    UInt8(truncatingIfNeeded: index >> 16),
                    UInt8(truncatingIfNeeded: index >> 8),
                    UInt8(truncatingIfNeeded: index)
                ))
        }

        private static func measure(_ name: String, _ operation: () throws -> Int) {
            let start = DispatchTime.now().uptimeNanoseconds
            do {
                let result = try operation()
                let milliseconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
                print(String(format: "%@: %.2f ms (result %d)", name, milliseconds, result))
            } catch {
                print("\(name): ERROR \(error)")
            }
        }
    }
#endif
