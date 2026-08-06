import AudioToolbox
import SwiftData
import SwiftUI
import UIKit

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var allSessions: [WorkoutSession]
    @AppStorage("hapticFeedbackEnabled") private var hapticsEnabled = true
    @AppStorage("timerSoundEnabled") private var timerSoundEnabled = true
    let session: WorkoutSession
    @StateObject private var restTimer = RestTimerService()
    @State private var exerciseIndex = 0
    @State private var cancelConfirmation = false
    @State private var finishConfirmation = false
    @State private var summaryPresented = false
    @State private var errorMessage: String?

    private var exercises: [ExerciseRecord] { session.orderedExerciseRecords }
    private var currentExercise: ExerciseRecord? {
        guard exercises.indices.contains(exerciseIndex) else { return nil }
        return exercises[exerciseIndex]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        workoutHeader
                        if restTimer.isRunning || restTimer.isPaused { RestTimerCard(timer: restTimer) }
                        if audioPlayer.currentTrack != nil { MiniPlayerView() }
                        if let exercise = currentExercise {
                            exerciseHeader(exercise)
                            previousPerformance(exercise)
                            setsCard(exercise)
                            notesCard(exercise)
                        } else {
                            ContentUnavailableView("No Exercises", systemImage: "dumbbell")
                        }
                    }
                    .padding()
                }
                bottomControls
            }
            .navigationTitle(session.planNameSnapshot)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .destructive) { cancelConfirmation = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") { finishConfirmation = true }.fontWeight(.semibold)
                }
            }
            .interactiveDismissDisabled()
            .confirmationDialog("Cancel this workout?", isPresented: $cancelConfirmation, titleVisibility: .visible) {
                Button("Cancel Workout", role: .destructive) { cancelWorkout() }
                Button("Keep Working Out", role: .cancel) { }
            } message: { Text("Completed set data will be retained as a cancelled session.") }
            .confirmationDialog("Finish this workout?", isPresented: $finishConfirmation, titleVisibility: .visible) {
                Button("Finish Workout") { finishWorkout() }
                Button("Keep Working Out", role: .cancel) { }
            } message: { Text("You can review the summary before returning to Today.") }
            .alert("Workout Error", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("OK", role: .cancel) { } } message: { Text(errorMessage ?? "Unknown error") }
            .fullScreenCover(isPresented: $summaryPresented, onDismiss: { dismiss() }) {
                WorkoutCompletionView(session: session) {
                    summaryPresented = false
                    dismiss()
                }
            }
            .onAppear {
                configureTimerFeedback()
                restTimer.refresh()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { restTimer.refresh() }
            }
        }
    }

    private var workoutHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Exercise \(min(exerciseIndex + 1, max(1, exercises.count))) of \(exercises.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(GymFlowFormatters.duration(context.date.timeIntervalSince(session.startedAt)))
                        .font(.title2.monospacedDigit().weight(.semibold))
                }
            }
            Spacer()
            ProgressView(value: Double(exerciseIndex + 1), total: Double(max(1, exercises.count)))
                .frame(width: 100)
        }
    }

    @ViewBuilder
    private func exerciseHeader(_ exercise: ExerciseRecord) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(exercise.exerciseNameSnapshot).font(.title.bold())
            Text("\(exercise.orderedSets.filter(\.isCompleted).count) of \(exercise.sets.count) sets complete")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func previousPerformance(_ exercise: ExerciseRecord) -> some View {
        if let previous = previousRecord(for: exercise) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Previous Performance", systemImage: "clock.arrow.circlepath")
                    .font(.subheadline.weight(.semibold))
                Text(previous.orderedSets.filter(\.isCompleted).map {
                    "\(GymFlowFormatters.weight($0.weight)) kg × \($0.repetitions)"
                }.joined(separator: "  •  "))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .gymCard()
        }
    }

    @ViewBuilder
    private func setsCard(_ exercise: ExerciseRecord) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text("Set").frame(width: 36)
                Text("kg").frame(maxWidth: .infinity)
                Text("Reps").frame(maxWidth: .infinity)
                Text("Done").frame(width: 48)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            ForEach(exercise.orderedSets) { set in
                WorkoutSetRow(set: set) { toggleCompletion(set, exercise: exercise) }
            }

            HStack {
                Button("Add Set", systemImage: "plus") { addSet(to: exercise) }
                Spacer()
                if exercise.sets.count > 1 {
                    Button("Remove Last", systemImage: "minus", role: .destructive) {
                        removeLastSet(from: exercise)
                    }
                }
            }
            .font(.subheadline)
        }
        .gymCard()
    }

    @ViewBuilder
    private func notesCard(_ exercise: ExerciseRecord) -> some View {
        VStack(alignment: .leading) {
            Text("Exercise Notes").font(.headline)
            TextEditor(text: Binding(
                get: { exercise.notes },
                set: { exercise.notes = $0; saveImmediately() }
            ))
            .frame(minHeight: 70)
            .scrollContentBackground(.hidden)
            .accessibilityLabel("Exercise notes")
        }
        .gymCard()
    }

    private var bottomControls: some View {
        HStack(spacing: 16) {
            Button("Previous", systemImage: "chevron.left") {
                exerciseIndex = max(0, exerciseIndex - 1)
            }
            .disabled(exerciseIndex == 0)
            .frame(maxWidth: .infinity, minHeight: 44)

            Button("Next", systemImage: "chevron.right") {
                exerciseIndex = min(max(0, exercises.count - 1), exerciseIndex + 1)
            }
            .labelStyle(.titleAndIcon)
            .disabled(exerciseIndex >= exercises.count - 1)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .padding()
        .background(.bar)
    }

    private func previousRecord(for exercise: ExerciseRecord) -> ExerciseRecord? {
        allSessions.first(where: { candidate in
            candidate.id != session.id && candidate.status == .completed
                && candidate.orderedExerciseRecords.contains(where: {
                    $0.exerciseNameSnapshot == exercise.exerciseNameSnapshot
                })
        })?.orderedExerciseRecords.first(where: {
            $0.exerciseNameSnapshot == exercise.exerciseNameSnapshot
        })
    }

    private func toggleCompletion(_ set: WorkoutSetRecord, exercise: ExerciseRecord) {
        set.isCompleted.toggle()
        set.completedAt = set.isCompleted ? Date() : nil
        if set.isCompleted {
            if hapticsEnabled { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            restTimer.start(duration: exercise.restSeconds)
        }
        saveImmediately()
    }

    private func addSet(to exercise: ExerciseRecord) {
        let previous = exercise.orderedSets.last
        let newSet = WorkoutSetRecord(
            setNumber: exercise.sets.count + 1,
            weight: previous?.weight ?? 0,
            repetitions: previous?.repetitions ?? 0
        )
        exercise.sets.append(newSet)
        saveImmediately()
    }

    private func removeLastSet(from exercise: ExerciseRecord) {
        guard exercise.sets.count > 1, let last = exercise.orderedSets.last else { return }
        exercise.sets.removeAll { $0.id == last.id }
        modelContext.delete(last)
        saveImmediately()
    }

    private func saveImmediately() {
        do { try modelContext.save() }
        catch { errorMessage = "Your latest change could not be saved. \(error.localizedDescription)" }
    }

    private func finishWorkout() {
        session.status = .completed
        session.completedAt = Date()
        restTimer.cancel()
        do {
            try modelContext.save()
            summaryPresented = true
        } catch {
            session.status = .active
            session.completedAt = nil
            errorMessage = "The workout could not be finished. \(error.localizedDescription)"
        }
    }

    private func cancelWorkout() {
        session.status = .cancelled
        session.completedAt = Date()
        restTimer.cancel()
        do {
            try modelContext.save()
            dismiss()
        } catch {
            session.status = .active
            session.completedAt = nil
            errorMessage = "The workout could not be cancelled. \(error.localizedDescription)"
        }
    }

    private func configureTimerFeedback() {
        restTimer.onCompletion = {
            if hapticsEnabled { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            if timerSoundEnabled { AudioServicesPlaySystemSound(1057) }
        }
    }
}

private struct WorkoutSetRow: View {
    let set: WorkoutSetRecord
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(spacing: 2) {
                Text("\(set.setNumber)").font(.headline.monospacedDigit())
                Toggle("Warm-up", isOn: Binding(
                    get: { set.isWarmup }, set: { set.isWarmup = $0 }
                ))
                .labelsHidden()
                .toggleStyle(.button)
                .buttonStyle(.borderless)
                .font(.caption2)
                .accessibilityLabel("Set \(set.setNumber) warm-up")
            }
            .frame(width: 36)

            TextField("Weight", value: Binding(
                get: { set.weight }, set: { set.weight = max(0, $0) }
            ), format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("Set \(set.setNumber) weight")

            TextField("Reps", value: Binding(
                get: { set.repetitions }, set: { set.repetitions = max(0, $0) }
            ), format: .number)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("Set \(set.setNumber) repetitions")

            Button(action: onToggle) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isCompleted ? Color.green : Color.secondary)
            }
            .frame(width: 48)
            .frame(minHeight: 44)
            .accessibilityLabel(set.isCompleted ? "Mark set \(set.setNumber) incomplete" : "Complete set \(set.setNumber)")
        }
        .padding(.vertical, 3)
        .opacity(set.isCompleted ? 0.72 : 1)
    }
}
