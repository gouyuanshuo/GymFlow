import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @Query private var plans: [WorkoutPlan]
    @Query private var definitions: [ExerciseDefinition]
    @Query private var sessions: [WorkoutSession]
    @Query private var tracks: [ImportedTrack]
    @Query private var memberships: [PlaylistTrack]
    @AppStorage("defaultRestDuration") private var defaultRestDuration = 90
    @AppStorage("timerSoundEnabled") private var timerSoundEnabled = true
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedbackEnabled = true
    @AppStorage("automaticallyPlayAssignedPlaylist") private var automaticallyPlayAssignedPlaylist = false
    @State private var resetSampleConfirmation = false
    @State private var deleteWorkoutConfirmation = false
    @State private var deleteAudioConfirmation = false
    @State private var message: SettingsMessage?
    var showsDoneButton = true

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Defaults") {
                    LabeledContent("Weight unit", value: "Kilograms (kg)")
                    Stepper("Default rest: \(defaultRestDuration) seconds", value: $defaultRestDuration, in: 0...900, step: 15)
                    Toggle("Automatically play assigned playlist", isOn: $automaticallyPlayAssignedPlaylist)
                }

                Section("Feedback") {
                    Toggle("Rest timer sound", isOn: $timerSoundEnabled)
                    Toggle("Haptic feedback", isOn: $hapticFeedbackEnabled)
                }

                Section("Appearance") {
                    LabeledContent("Theme", value: "Follow System")
                }

                Section("Data") {
                    Button("Reset Sample Plans", systemImage: "arrow.counterclockwise") {
                        resetSampleConfirmation = true
                    }
                    Button("Delete All Workout Data", systemImage: "trash", role: .destructive) {
                        deleteWorkoutConfirmation = true
                    }
                    Button("Delete All Imported Audio", systemImage: "trash", role: .destructive) {
                        deleteAudioConfirmation = true
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
            .confirmationDialog("Reset sample plans?", isPresented: $resetSampleConfirmation, titleVisibility: .visible) {
                Button("Delete Plans and Restore Samples", role: .destructive) { resetSamples() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your plans and exercise library will be replaced. Workout history and imported audio will remain.")
            }
            .confirmationDialog("Permanently delete all workout data?", isPresented: $deleteWorkoutConfirmation, titleVisibility: .visible) {
                Button("Delete Plans, Exercises, and History", role: .destructive) { deleteWorkoutData() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This includes active workouts and completed history. This action cannot be undone.")
            }
            .confirmationDialog("Permanently delete imported audio?", isPresented: $deleteAudioConfirmation, titleVisibility: .visible) {
                Button("Delete All Audio", role: .destructive) { deleteAllAudio() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("All GymFlow audio records and copied files will be removed. This action cannot be undone.")
            }
            .alert(item: $message) { value in
                Alert(title: Text(value.title), message: Text(value.detail), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func resetSamples() {
        plans.forEach(modelContext.delete)
        definitions.forEach(modelContext.delete)
        UserDefaults.standard.set(false, forKey: SampleDataSeeder.seedingKey)
        do {
            try modelContext.save()
            try SampleDataSeeder.seedIfNeeded(context: modelContext)
            message = .init(title: "Samples Restored", detail: "The sample workout plans and exercise library are ready.")
        } catch {
            message = .init(title: "Reset Failed", detail: error.localizedDescription)
        }
    }

    private func deleteWorkoutData() {
        WorkoutLiveActivityService.shared.endAll()
        sessions.forEach {
            RestTimerService.clearPersistedState(
                keyPrefix: "restTimer.\($0.id.uuidString)"
            )
        }
        RestTimerService.clearPersistedState(keyPrefix: "restTimer")
        UserDefaults.standard.set("", forKey: "activeWorkoutSessionID")
        plans.forEach(modelContext.delete)
        definitions.forEach(modelContext.delete)
        sessions.forEach(modelContext.delete)
        do {
            try modelContext.save()
            message = .init(title: "Workout Data Deleted", detail: "Plans, exercises, active workouts, and history were removed.")
        } catch {
            message = .init(title: "Delete Failed", detail: error.localizedDescription)
        }
    }

    private func deleteAllAudio() {
        do {
            let store = try AudioFileStore()
            audioPlayer.clearQueue()
            memberships.forEach(modelContext.delete)
            for track in tracks {
                try store.delete(storedFileName: track.storedFileName)
                modelContext.delete(track)
            }
            try modelContext.save()
            message = .init(title: "Imported Audio Deleted", detail: "All copied audio files were removed.")
        } catch {
            message = .init(title: "Delete Failed", detail: error.localizedDescription)
        }
    }
}

private struct SettingsMessage: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}
