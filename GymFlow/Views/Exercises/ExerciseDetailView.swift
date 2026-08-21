import SwiftData
import SwiftUI

struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [WorkoutPlan]
    /// Every session, including in-progress ones, because "is this exercise in use?" must consider
    /// them all.
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    /// Performance history only comes from finished workouts, so the store filters those out here
    /// rather than every derived value rescanning the full history.
    @Query(
        filter: WorkoutSession.predicate(status: .completed),
        sort: \WorkoutSession.startedAt,
        order: .reverse
    )
    private var completedSessions: [WorkoutSession]

    let exercise: ExerciseDefinition
    @State private var editorPresented = false
    @State private var deleteConfirmation = false
    @State private var errorMessage: String?

    private var isUsed: Bool {
        ExerciseLibraryService.isUsed(exercise, plans: plans, sessions: sessions)
    }

    /// The most recent sessions in which this exercise was actually trained.
    ///
    /// Only the first few are shown, so the scan stops as soon as enough have been found instead of
    /// walking the user's entire history.
    private var recentPerformance: [ExercisePerformanceItem] {
        let identity = ExerciseIdentity(exercise)
        var items: [ExercisePerformanceItem] = []
        for session in completedSessions {
            guard let record = session.orderedExerciseRecords.first(where: identity.matches),
                  record.orderedSets.contains(where: \.isCompleted) else { continue }
            items.append(ExercisePerformanceItem(session: session, record: record))
            if items.count == Self.recentPerformanceLimit { break }
        }
        return items
    }

    private var bestSummary: ExerciseBestSummary {
        ExercisePerformanceService.summary(for: exercise, sessions: completedSessions)
    }

    private static let recentPerformanceLimit = 8

    var body: some View {
        let summary = bestSummary
        let recentPerformance = recentPerformance
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

            personalBestsSection(summary)
            bestHistorySection(summary)

            Section("Recent Workouts") {
                if recentPerformance.isEmpty {
                    Text("Complete this exercise in a workout to see recent performance.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentPerformance) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.session.startedAt, format: .dateTime.month(.abbreviated).day().year())
                                .font(.headline)
                            Text(item.completedSets.map {
                                GymFlowFormatters.set(weight: $0.weight, repetitions: $0.repetitions)
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
        .errorAlert("Exercise Error", message: $errorMessage)
    }

    @ViewBuilder
    private func personalBestsSection(_ summary: ExerciseBestSummary) -> some View {
        Section("Personal Bests") {
            if summary.isEmpty {
                Text("Complete a working set to establish Personal Bests for this exercise.")
                    .foregroundStyle(.secondary)
            } else {
                if let record = summary.heaviestWeightRecord {
                    PersonalBestRow(
                        title: "Heaviest Weight",
                        value: "\(GymFlowFormatters.weight(record.weight)) kg",
                        detail: record.setDescription,
                        date: record.workoutDate,
                        icon: "scalemass.fill"
                    )
                }

                if let record = summary.estimatedOneRepMaxRecord,
                   let estimated = record.estimatedOneRepMax {
                    PersonalBestRow(
                        title: "Estimated 1RM",
                        value: "\(GymFlowFormatters.weight(estimated)) kg",
                        detail: record.setDescription,
                        date: record.workoutDate,
                        icon: "gauge.with.dots.needle.67percent"
                    )
                }

                if let record = summary.bestSetVolumeRecord {
                    PersonalBestRow(
                        title: "Best Set Volume",
                        value: "\(GymFlowFormatters.weight(record.setVolume)) kg",
                        detail: record.setDescription,
                        date: record.workoutDate,
                        icon: "chart.bar.fill"
                    )
                }

                if let record = summary.bestRepetitionRecord {
                    PersonalBestRow(
                        title: record.weight > 0 ? "Best Reps at Relevant Load" : "Best Repetitions",
                        value: record.setDescription,
                        detail: record.weight > 0 ? "At least half of max load" : "Bodyweight",
                        date: record.workoutDate,
                        icon: "repeat"
                    )
                }
            }
        }
        .accessibilityIdentifier("exercise-personal-bests")
    }

    @ViewBuilder
    private func bestHistorySection(_ summary: ExerciseBestSummary) -> some View {
        if !summary.personalBestEvents.isEmpty {
            Section {
                ForEach(summary.personalBestEvents.prefix(8)) { event in
                    PersonalBestEventRow(event: event)
                }
            } header: {
                Text("Best History")
            } footer: {
                Text("Estimated 1RM uses the Epley formula for completed working sets of 1–15 reps.")
            }
            .accessibilityIdentifier("exercise-best-history")
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

private struct PersonalBestRow: View {
    let title: String
    let value: String
    let detail: String
    let date: Date
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(date, format: .dateTime.day().month(.abbreviated).year())
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct PersonalBestEventRow: View {
    let event: ExercisePREvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(event.record.workoutDate, format: .dateTime.day().month(.abbreviated))
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .frame(width: 54, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.record.setDescription)
                    .font(.headline)
                if let metricDescription = event.metricDescription {
                    Text(metricDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Text(event.typeDescription)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tint)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

private struct ExercisePerformanceItem: Identifiable {
    let session: WorkoutSession
    let record: ExerciseRecord

    var id: UUID { session.id }
    var completedSets: [WorkoutSetRecord] { record.orderedSets.filter(\.isCompleted) }
}
