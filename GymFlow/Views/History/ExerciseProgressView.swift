import SwiftData
import SwiftUI

struct ExerciseProgressView: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    let exerciseName: String

    private var history: [(session: WorkoutSession, record: ExerciseRecord)] {
        sessions.compactMap { session in
            guard session.status == .completed,
                  let record = session.orderedExerciseRecords.first(where: {
                      $0.exerciseNameSnapshot == exerciseName && $0.orderedSets.contains(where: \.isCompleted)
                  }) else { return nil }
            return (session, record)
        }
    }

    private var bestWeight: Double {
        history.flatMap { $0.record.orderedSets }.filter(\.isCompleted).map(\.weight).max() ?? 0
    }

    var body: some View {
        List {
            Section("Best Completed Weight") {
                Text("\(GymFlowFormatters.weight(bestWeight)) kg")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.tint)
            }
            Section("Recent Sets") {
                if history.isEmpty {
                    Text("Complete this exercise in a workout to see progress.")
                        .foregroundStyle(.secondary)
                }
                ForEach(history.prefix(20), id: \.session.id) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.session.startedAt, format: .dateTime.month(.abbreviated).day().year())
                            .font(.headline)
                        Text(item.record.orderedSets.filter(\.isCompleted).map {
                            "\(GymFlowFormatters.weight($0.weight)) kg × \($0.repetitions)"
                        }.joined(separator: "  •  "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
