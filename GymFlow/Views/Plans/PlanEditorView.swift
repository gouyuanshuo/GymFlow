import SwiftData
import SwiftUI

struct PlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutPlan.sortOrder) private var plans: [WorkoutPlan]
    @Query(sort: \Playlist.sortOrder) private var playlists: [Playlist]
    @Query(sort: \ExerciseDefinition.name) private var definitions: [ExerciseDefinition]
    @AppStorage("defaultRestDuration") private var defaultRestDuration = 90
    let plan: WorkoutPlan?
    @State private var draft: PlanDraft
    @State private var exercisePickerPresented = false
    @State private var errorMessage: String?

    init(plan: WorkoutPlan?) {
        self.plan = plan
        _draft = State(initialValue: PlanDraft(plan: plan))
    }

    var body: some View {
        Form {
            Section("Plan") {
                TextField("Plan name", text: $draft.name)
                    .textInputAutocapitalization(.words)
                    .accessibilityLabel("Plan name")
                TextField("Notes (optional)", text: $draft.notes, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section("Workout Music") {
                Picker("Assigned playlist", selection: $draft.assignedPlaylistID) {
                    Text("None").tag(nil as UUID?)
                    ForEach(playlists) { playlist in
                        Text(playlist.name).tag(Optional(playlist.id))
                    }
                }
                if playlists.isEmpty {
                    Text("Create a playlist in Music to assign it to this workout.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                if draft.exercises.isEmpty {
                    Text("Add at least one exercise when you are ready.")
                        .foregroundStyle(.secondary)
                }
                ForEach($draft.exercises) { $exercise in
                    NavigationLink {
                        PlannedExerciseEditor(
                            draft: $exercise,
                            exerciseName: resolvedName(for: exercise)
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(resolvedName(for: exercise)).font(.headline)
                            Text("\(exercise.targetSets) × \(exercise.targetRepetitions) • \(GymFlowFormatters.weight(exercise.targetWeight)) kg • \(exercise.restSeconds)s rest")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { draft.exercises.remove(atOffsets: $0) }
                .onMove { draft.exercises.move(fromOffsets: $0, toOffset: $1) }

                Button("Add Exercise", systemImage: "plus.circle.fill") {
                    exercisePickerPresented = true
                }
            } header: {
                HStack {
                    Text("Exercises")
                    Spacer()
                    EditButton()
                }
            }
        }
        .navigationTitle(plan == nil ? "New Plan" : "Edit Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }.fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $exercisePickerPresented) {
            ExercisePickerView { definition in
                draft.exercises.append(PlannedExerciseDraft(
                    definition: definition,
                    restSeconds: defaultRestDuration
                ))
            }
        }
        .alert("Can’t Save Plan", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: { Text(errorMessage ?? "Unknown error") }
    }

    private func save() {
        do {
            try InputValidator.validatePlanName(draft.name)
            for exercise in draft.exercises {
                try InputValidator.validateExerciseName(exercise.name)
                try InputValidator.validate(
                    sets: exercise.targetSets,
                    repetitions: exercise.targetRepetitions,
                    weight: exercise.targetWeight,
                    restSeconds: exercise.restSeconds
                )
            }

            let savedExercises = draft.exercises.enumerated().map { index, exercise in
                PlannedExercise(
                    exerciseID: exercise.exerciseID,
                    exerciseNameSnapshot: resolvedName(for: exercise),
                    targetSets: exercise.targetSets,
                    targetRepetitions: exercise.targetRepetitions,
                    targetWeight: exercise.targetWeight,
                    restSeconds: exercise.restSeconds,
                    notes: exercise.notes,
                    sortOrder: index
                )
            }

            if let plan {
                let obsolete = plan.exercises
                plan.exercises = savedExercises
                obsolete.forEach(modelContext.delete)
                plan.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                plan.notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                plan.assignedPlaylistID = draft.assignedPlaylistID
                plan.updatedAt = Date()
            } else {
                let nextOrder = (plans.map(\.sortOrder).max() ?? -1) + 1
                modelContext.insert(WorkoutPlan(
                    name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    sortOrder: nextOrder,
                    assignedPlaylistID: draft.assignedPlaylistID,
                    exercises: savedExercises
                ))
            }
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolvedName(for exercise: PlannedExerciseDraft) -> String {
        guard let exerciseID = exercise.exerciseID,
              let definition = definitions.first(where: { $0.id == exerciseID }) else {
            return exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return definition.name
    }
}

private struct PlannedExerciseEditor: View {
    @Binding var draft: PlannedExerciseDraft
    let exerciseName: String

    var body: some View {
        Form {
            Section("Exercise") {
                Text(exerciseName).font(.headline)
                TextField("Exercise notes", text: $draft.notes, axis: .vertical)
                    .lineLimit(2...5)
            }
            Section("Targets") {
                Stepper("Sets: \(draft.targetSets)", value: $draft.targetSets, in: 1...20)
                Stepper("Repetitions: \(draft.targetRepetitions)", value: $draft.targetRepetitions, in: 0...100)
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("kg", value: $draft.targetWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Text("kg").foregroundStyle(.secondary)
                }
                Stepper("Rest: \(draft.restSeconds) seconds", value: $draft.restSeconds, in: 0...900, step: 15)
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: draft.targetWeight) { _, value in
            if value < 0 { draft.targetWeight = 0 }
        }
    }
}
