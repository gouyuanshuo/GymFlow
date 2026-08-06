#if DEBUG
import SwiftData
import SwiftUI

@MainActor
struct GymFlowPreview<Content: View>: View {
    private let content: Content
    private let container: ModelContainer?
    @StateObject private var audioPlayer = AudioPlayerService()

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        self.container = PreviewData.makeContainer()
    }

    var body: some View {
        if let container {
            content
                .modelContainer(container)
                .environmentObject(audioPlayer)
        } else {
            ContentUnavailableView(
                "Preview Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("The in-memory model container could not be created.")
            )
        }
    }
}

@MainActor
private enum PreviewData {
    static func makeContainer() -> ModelContainer? {
        let schema = Schema([
            WorkoutPlan.self,
            PlannedExercise.self,
            ExerciseDefinition.self,
            WorkoutSession.self,
            ExerciseRecord.self,
            WorkoutSetRecord.self,
            ImportedTrack.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = container.mainContext
            if let plan = SampleDataSeeder.samplePlans().first {
                context.insert(plan)
                let session = WorkoutService.makeSession(from: plan, now: Date().addingTimeInterval(-3_600))
                session.status = .completed
                session.completedAt = Date().addingTimeInterval(-1_800)
                session.orderedExerciseRecords.first?.orderedSets.first?.isCompleted = true
                context.insert(session)
            }
            context.insert(ImportedTrack(
                title: "Workout Mix",
                artist: "Local Artist",
                storedFileName: "preview.mp3",
                originalFileName: "preview.mp3",
                fileExtension: "mp3",
                duration: 215,
                sortOrder: 0
            ))
            try context.save()
            return container
        } catch {
            return nil
        }
    }
}
#endif
