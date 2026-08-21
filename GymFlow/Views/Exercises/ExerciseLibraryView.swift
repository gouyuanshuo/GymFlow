import SwiftData
import SwiftUI

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseDefinition.name) private var exercises: [ExerciseDefinition]

    @State private var searchText = ""
    @State private var scope: ExerciseLibraryScope = .available
    @State private var muscleFilter = ""
    @State private var equipmentFilter = ""
    @State private var sort = ExerciseLibrarySort.name
    @State private var editorPresented = false
    @State private var errorMessage: String?

    private var filteredExercises: [ExerciseDefinition] {
        exercises
            .filter { $0.isArchived == (scope == .archived) }
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .filter { muscleFilter.isEmpty || $0.muscleGroup == muscleFilter }
            .filter { equipmentFilter.isEmpty || $0.equipment == equipmentFilter }
            .sorted(by: sort.areInIncreasingOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Library scope", selection: $scope) {
                ForEach(ExerciseLibraryScope.allCases) { value in
                    Text(value.title).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if filteredExercises.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: scope == .available ? "figure.strengthtraining.traditional" : "archivebox",
                    description: Text(emptyDescription)
                )
            } else {
                List(filteredExercises) { exercise in
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise)
                    } label: {
                        ExerciseLibraryRow(exercise: exercise)
                    }
                    .accessibilityIdentifier("exercise-library-row")
                    .swipeActions(edge: .trailing) {
                        Button(scope == .archived ? "Restore" : "Archive") {
                            setArchived(scope != .archived, exercise: exercise)
                        }
                        .tint(scope == .archived ? .green : .orange)
                    }
                }
                .listStyle(.plain)
            }
        }
        .accessibilityIdentifier("exercise-library-screen")
        .navigationTitle("Exercise Library")
        .searchable(text: $searchText, prompt: "Exercise name")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                filterMenu
                Button("New Exercise", systemImage: "plus") {
                    editorPresented = true
                }
            }
        }
        .sheet(isPresented: $editorPresented) {
            NavigationStack {
                ExerciseEditorView(definition: nil)
            }
            .interactiveDismissDisabled()
        }
        .errorAlert("Exercise Library Error", message: $errorMessage)
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
            Picker("Sort", selection: $sort) {
                ForEach(ExerciseLibrarySort.allCases) { value in
                    Text(value.title).tag(value)
                }
            }
            if !muscleFilter.isEmpty || !equipmentFilter.isEmpty {
                Button("Clear Filters", systemImage: "line.3.horizontal.decrease.circle") {
                    muscleFilter = ""
                    equipmentFilter = ""
                }
            }
        } label: {
            Label("Filter and Sort", systemImage: hasActiveFilter
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
        }
    }

    private var muscleOptions: [String] {
        Array(Set(ExerciseTaxonomy.muscleGroups + exercises.map(\.muscleGroup))).sorted()
    }

    private var equipmentOptions: [String] {
        Array(Set(ExerciseTaxonomy.equipment + exercises.map(\.equipment))).sorted()
    }

    private var hasActiveFilter: Bool {
        !muscleFilter.isEmpty || !equipmentFilter.isEmpty
    }

    private var emptyTitle: String {
        if !searchText.isEmpty || hasActiveFilter { return "No Matches" }
        return scope == .available ? "No Exercises" : "No Archived Exercises"
    }

    private var emptyDescription: String {
        if !searchText.isEmpty || hasActiveFilter {
            return "Try another name or clear the filters."
        }
        return scope == .available
            ? "Create a custom exercise to start your library."
            : "Archived exercises will appear here and can be restored."
    }

    private func setArchived(_ isArchived: Bool, exercise: ExerciseDefinition) {
        ExerciseLibraryService.setArchived(isArchived, for: exercise)
        do {
            try modelContext.save()
        } catch {
            errorMessage = "The exercise could not be updated. \(error.localizedDescription)"
        }
    }
}

struct ExerciseLibraryRow: View {
    let exercise: ExerciseDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(exercise.name)
                    .font(.headline)
                Spacer()
                Text(exercise.isCustom ? "Custom" : "Built-in")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text("\(exercise.muscleGroup) • \(exercise.equipment)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if exercise.isArchived {
                Label("Archived", systemImage: "archivebox")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private enum ExerciseLibraryScope: String, CaseIterable, Identifiable {
    case available
    case archived

    var id: String { rawValue }
    var title: String { self == .available ? "Available" : "Archived" }
}

private enum ExerciseLibrarySort: String, CaseIterable, Identifiable {
    case name
    case muscleGroup
    case equipment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: "Name"
        case .muscleGroup: "Muscle Group"
        case .equipment: "Equipment"
        }
    }

    func areInIncreasingOrder(_ lhs: ExerciseDefinition, _ rhs: ExerciseDefinition) -> Bool {
        let comparison: ComparisonResult
        switch self {
        case .name:
            comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        case .muscleGroup:
            comparison = lhs.muscleGroup.localizedCaseInsensitiveCompare(rhs.muscleGroup)
        case .equipment:
            comparison = lhs.equipment.localizedCaseInsensitiveCompare(rhs.equipment)
        }
        if comparison == .orderedSame {
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return comparison == .orderedAscending
    }
}

#Preview { GymFlowPreview { NavigationStack { ExerciseLibraryView() } } }
