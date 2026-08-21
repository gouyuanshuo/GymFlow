import SwiftData
import SwiftUI
import UIKit

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    /// Only completed sessions can supply a previous performance, so the store filters them rather
    /// than handing the view every session ever recorded.
    @Query(
        filter: WorkoutSession.predicate(status: .completed),
        sort: \WorkoutSession.startedAt,
        order: .reverse
    )
    private var completedSessions: [WorkoutSession]
    @AppStorage(PreferenceKey.hapticFeedbackEnabled) private var hapticsEnabled = true
    @AppStorage(PreferenceKey.timerSoundEnabled) private var timerSoundEnabled = true
    @AppStorage(PreferenceKey.activeWorkoutSessionID) private var activeWorkoutSessionID = ""
    let session: WorkoutSession
    @StateObject private var restTimer: RestTimerService
    @State private var exerciseIndex = 0
    @State private var cancelConfirmation = false
    @State private var finishConfirmation = false
    @State private var summaryPresented = false
    @State private var nowPlayingPresentation = NowPlayingPresentationState()
    @State private var notesExpanded = false
    @State private var errorMessage: String?
    /// Cached sets from the last time this exercise was trained. See `refreshPreviousPerformance()`.
    @State private var previousPerformanceSets: [WorkoutSetRecord] = []
    private let liveActivity = LiveActivityManager.shared

    init(session: WorkoutSession) {
        self.session = session
        _restTimer = StateObject(wrappedValue: RestTimerService(
            keyPrefix: RestTimerStorage.keyPrefix(for: session.id),
            migrationKeyPrefix: "restTimer",
            sessionID: session.id,
            notificationScheduler: RestTimerNotificationScheduler.shared
        ))
    }

    private var exercises: [ExerciseRecord] { session.orderedExerciseRecords }
    private var currentExercise: ExerciseRecord? {
        guard exercises.indices.contains(exerciseIndex) else { return nil }
        return exercises[exerciseIndex]
    }
    /// The set number shown in the header.
    ///
    /// Once the exercise on screen is finished there is no set left to work on, so the header keeps
    /// showing its last set rather than blanking out.
    private var currentSetNumber: Int {
        guard let currentExercise else { return 1 }
        return currentExercise.currentSet(preferring: session.currentSetNumber)?.setNumber
            ?? currentExercise.orderedSets.last?.setNumber
            ?? 1
    }
    private var allExercisesAreComplete: Bool {
        !exercises.isEmpty && exercises.allSatisfy(\.isFullyCompleted)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let exercise = currentExercise {
                        WorkoutExerciseHeader(
                            exerciseName: exercise.exerciseNameSnapshot,
                            exerciseNumber: min(exerciseIndex + 1, max(1, exercises.count)),
                            exerciseCount: exercises.count,
                            currentSetNumber: currentSetNumber,
                            setCount: exercise.orderedSets.count,
                            completedSetCount: exercise.orderedSets.filter(\.isCompleted).count,
                            workoutStartDate: session.startedAt
                        )

                        previousPerformance
                        setCards(exercise)

                        if restTimer.isRunning || restTimer.isPaused || restTimer.didComplete {
                            RestTimerCard(timer: restTimer)
                        }

                        notesCard(exercise)

                        if allExercisesAreComplete {
                            Button(
                                "Review and Finish Workout",
                                systemImage: "checkmark.circle.fill"
                            ) {
                                finishConfirmation = true
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                    } else {
                        ContentUnavailableView("No Exercises", systemImage: "dumbbell")
                            .frame(maxWidth: .infinity, minHeight: 320)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) { workoutFooter }
            .navigationTitle(session.planNameSnapshot)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Minimize", systemImage: "chevron.down") { minimizeWorkout() }
                        .labelStyle(.iconOnly)
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
            .sheet(isPresented: nowPlayingPresentedBinding) {
                NowPlayingView()
            }
            .confirmationDialog("Cancel this workout?", isPresented: $cancelConfirmation, titleVisibility: .visible) {
                Button("Cancel Workout", role: .destructive) { cancelWorkout() }
                    .accessibilityIdentifier("confirm-cancel-workout")
                Button("Keep Working Out", role: .cancel) { }
            } message: { Text("Completed set data will be retained as a cancelled session.") }
            .confirmationDialog("Finish this workout?", isPresented: $finishConfirmation, titleVisibility: .visible) {
                Button("Finish Workout") { finishWorkout() }
                Button("Keep Working Out", role: .cancel) { }
            } message: { Text("You can review the summary before returning to Today.") }
            .errorAlert("Workout Error", message: $errorMessage)
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
                restTimer.setNotificationSoundEnabled(timerSoundEnabled)
                RestTimerNotificationScheduler.shared.prepareAuthorization()
                restTimer.refresh()
                syncLiveActivity()
                refreshPreviousPerformance()
            }
            .onChange(of: exerciseIndex) { _, _ in refreshPreviousPerformance() }
            .onChange(of: completedSessions.count) { _, _ in refreshPreviousPerformance() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    restTimer.reload()
                    restoreWorkoutPosition()
                    syncLiveActivity()
                } else {
                    persistWorkoutPosition()
                    syncLiveActivity()
                }
            }
            .onChange(of: restTimer.stateRevision) { _, _ in syncLiveActivity() }
            .onChange(of: timerSoundEnabled) { _, enabled in
                restTimer.setNotificationSoundEnabled(enabled)
            }
        }
    }

    private var nowPlayingPresentedBinding: Binding<Bool> {
        Binding(
            get: { nowPlayingPresentation.isPresented },
            set: { nowPlayingPresentation.updateSystemPresentation($0) }
        )
    }

    @ViewBuilder
    private var previousPerformance: some View {
        if !previousPerformanceSets.isEmpty {
            PreviousPerformanceCard(sets: previousPerformanceSets)
        }
    }

    @ViewBuilder
    private func setCards(_ exercise: ExerciseRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(exercise.orderedSets) { set in
                WorkoutSetCard(
                    set: set,
                    canRemove: exercise.orderedSets.count > 1,
                    onChange: { _ = saveImmediately() },
                    onToggleCompletion: { toggleCompletion(set) },
                    onRemove: { removeSet(set, from: exercise) }
                )
            }

            Button { addSet(to: exercise) } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("add-workout-set")
        }
    }

    @ViewBuilder
    private func notesCard(_ exercise: ExerciseRecord) -> some View {
        // `@Bindable` gives the SwiftData model a binding directly, so the notes field does not need
        // a hand-written `Binding(get:set:)`; the save side effect moves to `onChange`.
        @Bindable var exercise = exercise
        DisclosureGroup(isExpanded: $notesExpanded) {
            TextEditor(text: $exercise.notes)
                .frame(minHeight: 88)
                .scrollContentBackground(.hidden)
                .padding(.top, 8)
                .onChange(of: exercise.notes) { _, _ in saveImmediately() }
                .accessibilityLabel("Exercise notes")
        } label: {
            Label("Exercise Notes", systemImage: "note.text")
                .font(.headline)
        }
        .gymCard()
    }

    private var workoutFooter: some View {
        VStack(spacing: 0) {
            if MiniPlayerPresentationPolicy.showsWorkoutPlayer(
                hasLoadedTrack: audioPlayer.currentTrack != nil,
                isWorkoutPresented: true,
                isNowPlayingPresented: nowPlayingPresentation.isPresented
            ) {
                MiniPlayerView { nowPlayingPresentation.present() }
            }

            WorkoutExerciseNavigation(
                exerciseNumber: min(exerciseIndex + 1, max(1, exercises.count)),
                exerciseCount: exercises.count,
                canGoPrevious: exerciseIndex > 0,
                canGoNext: exerciseIndex < exercises.count - 1,
                onPrevious: { navigate(to: exerciseIndex - 1) },
                onNext: { navigate(to: exerciseIndex + 1) }
            )
        }
    }

    /// Finds the sets logged for `exerciseName` in the most recent other completed session.
    ///
    /// `completedSessions` is newest-first, so the first match is the most recent one.
    private func previousCompletedSets(forExerciseNamed exerciseName: String) -> [WorkoutSetRecord] {
        for candidate in completedSessions where candidate.id != session.id {
            guard let record = candidate.orderedExerciseRecords.first(where: {
                $0.exerciseNameSnapshot == exerciseName
            }) else { continue }
            return record.orderedSets.filter(\.isCompleted)
        }
        return []
    }

    /// Refreshes the cached previous performance for the exercise on screen.
    ///
    /// The lookup walks past sessions and their sets, so it runs only when the exercise or the
    /// history changes — not on every `body` pass, which the rest timer triggers each second.
    private func refreshPreviousPerformance() {
        guard let name = currentExercise?.exerciseNameSnapshot else {
            previousPerformanceSets = []
            return
        }
        previousPerformanceSets = previousCompletedSets(forExerciseNamed: name)
    }

    private func toggleCompletion(_ set: WorkoutSetRecord) {
        if set.isCompleted {
            guard WorkoutActionService.reopenSet(in: session, setID: set.id) else { return }
            exerciseIndex = session.currentExerciseIndex ?? exerciseIndex
            _ = saveImmediately()
            syncLiveActivity()
            return
        }

        let result = WorkoutActionService.completeSet(
            in: session,
            expectedSetID: set.id,
            requiresCurrentSet: false
        )
        guard result.didCompleteSet else {
            syncLiveActivity()
            return
        }
        guard saveImmediately() else {
            modelContext.rollback()
            restoreWorkoutPosition()
            return
        }

        exerciseIndex = result.currentExerciseIndex ?? exerciseIndex
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        restTimer.start(duration: result.restDuration)
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

    private func removeSet(_ set: WorkoutSetRecord, from exercise: ExerciseRecord) {
        guard exercise.sets.count > 1, exercise.sets.contains(where: { $0.id == set.id }) else {
            return
        }
        exercise.sets.removeAll { $0.id == set.id }
        modelContext.delete(set)
        for (index, remainingSet) in exercise.orderedSets.enumerated() {
            remainingSet.setNumber = index + 1
        }
        session.currentSetNumber = exercise.orderedSets.first(where: { !$0.isCompleted })?.setNumber
            ?? exercise.orderedSets.last?.setNumber
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

    @discardableResult
    private func saveImmediately() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            errorMessage = "Your latest change could not be saved. \(error.localizedDescription)"
            return false
        }
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
            guard UIApplication.shared.applicationState == .active else { return }
            RestTimerAlertService.shared.play(
                configuration: RestTimerAlertConfiguration(
                    soundEnabled: timerSoundEnabled,
                    hapticEnabled: hapticsEnabled
                ),
                audioPlayer: audioPlayer
            )
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
        liveActivity.snapshot(for: session)
    }
}
