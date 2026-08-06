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
    @AppStorage("activeWorkoutSessionID") private var activeWorkoutSessionID = ""
    let session: WorkoutSession
    @StateObject private var restTimer: RestTimerService
    @State private var exerciseIndex = 0
    @State private var cancelConfirmation = false
    @State private var finishConfirmation = false
    @State private var summaryPresented = false
    @State private var errorMessage: String?
    private let liveActivity = LiveActivityManager.shared

    init(session: WorkoutSession) {
        self.session = session
        _restTimer = StateObject(wrappedValue: RestTimerService(
            keyPrefix: "restTimer.\(session.id.uuidString)",
            migrationKeyPrefix: "restTimer"
        ))
    }

    private var exercises: [ExerciseRecord] { session.orderedExerciseRecords }
    private var currentExercise: ExerciseRecord? {
        guard exercises.indices.contains(exerciseIndex) else { return nil }
        return exercises[exerciseIndex]
    }
    private var currentSetNumber: Int {
        let savedSet = session.currentSetNumber.flatMap { savedNumber in
            currentExercise?.orderedSets.first(where: {
                $0.setNumber == savedNumber && !$0.isCompleted
            })
        }
        return savedSet?.setNumber
            ?? currentExercise?.orderedSets.first(where: { !$0.isCompleted })?.setNumber
            ?? currentExercise?.orderedSets.last?.setNumber
            ?? 1
    }
    private var currentExerciseIsComplete: Bool {
        guard let currentExercise, !currentExercise.orderedSets.isEmpty else { return false }
        return currentExercise.orderedSets.allSatisfy(\.isCompleted)
    }
    private var allExercisesAreComplete: Bool {
        !exercises.isEmpty && exercises.allSatisfy { exercise in
            !exercise.orderedSets.isEmpty && exercise.orderedSets.allSatisfy(\.isCompleted)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        workoutHeader
                        if restTimer.isRunning || restTimer.isPaused || restTimer.didComplete {
                            RestTimerCard(timer: restTimer)
                        }
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
                if MiniPlayerPresentationPolicy.showsWorkoutPlayer(
                    hasLoadedTrack: audioPlayer.currentTrack != nil,
                    isWorkoutPresented: true
                ) {
                    MiniPlayerView()
                }
                bottomControls
            }
            .navigationTitle(session.planNameSnapshot)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Minimize", systemImage: "chevron.down") { minimizeWorkout() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") { finishConfirmation = true }.fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Workout options", systemImage: "ellipsis.circle") {
                        Button("Cancel Workout", systemImage: "xmark.circle", role: .destructive) {
                            cancelConfirmation = true
                        }
                        .accessibilityIdentifier("cancel-workout-menu-action")
                    }
                }
            }
            .interactiveDismissDisabled()
            .confirmationDialog("Cancel this workout?", isPresented: $cancelConfirmation, titleVisibility: .visible) {
                Button("Cancel Workout", role: .destructive) { cancelWorkout() }
                    .accessibilityIdentifier("confirm-cancel-workout")
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
                activeWorkoutSessionID = session.id.uuidString
                restoreWorkoutPosition()
                configureTimerFeedback()
                restTimer.refresh()
                syncLiveActivity()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    restTimer.refresh()
                    syncLiveActivity()
                } else {
                    persistWorkoutPosition()
                    syncLiveActivity()
                }
            }
            .onChange(of: restTimer.stateRevision) { _, _ in syncLiveActivity() }
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
            HStack(spacing: 8) {
                Text("Set \(currentSetNumber) of \(max(1, exercise.sets.count))")
                Text("•")
                Text("\(exercise.orderedSets.filter(\.isCompleted).count) complete")
            }
            .foregroundStyle(.secondary)

            if currentExerciseIsComplete {
                Label("Exercise Complete", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .padding(.top, 4)
            }
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
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Set").frame(width: 54, alignment: .leading)
                Text("Weight").frame(maxWidth: .infinity)
                Text("Reps").frame(maxWidth: .infinity)
                Text("Done").frame(width: 44)
            }
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            Divider()

            ForEach(exercise.orderedSets) { set in
                WorkoutSetRow(
                    set: set,
                    onChange: saveImmediately,
                    onToggle: { toggleCompletion(set, exercise: exercise) }
                )
                if set.id != exercise.orderedSets.last?.id {
                    Divider().padding(.leading, 74)
                }
            }

            Divider()
                .padding(.top, 4)

            HStack(spacing: 10) {
                Button { addSet(to: exercise) } label: {
                    Label("Add Set", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if exercise.sets.count > 1 {
                    Button(role: .destructive) {
                        removeLastSet(from: exercise)
                    } label: {
                        Label("Remove", systemImage: "minus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.top, 12)
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
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                Button("Previous", systemImage: "chevron.left") {
                    navigate(to: exerciseIndex - 1)
                }
                .disabled(exerciseIndex == 0)
                .frame(maxWidth: .infinity, minHeight: 44)

                Button("Next", systemImage: "chevron.right") {
                    navigate(to: exerciseIndex + 1)
                }
                .labelStyle(.titleAndIcon)
                .disabled(exerciseIndex >= exercises.count - 1)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)

            if allExercisesAreComplete {
                Button("Review and Finish Workout", systemImage: "checkmark.circle.fill") {
                    finishConfirmation = true
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
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
        session.currentSetNumber = exercise.orderedSets.first(where: { !$0.isCompleted })?.setNumber
            ?? exercise.orderedSets.last?.setNumber
        saveImmediately()
        syncLiveActivity()
    }

    private func addSet(to exercise: ExerciseRecord) {
        let previous = exercise.orderedSets.last
        let newSet = WorkoutSetRecord(
            setNumber: exercise.sets.count + 1,
            weight: previous?.weight ?? 0,
            repetitions: previous?.repetitions ?? 0
        )
        exercise.sets.append(newSet)
        session.currentSetNumber = newSet.setNumber
        saveImmediately()
        syncLiveActivity()
    }

    private func removeLastSet(from exercise: ExerciseRecord) {
        guard exercise.sets.count > 1, let last = exercise.orderedSets.last else { return }
        exercise.sets.removeAll { $0.id == last.id }
        modelContext.delete(last)
        saveImmediately()
        syncLiveActivity()
    }

    private func restoreWorkoutPosition() {
        let savedIndex = session.currentExerciseIndex ?? firstIncompleteExerciseIndex()
        exerciseIndex = min(max(0, savedIndex), max(0, exercises.count - 1))
        session.currentExerciseIndex = exerciseIndex
        session.currentSetNumber = currentSetNumber
        saveImmediately()
    }

    private func firstIncompleteExerciseIndex() -> Int {
        exercises.firstIndex(where: { exercise in
            exercise.orderedSets.contains(where: { !$0.isCompleted })
        }) ?? max(0, exercises.count - 1)
    }

    private func navigate(to index: Int) {
        guard exercises.indices.contains(index) else { return }
        exerciseIndex = index
        persistWorkoutPosition()
        syncLiveActivity()
    }

    private func persistWorkoutPosition() {
        session.currentExerciseIndex = exerciseIndex
        session.currentSetNumber = currentSetNumber
        saveImmediately()
    }

    private func minimizeWorkout() {
        persistWorkoutPosition()
        dismiss()
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
            activeWorkoutSessionID = ""
            endLiveActivity()
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
            activeWorkoutSessionID = ""
            endLiveActivity()
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

    private func syncLiveActivity() {
        liveActivity.startOrUpdate(
            sessionID: session.id,
            workoutName: session.planNameSnapshot,
            snapshot: liveActivitySnapshot
        )
    }

    private func endLiveActivity() {
        liveActivity.end(sessionID: session.id, finalSnapshot: liveActivitySnapshot)
    }

    private var liveActivitySnapshot: WorkoutActivitySnapshot {
        let exercise = currentExercise
        let completedExercises = exercises.filter { record in
            !record.orderedSets.isEmpty && record.orderedSets.allSatisfy(\.isCompleted)
        }.count
        return WorkoutActivitySnapshot(
            exerciseName: exercise?.exerciseNameSnapshot ?? "Workout complete",
            currentSet: currentSetNumber,
            totalSets: max(1, exercise?.orderedSets.count ?? 1),
            completedExercises: completedExercises,
            totalExercises: exercises.count,
            workoutStartDate: session.startedAt,
            restEndDate: restTimer.deadline,
            pausedRestSeconds: restTimer.isPaused ? restTimer.remainingSeconds : 0,
            restComplete: restTimer.didComplete
        )
    }
}

private struct WorkoutSetRow: View {
    let set: WorkoutSetRecord
    let onChange: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 4) {
                Text("\(set.setNumber)")
                    .font(.headline.monospacedDigit())
                Button {
                    set.isWarmup.toggle()
                    onChange()
                } label: {
                    Text("Warm")
                        .font(.caption2.weight(.bold))
                        .lineLimit(1)
                        .foregroundStyle(set.isWarmup ? Color.orange : Color.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(set.isWarmup ? Color.orange.opacity(0.14) : Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Set \(set.setNumber) warm-up")
                .accessibilityValue(set.isWarmup ? "On" : "Off")
            }
            .frame(width: 54)

            SetValueField(
                placeholder: "kg",
                value: Binding(
                    get: { set.weight },
                    set: { set.weight = max(0, $0); onChange() }
                ),
                keyboardType: .decimalPad,
                accessibilityLabel: "Set \(set.setNumber) weight"
            )

            SetValueField(
                placeholder: "reps",
                value: Binding(
                    get: { Double(set.repetitions) },
                    set: { set.repetitions = max(0, Int($0)); onChange() }
                ),
                keyboardType: .numberPad,
                accessibilityLabel: "Set \(set.setNumber) repetitions",
                format: .number.precision(.fractionLength(0))
            )

            Button(action: onToggle) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(set.isCompleted ? Color.green : Color.secondary.opacity(0.75))
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 44, height: 48)
            .accessibilityLabel(set.isCompleted ? "Mark set \(set.setNumber) incomplete" : "Complete set \(set.setNumber)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(set.isCompleted ? Color.green.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.snappy, value: set.isCompleted)
    }
}

private struct SetValueField: View {
    let placeholder: String
    @Binding var value: Double
    let keyboardType: UIKeyboardType
    let accessibilityLabel: String
    var format: FloatingPointFormatStyle<Double>

    init(
        placeholder: String,
        value: Binding<Double>,
        keyboardType: UIKeyboardType,
        accessibilityLabel: String,
        format: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0 ... 2))
    ) {
        self.placeholder = placeholder
        _value = value
        self.keyboardType = keyboardType
        self.accessibilityLabel = accessibilityLabel
        self.format = format
    }

    var body: some View {
        TextField(placeholder, value: $value, format: format)
            .keyboardType(keyboardType)
            .font(.body.monospacedDigit().weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
            }
            .accessibilityLabel(accessibilityLabel)
    }
}
