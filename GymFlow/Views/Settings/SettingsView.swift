import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @AppStorage(PreferenceKey.defaultRestDuration) private var defaultRestDuration = 90
    @AppStorage(PreferenceKey.timerSoundEnabled) private var timerSoundEnabled = true
    @AppStorage(PreferenceKey.hapticFeedbackEnabled) private var hapticFeedbackEnabled = true
    @AppStorage(PreferenceKey.automaticallyPlayAssignedPlaylist)
    private var automaticallyPlayAssignedPlaylist = false
    @State private var pendingAction: DestructiveDataAction?
    @State private var outcome: SettingsOutcome?
    var showsDoneButton = true

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Defaults") {
                    LabeledContent("Weight unit", value: "Kilograms (kg)")
                    Stepper(
                        "Default rest: \(defaultRestDuration) seconds",
                        value: $defaultRestDuration,
                        in: 0...900,
                        step: 15
                    )
                    Toggle(
                        "Automatically play assigned playlist",
                        isOn: $automaticallyPlayAssignedPlaylist
                    )
                }

                Section("Rest Timer Alert") {
                    Toggle("Sound", isOn: $timerSoundEnabled)
                    Toggle("Haptic", isOn: $hapticFeedbackEnabled)
                }

                Section("Exercises") {
                    NavigationLink {
                        ExerciseLibraryView()
                    } label: {
                        Label(
                            "Exercise Library",
                            systemImage: "figure.strengthtraining.traditional"
                        )
                    }
                }

                Section("Appearance") {
                    LabeledContent("Theme", value: "Follow System")
                }

                Section("Data") {
                    ForEach(DestructiveDataAction.allCases) { action in
                        Button(action.title, systemImage: action.icon, role: action.buttonRole) {
                            pendingAction = action
                        }
                    }
                }

                Section("About") {
                    LabeledContent("GymFlow version", value: version)
                    LabeledContent("Storage", value: "On this device")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsDoneButton { Button("Done") { dismiss() } }
            }
            // One dialog driven by the pending action, rather than a separate flag and a separate
            // near-identical dialog per destructive button.
            .confirmationDialog(
                pendingAction?.confirmationTitle ?? "",
                isPresented: $pendingAction.isPresent(),
                titleVisibility: .visible,
                presenting: pendingAction
            ) { action in
                Button(action.confirmButtonTitle, role: .destructive) { perform(action) }
                Button("Cancel", role: .cancel) { }
            } message: { action in
                Text(action.consequences)
            }
            .alert(
                outcome?.title ?? "",
                isPresented: $outcome.isPresent(),
                presenting: outcome
            ) { _ in
                Button("OK", role: .cancel) { }
            } message: { outcome in
                Text(outcome.detail)
            }
        }
    }

    private func perform(_ action: DestructiveDataAction) {
        pendingAction = nil
        do {
            switch action {
            case .resetSamples: try resetSamples()
            case .deleteWorkoutData: try deleteWorkoutData()
            case .deleteImportedAudio: try deleteAllAudio()
            }
            outcome = SettingsOutcome(title: action.successTitle, detail: action.successDetail)
        } catch {
            outcome = SettingsOutcome(
                title: action.failureTitle,
                detail: error.localizedDescription
            )
        }
    }

    private func resetSamples() throws {
        try deleteAll(WorkoutPlan.self)
        try deleteAll(ExerciseDefinition.self)
        UserDefaults.standard.set(false, forKey: SampleDataSeeder.seedingKey)
        try modelContext.save()
        try SampleDataSeeder.seedIfNeeded(context: modelContext)
    }

    private func deleteWorkoutData() throws {
        LiveActivityManager.shared.endAll()
        for session in try fetchAll(WorkoutSession.self) {
            RestTimerService.clearPersistedState(
                keyPrefix: RestTimerStorage.keyPrefix(for: session.id)
            )
            RestTimerNotificationScheduler.shared.cancel(
                identifier: RestTimerNotificationScheduler.identifier(for: session.id)
            )
            modelContext.delete(session)
        }
        RestTimerService.clearPersistedState(keyPrefix: RestTimerStorage.legacyKeyPrefix)
        UserDefaults.standard.set("", forKey: PreferenceKey.activeWorkoutSessionID)
        try deleteAll(WorkoutPlan.self)
        try deleteAll(ExerciseDefinition.self)
        try modelContext.save()
    }

    private func deleteAllAudio() throws {
        let store = try AudioFileStore()
        audioPlayer.clearQueue()
        try deleteAll(PlaylistTrack.self)
        for track in try fetchAll(ImportedTrack.self) {
            try store.delete(storedFileName: track.storedFileName)
            modelContext.delete(track)
        }
        try modelContext.save()
    }

    /// Fetches a whole table on demand.
    ///
    /// Settings displays none of this data — it only deletes it — so the rows are fetched inside the
    /// action rather than held in a `@Query`, which would re-read every table each time the screen
    /// appears or the store changes.
    private func fetchAll<Model: PersistentModel>(_ type: Model.Type) throws -> [Model] {
        try modelContext.fetch(FetchDescriptor<Model>())
    }

    private func deleteAll<Model: PersistentModel>(_ type: Model.Type) throws {
        try fetchAll(type).forEach(modelContext.delete)
    }
}

