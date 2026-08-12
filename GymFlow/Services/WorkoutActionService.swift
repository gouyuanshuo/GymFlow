import Foundation

enum WorkoutSetCompletionDisposition: Equatable {
    case completed
    case alreadyCompleted
    case staleSet
    case inactiveWorkout
    case noIncompleteSet
}

struct WorkoutSetCompletionResult: Equatable {
    let disposition: WorkoutSetCompletionDisposition
    let completedSetID: UUID?
    let completedSetNumber: Int?
    let restDuration: Int
    let currentExerciseIndex: Int?
    let currentSetID: UUID?
    let exerciseCompleted: Bool
    let workoutReadyToFinish: Bool

    var didCompleteSet: Bool { disposition == .completed }
}

enum WorkoutActionService {
    static func completeCurrentSet(
        in session: WorkoutSession,
        expectedSetID: UUID,
        now: Date = Date()
    ) -> WorkoutSetCompletionResult {
        completeSet(
            in: session,
            expectedSetID: expectedSetID,
            requiresCurrentSet: true,
            now: now
        )
    }

    static func completeSet(
        in session: WorkoutSession,
        expectedSetID: UUID,
        requiresCurrentSet: Bool,
        now: Date = Date()
    ) -> WorkoutSetCompletionResult {
        guard session.status == .active else {
            return result(.inactiveWorkout, session: session)
        }

        let exercises = session.orderedExerciseRecords
        guard let located = locate(setID: expectedSetID, in: exercises) else {
            return result(.staleSet, session: session)
        }
        guard !located.set.isCompleted else {
            normalizePosition(in: session)
            return result(.alreadyCompleted, session: session)
        }

        if requiresCurrentSet,
           currentIncompletePosition(in: session)?.set.id != expectedSetID {
            normalizePosition(in: session)
            return result(.staleSet, session: session)
        }

        located.set.isCompleted = true
        located.set.completedAt = now
        let exerciseCompleted = located.exercise.orderedSets.allSatisfy(\.isCompleted)
        normalizePosition(
            in: session,
            afterExerciseIndex: exerciseCompleted ? located.exerciseIndex : nil
        )

        return WorkoutSetCompletionResult(
            disposition: .completed,
            completedSetID: located.set.id,
            completedSetNumber: located.set.setNumber,
            restDuration: max(0, located.exercise.restSeconds),
            currentExerciseIndex: session.currentExerciseIndex,
            currentSetID: currentIncompletePosition(in: session)?.set.id,
            exerciseCompleted: exerciseCompleted,
            workoutReadyToFinish: allExercisesComplete(in: session)
        )
    }

    static func reopenSet(
        in session: WorkoutSession,
        setID: UUID
    ) -> Bool {
        guard session.status == .active,
              let located = locate(setID: setID, in: session.orderedExerciseRecords),
              located.set.isCompleted else {
            return false
        }
        located.set.isCompleted = false
        located.set.completedAt = nil
        session.currentExerciseIndex = located.exerciseIndex
        session.currentSetNumber = located.set.setNumber
        return true
    }

    static func currentIncompleteSet(in session: WorkoutSession) -> WorkoutSetRecord? {
        currentIncompletePosition(in: session)?.set
    }

    private static func result(
        _ disposition: WorkoutSetCompletionDisposition,
        session: WorkoutSession
    ) -> WorkoutSetCompletionResult {
        WorkoutSetCompletionResult(
            disposition: disposition,
            completedSetID: nil,
            completedSetNumber: nil,
            restDuration: 0,
            currentExerciseIndex: session.currentExerciseIndex,
            currentSetID: currentIncompletePosition(in: session)?.set.id,
            exerciseCompleted: false,
            workoutReadyToFinish: allExercisesComplete(in: session)
        )
    }

    private static func normalizePosition(
        in session: WorkoutSession,
        afterExerciseIndex completedExerciseIndex: Int? = nil
    ) {
        let exercises = session.orderedExerciseRecords
        guard !exercises.isEmpty else {
            session.currentExerciseIndex = nil
            session.currentSetNumber = nil
            return
        }

        if let completedExerciseIndex {
            let followingIndices = Array(exercises.indices.dropFirst(completedExerciseIndex + 1))
            if let index = followingIndices.first(where: {
                exercises[$0].orderedSets.contains(where: { !$0.isCompleted })
            }), let set = exercises[index].orderedSets.first(where: { !$0.isCompleted }) {
                session.currentExerciseIndex = index
                session.currentSetNumber = set.setNumber
                return
            }
        }

        if let position = currentIncompletePosition(in: session) {
            session.currentExerciseIndex = position.exerciseIndex
            session.currentSetNumber = position.set.setNumber
            return
        }

        if let index = exercises.firstIndex(where: {
            $0.orderedSets.contains(where: { !$0.isCompleted })
        }), let set = exercises[index].orderedSets.first(where: { !$0.isCompleted }) {
            session.currentExerciseIndex = index
            session.currentSetNumber = set.setNumber
            return
        }

        let finalIndex = exercises.index(before: exercises.endIndex)
        session.currentExerciseIndex = finalIndex
        session.currentSetNumber = exercises[finalIndex].orderedSets.last?.setNumber
    }

    private static func currentIncompletePosition(
        in session: WorkoutSession
    ) -> (exerciseIndex: Int, exercise: ExerciseRecord, set: WorkoutSetRecord)? {
        let exercises = session.orderedExerciseRecords
        guard !exercises.isEmpty else { return nil }

        if let savedIndex = session.currentExerciseIndex,
           exercises.indices.contains(savedIndex) {
            let exercise = exercises[savedIndex]
            if let savedNumber = session.currentSetNumber,
               let set = exercise.orderedSets.first(where: {
                   $0.setNumber == savedNumber && !$0.isCompleted
               }) {
                return (savedIndex, exercise, set)
            }
            if let set = exercise.orderedSets.first(where: { !$0.isCompleted }) {
                return (savedIndex, exercise, set)
            }
        }

        for (index, exercise) in exercises.enumerated() {
            if let set = exercise.orderedSets.first(where: { !$0.isCompleted }) {
                return (index, exercise, set)
            }
        }
        return nil
    }

    private static func locate(
        setID: UUID,
        in exercises: [ExerciseRecord]
    ) -> (exerciseIndex: Int, exercise: ExerciseRecord, set: WorkoutSetRecord)? {
        for (index, exercise) in exercises.enumerated() {
            if let set = exercise.orderedSets.first(where: { $0.id == setID }) {
                return (index, exercise, set)
            }
        }
        return nil
    }

    private static func allExercisesComplete(in session: WorkoutSession) -> Bool {
        let exercises = session.orderedExerciseRecords
        return !exercises.isEmpty && exercises.allSatisfy { exercise in
            !exercise.orderedSets.isEmpty && exercise.orderedSets.allSatisfy(\.isCompleted)
        }
    }
}
