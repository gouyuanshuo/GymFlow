import SwiftUI

struct WorkoutHistoryDetailView: View {
    let session: WorkoutSession

    var body: some View {
        List {
            Section {
                LabeledContent("Started", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
                if let completedAt = session.completedAt {
                    LabeledContent("Completed", value: completedAt.formatted(date: .omitted, time: .shortened))
                }
                LabeledContent("Duration", value: GymFlowFormatters.duration(session.duration))
                LabeledContent("Total volume", value: "\(GymFlowFormatters.weight(session.trainingVolume)) kg")
                LabeledContent("Total repetitions", value: "\(session.totalRepetitions)")
                if !session.notes.isEmpty { Text(session.notes) }
            } header: { Text("Summary") }

            ForEach(session.orderedExerciseRecords) { exercise in
                Section {
                    ForEach(exercise.orderedSets.filter(\.isCompleted)) { set in
                        HStack {
                            Text(set.isWarmup ? "Warm-up" : "Set \(set.setNumber)")
                            Spacer()
                            Text("\(GymFlowFormatters.weight(set.weight)) kg × \(set.repetitions)")
                                .monospacedDigit()
                        }
                    }
                    if exercise.orderedSets.filter(\.isCompleted).isEmpty {
                        Text("No completed sets").foregroundStyle(.secondary)
                    }
                    NavigationLink("View Exercise Progress") {
                        ExerciseProgressView(exerciseName: exercise.exerciseNameSnapshot)
                    }
                } header: {
                    Text(exercise.exerciseNameSnapshot)
                } footer: {
                    if !exercise.notes.isEmpty { Text(exercise.notes) }
                }
            }
        }
        .navigationTitle(session.planNameSnapshot)
        .navigationBarTitleDisplayMode(.inline)
    }
}
