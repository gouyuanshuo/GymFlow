import SwiftData
import SwiftUI

struct ExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseDefinition.name) private var definitions: [ExerciseDefinition]
    @Query private var plans: [WorkoutPlan]

    let definition: ExerciseDefinition?
    let onSave: ((ExerciseDefinition) -> Void)?

    @State private var name: String
    @State private var muscleGroup: String
    @State private var secondaryMuscleGroups: Set<String>
    @State private var equipment: String
    @State private var usesDefaultSets: Bool
    @State private var defaultSets: Int
    @State private var usesDefaultRepetitions: Bool
    @State private var defaultRepetitions: Int
    @State private var usesDefaultRest: Bool
    @State private var defaultRestSeconds: Int
    @State private var notes: String
    @State private var errorMessage: String?

    init(
        definition: ExerciseDefinition?,
        onSave: ((ExerciseDefinition) -> Void)? = nil
    ) {
        self.definition = definition
        self.onSave = onSave
        _name = State(initialValue: definition?.name ?? "")
        _muscleGroup = State(initialValue: definition?.muscleGroup ?? "Other")
        _secondaryMuscleGroups = State(initialValue: Set(definition?.secondaryMuscleGroups ?? []))
        _equipment = State(initialValue: definition?.equipment ?? "Other")
        _usesDefaultSets = State(initialValue: definition?.defaultSets != nil)
        _defaultSets = State(initialValue: definition?.defaultSets ?? 3)
        _usesDefaultRepetitions = State(initialValue: definition?.defaultRepetitions != nil)
        _defaultRepetitions = State(initialValue: definition?.defaultRepetitions ?? 10)
        _usesDefaultRest = State(initialValue: definition?.defaultRestSeconds != nil)
        _defaultRestSeconds = State(initialValue: definition?.defaultRestSeconds ?? 90)
        _notes = State(initialValue: definition?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("Exercise") {
                TextField("Exercise name", text: $name)
                    .textInputAutocapitalization(.words)
                    .accessibilityLabel("Exercise name")

                Picker("Primary muscle", selection: $muscleGroup) {
                    ForEach(primaryMuscleOptions, id: \.self) { value in
                        Text(value).tag(value)
                    }
                }

                NavigationLink {
                    SecondaryMuscleSelectionView(
                        selection: $secondaryMuscleGroups,
                        primaryMuscle: muscleGroup
                    )
                } label: {
                    LabeledContent("Secondary muscles", value: secondaryMuscleSummary)
                }

                Picker("Equipment", selection: $equipment) {
                    ForEach(equipmentOptions, id: \.self) { value in
                        Text(value).tag(value)
                    }
                }
            }

            Section("Plan Defaults") {
                Toggle("Default sets", isOn: $usesDefaultSets)
                if usesDefaultSets {
                    Stepper("Sets: \(defaultSets)", value: $defaultSets, in: 1...20)
                }

                Toggle("Default repetitions", isOn: $usesDefaultRepetitions)
                if usesDefaultRepetitions {
                    Stepper(
                        "Repetitions: \(defaultRepetitions)",
                        value: $defaultRepetitions,
                        in: 0...100
                    )
                }

                Toggle("Default rest", isOn: $usesDefaultRest)
                if usesDefaultRest {
                    Stepper(
                        "Rest: \(defaultRestSeconds) seconds",
                        value: $defaultRestSeconds,
                        in: 0...900,
                        step: 15
                    )
                }

                Text("These values prefill new plan entries and can always be overridden per plan.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Notes") {
                TextField("Technique cues or setup notes", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
        .navigationTitle(definition == nil ? "New Exercise" : "Edit Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
            }
        }
        .onChange(of: muscleGroup) { _, newValue in
            secondaryMuscleGroups.remove(newValue)
        }
        .alert("Can’t Save Exercise", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    private var primaryMuscleOptions: [String] {
        options(including: muscleGroup, standard: ExerciseTaxonomy.muscleGroups)
    }

    private var equipmentOptions: [String] {
        options(including: equipment, standard: ExerciseTaxonomy.equipment)
    }

    private var secondaryMuscleSummary: String {
        let values = secondaryMuscleGroups.sorted()
        return values.isEmpty ? "None" : values.joined(separator: ", ")
    }

    private func options(including value: String, standard: [String]) -> [String] {
        standard.contains(value) ? standard : [value] + standard
    }

    private func save() {
        let input = ExerciseDefinitionInput(
            name: name,
            muscleGroup: muscleGroup,
            secondaryMuscleGroups: secondaryMuscleGroups.sorted(),
            equipment: equipment,
            defaultRestSeconds: usesDefaultRest ? defaultRestSeconds : nil,
            defaultSets: usesDefaultSets ? defaultSets : nil,
            defaultRepetitions: usesDefaultRepetitions ? defaultRepetitions : nil,
            notes: notes
        )

        do {
            let savedDefinition: ExerciseDefinition
            if let definition {
                try ExerciseLibraryService.update(
                    definition,
                    input: input,
                    existingDefinitions: definitions,
                    plans: plans
                )
                savedDefinition = definition
            } else {
                let created = try ExerciseLibraryService.create(
                    input: input,
                    existingDefinitions: definitions
                )
                modelContext.insert(created)
                savedDefinition = created
            }
            try modelContext.save()
            onSave?(savedDefinition)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SecondaryMuscleSelectionView: View {
    @Binding var selection: Set<String>
    let primaryMuscle: String

    var body: some View {
        List {
            ForEach(muscleOptions, id: \.self) { muscle in
                Button {
                    if selection.contains(muscle) {
                        selection.remove(muscle)
                    } else {
                        selection.insert(muscle)
                    }
                } label: {
                    HStack {
                        Text(muscle)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selection.contains(muscle) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .accessibilityValue(selection.contains(muscle) ? "Selected" : "Not selected")
            }
        }
        .navigationTitle("Secondary Muscles")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var muscleOptions: [String] {
        Array(Set(ExerciseTaxonomy.muscleGroups + Array(selection)))
            .filter { $0 != primaryMuscle }
            .sorted()
    }
}
