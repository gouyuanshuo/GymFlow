import SwiftData
import SwiftUI

struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [WorkoutPlan]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    let exercise: ExerciseDefinition
    @State private var editorPresented = false
    @State private var deleteConfirmation = false
    @State private var errorMessage: String?

    private var isUsed: Bool {
        ExerciseLibraryService.isUsed(exercise, plans: plans, sessions: sessions)
    }

    private var recentPerformance: [ExercisePerformanceItem] {
        sessions.compactMap { session in
            guard session.status == .completed,
                  let record = session.orderedExerciseRecords.first(where: { record in
                      record.exerciseID == exercise.id
                          || (record.exerciseID == nil
                              && ExerciseLibraryService.normalizedName(record.exerciseNameSnapshot)
                                == ExerciseLibraryService.normalizedName(exercise.name))
                  }),
                  record.orderedSets.contains(where: \.isCompleted) else { return nil }
            return ExercisePerformanceItem(session: session, record: record)
        }
    }

    var body: some View {
        List {
            Section("Exercise") {
                LabeledContent("Primary muscle", value: exercise.muscleGroup)
                if !exercise.secondaryMuscleGroups.isEmpty {
                    LabeledContent(
                        "Secondary muscles",
                        value: exercise.secondaryMuscleGroups.joined(separator: ", ")
                    )
                }
                LabeledContent("Equipment", value: exercise.equipment)
                LabeledContent("Type", value: exercise.isCustom ? "Custom" : "Built-in")
                if exercise.isArchived {
                    Label("Archived", systemImage: "archivebox")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Plan Defaults") {
                LabeledContent("Sets", value: optionalValue(exercise.defaultSets))
                LabeledContent("Repetitions", value: optionalValue(exercise.defaultRepetitions))
                LabeledContent("Rest", value: exercise.defaultRestSeconds.map { "\($0) seconds" } ?? "Not set")
            }

            if !exercise.notes.isEmpty {
                Section("Notes") {
                    Text(exercise.notes)
                }
            }

            Section("Recent Workouts") {
                if recentPerformance.isEmpty {
                    Text("Complete this exercise in a workout to see recent performance.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentPerformance.prefix(8)) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.session.startedAt, format: .dateTime.month(.abbreviated).day().year())
                                .font(.headline)
                            Text(item.completedSets.map {
                                "\(GymFlowFormatters.weight($0.weight)) kg × \($0.repetitions)"
                            }.joined(separator: "  •  "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("Library Actions") {
                Button(exercise.isArchived ? "Restore Exercise" : "Archive Exercise",
                       systemImage: exercise.isArchived ? "arrow.uturn.backward" : "archivebox") {
                    setArchived(!exercise.isArchived)
                }

                if !exercise.isCustom {
                    Text("Built-in exercises can be archived but are kept in the library so the default collection remains available.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if isUsed {
                    Text("This exercise is used by a workout plan or history. Archive it to hide it from new plan selection while preserving existing data.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Delete Exercise", systemImage: "trash", role: .destructive) {
                        deleteConfirmation = true
                    }
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit", systemImage: "pencil") {
                editorPresented = true
            }
        }
        .sheet(isPresented: $editorPresented) {
            NavigationStack {
                ExerciseEditorView(definition: exercise)
            }
            .interactiveDismissDisabled()
        }
        .confirmationDialog(
            "Delete \(exercise.name)?",
            isPresented: $deleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Exercise", role: .destructive) { deleteExercise() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This unused exercise will be permanently removed. This action cannot be undone.")
        }
        .alert("Exercise Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    private func optionalValue(_ value: Int?) -> String {
        value.map(String.init) ?? "Not set"
    }

    private func setArchived(_ isArchived: Bool) {
        ExerciseLibraryService.setArchived(isArchived, for: exercise)
        saveOrReport("The archive state could not be saved.")
    }

    private func deleteExercise() {
        guard !ExerciseLibraryService.isUsed(exercise, plans: plans, sessions: sessions) else {
            errorMessage = "This exercise is now in use. Archive it instead."
            return
        }
        modelContext.delete(exercise)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "The exercise could not be deleted. \(error.localizedDescription)"
        }
    }

    private func saveOrReport(_ prefix: String) {
        do {
            try modelContext.save()
        } catch {
            errorMessage = "\(prefix) \(error.localizedDescription)"
        }
    }
}

private struct ExercisePerformanceItem: Identifiable {
    let session: WorkoutSession
    let record: ExerciseRecord

    var id: UUID { session.id }
    var completedSets: [WorkoutSetRecord] { record.orderedSets.filter(\.isCompleted) }
}
