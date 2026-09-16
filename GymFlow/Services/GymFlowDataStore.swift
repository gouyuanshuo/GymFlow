import SwiftData

enum GymFlowDataStore {
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            WorkoutPlan.self,
            PlannedExercise.self,
            ExerciseDefinition.self,
            WorkoutSession.self,
            ExerciseRecord.self,
            WorkoutSetRecord.self,
            ImportedTrack.self,
            Playlist.self,
            PlaylistTrack.self
        ])
        return try ModelContainer(for: schema)
    }
}