/// A data-destroying action offered in Settings, with the wording of its confirmation.
///
/// Each case carries its own copy so the three buttons share one dialog and one handler instead of
/// three parallel flags and three near-identical `confirmationDialog` blocks.
private enum DestructiveDataAction: String, CaseIterable, Identifiable {
    case resetSamples
    case deleteWorkoutData
    case deleteImportedAudio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .resetSamples: "Reset Sample Plans"
        case .deleteWorkoutData: "Delete All Workout Data"
        case .deleteImportedAudio: "Delete All Imported Audio"
        }
    }

    var icon: String {
        switch self {
        case .resetSamples: "arrow.counterclockwise"
        case .deleteWorkoutData, .deleteImportedAudio: "trash"
        }
    }

    /// Resetting samples restores data rather than removing it, so it is not styled as destructive.
    var buttonRole: ButtonRole? {
        self == .resetSamples ? nil : .destructive
    }

    var confirmationTitle: String {
        switch self {
        case .resetSamples: "Reset sample plans?"
        case .deleteWorkoutData: "Permanently delete all workout data?"
        case .deleteImportedAudio: "Permanently delete imported audio?"
        }
    }

    var confirmButtonTitle: String {
        switch self {
        case .resetSamples: "Delete Plans and Restore Samples"
        case .deleteWorkoutData: "Delete Plans, Exercises, and History"
        case .deleteImportedAudio: "Delete All Audio"
        }
    }

    var consequences: String {
        switch self {
        case .resetSamples:
            "Your plans and exercise library will be replaced. Workout history and imported audio will remain."
        case .deleteWorkoutData:
            "This includes active workouts and completed history. This action cannot be undone."
        case .deleteImportedAudio:
            "All GymFlow audio records and copied files will be removed. This action cannot be undone."
        }
    }

    var successTitle: String {
        switch self {
        case .resetSamples: "Samples Restored"
        case .deleteWorkoutData: "Workout Data Deleted"
        case .deleteImportedAudio: "Imported Audio Deleted"
        }
    }

    var successDetail: String {
        switch self {
        case .resetSamples: "The sample workout plans and exercise library are ready."
        case .deleteWorkoutData: "Plans, exercises, active workouts, and history were removed."
        case .deleteImportedAudio: "All copied audio files were removed."
        }
    }

    var failureTitle: String {
        self == .resetSamples ? "Reset Failed" : "Delete Failed"
    }
}

/// The result of a Settings action, reported back to the user in an alert.
private struct SettingsOutcome {
    let title: String
    let detail: String
}
