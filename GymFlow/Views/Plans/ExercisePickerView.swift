import SwiftData
import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExerciseDefinition.name) private var exercises: [ExerciseDefinition]
    let onSelect: (ExerciseDefinition) -> Void
    @State private var searchText = ""
    @State private var muscleFilter = ""
    @State private var equipmentFilter = ""
    @State private var customPresented = false
    @State private var createdExercise: ExerciseDefinition?

    private var filtered: [ExerciseDefinition] {
        exercises
            .filter { !$0.isArchived }
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .filter { muscleFilter.isEmpty || $0.muscleGroup == muscleFilter }
            .filter { equipmentFilter.isEmpty || $0.equipment == equipmentFilter }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Try another name or filter, or create a custom exercise.")
                    )
                } else {
                    List(filtered) { exercise in
                        Button {
                            onSelect(exercise)
                            dismiss()
                        } label: {
                            ExerciseLibraryRow(exercise: exercise)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Exercise name")
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    filterMenu
                    Button("New Exercise", systemImage: "plus") { customPresented = true }
                }
            }
            .sheet(isPresented: $customPresented, onDismiss: selectCreatedExercise) {
                NavigationStack {
                    ExerciseEditorView(definition: nil) { definition in
                        createdExercise = definition
                    }
                }
                .interactiveDismissDisabled()
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Muscle Group", selection: $muscleFilter) {
                Text("All Muscle Groups").tag("")
                ForEach(muscleOptions, id: \.self) { value in
                    Text(value).tag(value)
                }
            }
            Picker("Equipment", selection: $equipmentFilter) {
                Text("All Equipment").tag("")
                ForEach(equipmentOptions, id: \.self) { value in
                    Text(value).tag(value)
                }
            }
            if !muscleFilter.isEmpty || !equipmentFilter.isEmpty {
                Button("Clear Filters") {
                    muscleFilter = ""
                    equipmentFilter = ""
                }
            }
        } label: {
            Label(
                "Filter",
                systemImage: muscleFilter.isEmpty && equipmentFilter.isEmpty
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
    }

    private var muscleOptions: [String] {
        Array(Set(ExerciseTaxonomy.muscleGroups + exercises.map(\.muscleGroup))).sorted()
    }

    private var equipmentOptions: [String] {
        Array(Set(ExerciseTaxonomy.equipment + exercises.map(\.equipment))).sorted()
    }

    private func selectCreatedExercise() {
        guard let createdExercise else { return }
        self.createdExercise = nil
        onSelect(createdExercise)
        dismiss()
    }
}
