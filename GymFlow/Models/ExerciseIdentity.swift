import Foundation

/// Identifies one exercise so plan entries and logged records can be matched against it.
///
/// A plan entry or a logged set always stores a name snapshot, and stores the exercise's ID only
/// when the entry was created from the library. The snapshot is what keeps old history readable
/// after an exercise is renamed or deleted, so matching has to prefer the ID and fall back to the
/// name — and the fallback has to compare names the same way everywhere, or an exercise will look
/// "used" on one screen and unused on another.
///
/// The normalised form of the target name is computed once when the identity is created, rather
/// than re-derived for every record a scan walks past.
struct ExerciseIdentity: Equatable {
    let id: UUID?
    let normalizedName: String

    init(id: UUID?, name: String) {
        self.id = id
        self.normalizedName = ExerciseLibraryService.normalizedName(name)
    }

    init(_ definition: ExerciseDefinition) {
        self.init(id: definition.id, name: definition.name)
    }

    /// Whether a stored reference points at this exercise.
    ///
    /// A reference that carries an ID is trusted outright: two library exercises may share a name,
    /// and a renamed exercise keeps its ID. Only an ID-less reference — one recorded before the
    /// exercise library existed, or typed by hand — falls back to the name.
    func matches(id referenceID: UUID?, nameSnapshot: String) -> Bool {
        if let referenceID {
            return referenceID == id
        }
        return ExerciseLibraryService.normalizedName(nameSnapshot) == normalizedName
    }

    func matches(_ record: ExerciseRecord) -> Bool {
        matches(id: record.exerciseID, nameSnapshot: record.exerciseNameSnapshot)
    }

    func matches(_ exercise: PlannedExercise) -> Bool {
        matches(id: exercise.exerciseID, nameSnapshot: exercise.exerciseNameSnapshot)
    }
}
