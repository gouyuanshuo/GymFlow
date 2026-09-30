import Foundation
import SwiftData
import Testing
@testable import GymFlow

@MainActor
@Suite("GymFlow SwiftData migration safety")
struct GymFlowDataStoreMigrationTests {
    @Test("Schema V1 is explicit and its persisted shape is locked")
    func currentSchemaContract() {
        #expect(GymFlowSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(GymFlowSchemaV1.models.count == 9)
        #expect(GymFlowMigrationPlan.schemas.count == 1)
        #expect(GymFlowMigrationPlan.schemas[0] == GymFlowSchemaV1.self)
        #expect(GymFlowMigrationPlan.stages.isEmpty)
        #expect(schemaSignature(GymFlowDataStore.schema) == Self.expectedV1SchemaSignature)
    }

    @Test("An implicit legacy store opens through Schema V1 without losing workout data")
    func implicitLegacyStoreUpgrade() throws {
        let fixtureDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GymFlowMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: fixtureDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: fixtureDirectory) }
        let storeURL = fixtureDirectory.appendingPathComponent("GymFlowV1.store")
        let expected = try createImplicitLegacyStore(at: storeURL)

        let currentConfiguration = ModelConfiguration(
            "GymFlowMigrationFixture",
            schema: GymFlowDataStore.schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try GymFlowDataStore.makeContainer(
            configurations: [currentConfiguration]
        )
        let context = ModelContext(container)

        let definition = try #require(
            context.fetch(FetchDescriptor<ExerciseDefinition>()).first
        )
        #expect(definition.id == expected.exerciseDefinitionID)
        #expect(definition.name == "Current Library Name")

        let plan = try #require(context.fetch(FetchDescriptor<WorkoutPlan>()).first)
        let plannedExercise = try #require(plan.orderedExercises.first)
        #expect(plan.id == expected.planID)
        #expect(plannedExercise.id == expected.plannedExerciseID)
        #expect(plannedExercise.exerciseID == expected.exerciseDefinitionID)
        #expect(plannedExercise.exerciseNameSnapshot == "Current Library Name")

        let session = try #require(context.fetch(FetchDescriptor<WorkoutSession>()).first)
        let exerciseRecord = try #require(session.orderedExerciseRecords.first)
        let workoutSet = try #require(exerciseRecord.orderedSets.first)
        #expect(session.id == expected.sessionID)
        #expect(session.status == .completed)
        #expect(session.workoutPlanID == expected.planID)
        #expect(session.planNameSnapshot == "Historical Plan Snapshot")
        #expect(session.startedAt == Date(timeIntervalSince1970: 1_000))
        #expect(session.completedAt == Date(timeIntervalSince1970: 1_300))
        #expect(exerciseRecord.id == expected.exerciseRecordID)
        #expect(exerciseRecord.exerciseID == expected.exerciseDefinitionID)
        #expect(exerciseRecord.exerciseNameSnapshot == "Historical Snapshot Name")
        #expect(workoutSet.id == expected.workoutSetID)
        #expect(workoutSet.isCompleted)
        #expect(workoutSet.weight == 82.5)
        #expect(workoutSet.repetitions == 5)
    }

    private func createImplicitLegacyStore(at storeURL: URL) throws -> FixtureIdentity {
        // This is the exact implicit schema construction used before GymFlow adopted
        // VersionedSchema. It intentionally has no migration plan.
        let legacySchema = Schema([
            WorkoutPlan.self,
            PlannedExercise.self,
            ExerciseDefinition.self,
            WorkoutSession.self,
            ExerciseRecord.self,
            WorkoutSetRecord.self,
            ImportedTrack.self,
            Playlist.self,
            PlaylistTrack.self,
        ])
        let configuration = ModelConfiguration(
            "GymFlowMigrationFixture",
            schema: legacySchema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: legacySchema,
            configurations: [configuration]
        )
        let context = ModelContext(container)
        let identity = FixtureIdentity()
        let definition = ExerciseDefinition(
            id: identity.exerciseDefinitionID,
            name: "Current Library Name",
            muscleGroup: "Chest",
            equipment: "Barbell"
        )
        let plannedExercise = PlannedExercise(
            id: identity.plannedExerciseID,
            exerciseID: identity.exerciseDefinitionID,
            exerciseNameSnapshot: "Current Library Name",
            targetSets: 1,
            targetRepetitions: 5,
            targetWeight: 82.5
        )
        let plan = WorkoutPlan(
            id: identity.planID,
            name: "Fixture Plan",
            exercises: [plannedExercise]
        )
        let workoutSet = WorkoutSetRecord(
            id: identity.workoutSetID,
            setNumber: 1,
            weight: 82.5,
            repetitions: 5,
            isCompleted: true,
            completedAt: Date(timeIntervalSince1970: 1_200)
        )
        let exerciseRecord = ExerciseRecord(
            id: identity.exerciseRecordID,
            exerciseID: identity.exerciseDefinitionID,
            exerciseNameSnapshot: "Historical Snapshot Name",
            sets: [workoutSet]
        )
        let session = WorkoutSession(
            id: identity.sessionID,
            workoutPlanID: identity.planID,
            planNameSnapshot: "Historical Plan Snapshot",
            startedAt: Date(timeIntervalSince1970: 1_000),
            completedAt: Date(timeIntervalSince1970: 1_300),
            status: .completed,
            exerciseRecords: [exerciseRecord]
        )

        context.insert(definition)
        context.insert(plan)
        context.insert(session)
        try context.save()
        return identity
    }

    private func schemaSignature(_ schema: Schema) -> String {
        schema.entities.sorted(by: { $0.name < $1.name }).flatMap { entity in
            let properties = entity.properties.sorted(by: { $0.name < $1.name })
            return ["[\(entity.name)]"] + properties.map { property in
                if let relationship = property as? Schema.Relationship {
                    return "\(property.name)|relationship|\(relationship.destination)"
                        + "|\(relationship.deleteRule.rawValue)|\(property.isOptional)"
                }
                return "\(property.name)|attribute|\(String(reflecting: property.valueType))"
                    + "|\(property.isOptional)|\(property.isUnique)"
            }
        }
        .joined(separator: "\n")
    }

    private struct FixtureIdentity {
        let exerciseDefinitionID = UUID()
        let plannedExerciseID = UUID()
        let planID = UUID()
        let sessionID = UUID()
        let exerciseRecordID = UUID()
        let workoutSetID = UUID()
    }

    /// Changing this signature means V1 changed in place. Add a new VersionedSchema and migration
    /// stage instead of updating this fixture unless the persisted model shape truly did not change.
    private static let expectedV1SchemaSignature = """
        [ExerciseDefinition]
        createdAt|attribute|Foundation.Date|false|false
        defaultRepetitions|attribute|Swift.Optional<Swift.Int>|true|false
        defaultRestSeconds|attribute|Swift.Optional<Swift.Int>|true|false
        defaultSets|attribute|Swift.Optional<Swift.Int>|true|false
        equipment|attribute|Swift.String|false|false
        id|attribute|Foundation.UUID|false|true
        isArchived|attribute|Swift.Bool|false|false
        isCustom|attribute|Swift.Bool|false|false
        muscleGroup|attribute|Swift.String|false|false
        name|attribute|Swift.String|false|false
        notes|attribute|Swift.String|false|false
        secondaryMuscleGroups|attribute|Swift.Array<Swift.String>|false|false
        updatedAt|attribute|Foundation.Date|false|false
        [ExerciseRecord]
        exerciseID|attribute|Swift.Optional<Foundation.UUID>|true|false
        exerciseNameSnapshot|attribute|Swift.String|false|false
        id|attribute|Foundation.UUID|false|true
        notes|attribute|Swift.String|false|false
        restSeconds|attribute|Swift.Int|false|false
        sets|relationship|WorkoutSetRecord|cascade|false
        sortOrder|attribute|Swift.Int|false|false
        [ImportedTrack]
        album|attribute|Swift.Optional<Swift.String>|true|false
        artist|attribute|Swift.String|false|false
        artworkData|attribute|Swift.Optional<Foundation.Data>|true|false
        createdAt|attribute|Foundation.Date|false|false
        duration|attribute|Swift.Optional<Swift.Double>|true|false
        fileExtension|attribute|Swift.String|false|false
        id|attribute|Foundation.UUID|false|true
        originalFileName|attribute|Swift.String|false|false
        sortOrder|attribute|Swift.Int|false|false
        storedFileName|attribute|Swift.String|false|false
        title|attribute|Swift.String|false|false
        [PlannedExercise]
        exerciseID|attribute|Swift.Optional<Foundation.UUID>|true|false
        exerciseNameSnapshot|attribute|Swift.String|false|false
        id|attribute|Foundation.UUID|false|true
        notes|attribute|Swift.String|false|false
        restSeconds|attribute|Swift.Int|false|false
        sortOrder|attribute|Swift.Int|false|false
        targetRepetitions|attribute|Swift.Int|false|false
        targetSets|attribute|Swift.Int|false|false
        targetWeight|attribute|Swift.Double|false|false
        [Playlist]
        createdAt|attribute|Foundation.Date|false|false
        id|attribute|Foundation.UUID|false|true
        name|attribute|Swift.String|false|false
        sortOrder|attribute|Swift.Int|false|false
        updatedAt|attribute|Foundation.Date|false|false
        [PlaylistTrack]
        addedAt|attribute|Foundation.Date|false|false
        id|attribute|Foundation.UUID|false|true
        playlistID|attribute|Foundation.UUID|false|false
        sortOrder|attribute|Swift.Int|false|false
        trackID|attribute|Foundation.UUID|false|false
        [WorkoutPlan]
        assignedPlaylistID|attribute|Swift.Optional<Foundation.UUID>|true|false
        createdAt|attribute|Foundation.Date|false|false
        exercises|relationship|PlannedExercise|cascade|false
        id|attribute|Foundation.UUID|false|true
        name|attribute|Swift.String|false|false
        notes|attribute|Swift.String|false|false
        sortOrder|attribute|Swift.Int|false|false
        updatedAt|attribute|Foundation.Date|false|false
        [WorkoutSession]
        completedAt|attribute|Swift.Optional<Foundation.Date>|true|false
        currentExerciseIndex|attribute|Swift.Optional<Swift.Int>|true|false
        currentSetNumber|attribute|Swift.Optional<Swift.Int>|true|false
        exerciseRecords|relationship|ExerciseRecord|cascade|false
        id|attribute|Foundation.UUID|false|true
        notes|attribute|Swift.String|false|false
        planNameSnapshot|attribute|Swift.String|false|false
        playlistID|attribute|Swift.Optional<Foundation.UUID>|true|false
        playlistNameSnapshot|attribute|Swift.Optional<Swift.String>|true|false
        startedAt|attribute|Foundation.Date|false|false
        statusRawValue|attribute|Swift.String|false|false
        workoutPlanID|attribute|Swift.Optional<Foundation.UUID>|true|false
        [WorkoutSetRecord]
        completedAt|attribute|Swift.Optional<Foundation.Date>|true|false
        id|attribute|Foundation.UUID|false|true
        isCompleted|attribute|Swift.Bool|false|false
        isWarmup|attribute|Swift.Bool|false|false
        repetitions|attribute|Swift.Int|false|false
        setNumber|attribute|Swift.Int|false|false
        weight|attribute|Swift.Double|false|false
        """
}
