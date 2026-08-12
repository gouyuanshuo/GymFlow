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
    @State private var nowPlayingPresentation = NowPlayingPresentationState()
    @State private var notesExpanded = false
    @State private var errorMessage: String?
    private let liveActivity = LiveActivityManager.shared

    init(session: WorkoutSession) {
        self.session = session
        _restTimer = StateObject(wrappedValue: RestTimerService(
            keyPrefix: "restTimer.\(session.id.uuidString)",
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
    private var allExercisesAreComplete: Bool {
        !exercises.isEmpty && exercises.allSatisfy { exercise in
            !exercise.orderedSets.isEmpty && exercise.orderedSets.allSatisfy(\.isCompleted)
        }
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

                        previousPerformance(exercise)
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
                restTimer.setNotificationSoundEnabled(timerSoundEnabled)
                RestTimerNotificationScheduler.shared.prepareAuthorization()
                restTimer.refresh()
                syncLiveActivity()
            }
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
    private func previousPerformance(_ exercise: ExerciseRecord) -> some View {
        if let previous = previousRecord(for: exercise) {
            let completedSets = previous.orderedSets.filter(\.isCompleted)
            if !completedSets.isEmpty {
                PreviousPerformanceCard(sets: completedSets)
            }
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
        DisclosureGroup(isExpanded: $notesExpanded) {
            TextEditor(text: Binding(
                get: { exercise.notes },
                set: { exercise.notes = $0; saveImmediately() }
            ))
            .frame(minHeight: 88)
            .scrollContentBackground(.hidden)
            .padding(.top, 8)
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
