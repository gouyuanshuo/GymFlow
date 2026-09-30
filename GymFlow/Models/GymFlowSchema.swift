import SwiftData

/// The first explicit version of GymFlow's persisted SwiftData model.
///
/// Do not change this registered shape in place. Before changing a persisted model, preserve the
/// preceding schema, add the next `VersionedSchema`, declare its migration stage below, and extend
/// the on-disk migration fixture.
enum GymFlowSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            WorkoutPlan.self,
            PlannedExercise.self,
            ExerciseDefinition.self,
            WorkoutSession.self,
            ExerciseRecord.self,
            WorkoutSetRecord.self,
            ImportedTrack.self,
            Playlist.self,
            PlaylistTrack.self,
        ]
    }
}

/// Every supported store version and the explicit transitions between them.
///
/// V1 adopts the existing implicit 1.0.0 schema without changing its shape, so it needs no stage.
/// A future V2 must add either a lightweight or custom V1-to-V2 stage; container failures are
/// surfaced to the app and must never trigger a store deletion fallback.
enum GymFlowMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [GymFlowSchemaV1.self]
    }

    static var stages: [MigrationStage] { [] }
}
