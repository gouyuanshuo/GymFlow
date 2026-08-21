import SwiftUI

struct CalendarDayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let day: Date
    let sessions: [WorkoutSession]

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No Workout Recorded",
                    systemImage: "calendar",
                    description: Text("There is no completed workout on this date.")
                )
            } else {
                List {
                    ForEach(sessions) { session in
                        Section {
                            LabeledContent("Duration", value: GymFlowFormatters.duration(session.duration))
                            LabeledContent(
                                "Volume",
                                value: "\(GymFlowFormatters.weight(session.trainingVolume)) kg"
                            )

                            ForEach(session.orderedExerciseRecords) { exercise in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(exercise.exerciseNameSnapshot)
                                        .font(.headline)
                                    let completedSets = exercise.orderedSets.filter(\.isCompleted)
                                    if completedSets.isEmpty {
                                        Text("No completed sets")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text(completedSets.map {
                                            GymFlowFormatters.set(weight: $0.weight, repetitions: $0.repetitions)
                                        }.joined(separator: "  •  "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }

                            NavigationLink("Open Workout Details") {
                                WorkoutHistoryDetailView(session: session)
                            }
                        } header: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.planNameSnapshot)
                                Text(session.startedAt, format: .dateTime.hour().minute())
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(day.formatted(.dateTime.day().month(.wide).year()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}
