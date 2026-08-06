import SwiftData
import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExerciseDefinition.name) private var exercises: [ExerciseDefinition]
    let onSelect: (ExerciseDefinition) -> Void
    @State private var searchText = ""
    @State private var customPresented = false

    private var filtered: [ExerciseDefinition] {
        guard !searchText.isEmpty else { return exercises }
        return exercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.muscleGroup.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { exercise in
                Button {
                    onSelect(exercise)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.name).foregroundStyle(.primary)
                        Text("\(exercise.muscleGroup) • \(exercise.equipment)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Exercise or muscle group")
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Custom", systemImage: "plus") { customPresented = true }
                }
            }
            .sheet(isPresented: $customPresented) {
                CustomExerciseView { definition in
                    onSelect(definition)
                    dismiss()
                }
            }
        }
    }
}

private struct CustomExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let onCreate: (ExerciseDefinition) -> Void
    @State private var name = ""
    @State private var muscleGroup = "Other"
    @State private var equipment = "Other"
    @State private var notes = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Exercise name", text: $name)
                TextField("Muscle group", text: $muscleGroup)
                TextField("Equipment", text: $equipment)
                TextField("Notes", text: $notes, axis: .vertical)
            }
            .navigationTitle("Custom Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Create") { create() } }
            }
            .alert("Can’t Create Exercise", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("OK", role: .cancel) { } } message: { Text(errorMessage ?? "Unknown error") }
        }
    }

    private func create() {
        do {
            try InputValidator.validateExerciseName(name)
            let definition = ExerciseDefinition(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                muscleGroup: muscleGroup.trimmingCharacters(in: .whitespacesAndNewlines),
                equipment: equipment.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                isCustom: true
            )
            modelContext.insert(definition)
            try modelContext.save()
            onCreate(definition)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
