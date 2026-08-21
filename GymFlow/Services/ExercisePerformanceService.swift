import Foundation

enum ExercisePRType: String, CaseIterable, Codable, Hashable {
    case weight
    case estimatedOneRepMax
    case setVolume
    case repetitionsAtWeight

    var title: String {
        switch self {
        case .weight: "Weight PR"
        case .estimatedOneRepMax: "Estimated 1RM PR"
        case .setVolume: "Set Volume PR"
        case .repetitionsAtWeight: "Rep PR"
        }
    }

    var shortTitle: String {
        switch self {
        case .weight: "Weight"
        case .estimatedOneRepMax: "Estimated 1RM"
        case .setVolume: "Volume"
        case .repetitionsAtWeight: "Reps"
        }
    }

    var priority: Int {
        switch self {
        case .weight: 0
        case .estimatedOneRepMax: 1
        case .setVolume: 2
        case .repetitionsAtWeight: 3
        }
    }
}

struct ExercisePerformanceRecord: Identifiable, Equatable {
    let sessionID: UUID
    let exerciseRecordID: UUID
    let setID: UUID
    let exerciseID: UUID?
    let exerciseName: String
    let setNumber: Int
    let weight: Double
    let repetitions: Int
    let workoutDate: Date
    let sessionCompletedAt: Date
    /// Weight times repetitions for this set.
    let setVolume: Double
    /// The Epley estimate for this set, or `nil` for sets the formula does not apply to.
    let estimatedOneRepMax: Double?

    /// Creates a record for one logged set, deriving its metrics once.
    ///
    /// ``setVolume`` and ``estimatedOneRepMax`` are stored rather than computed because ranking a
    /// history re-reads them on every comparison, and a logged set never changes afterwards.
    init(
        sessionID: UUID,
        exerciseRecordID: UUID,
        setID: UUID,
        exerciseID: UUID?,
        exerciseName: String,
        setNumber: Int,
        weight: Double,
        repetitions: Int,
        workoutDate: Date,
        sessionCompletedAt: Date
    ) {
        self.sessionID = sessionID
        self.exerciseRecordID = exerciseRecordID
        self.setID = setID
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.weight = weight
        self.repetitions = repetitions
        self.workoutDate = workoutDate
        self.sessionCompletedAt = sessionCompletedAt
        self.setVolume = weight * Double(repetitions)
        self.estimatedOneRepMax = ExercisePerformanceService.estimatedOneRepMax(
            weight: weight,
            repetitions: repetitions
        )
    }

    var id: UUID { setID }

    var setDescription: String {
        GymFlowFormatters.set(weight: weight, repetitions: repetitions)
    }
}

struct ExercisePREvent: Identifiable, Equatable {
    let record: ExercisePerformanceRecord
    let types: [ExercisePRType]

    var id: String {
        "\(record.setID.uuidString)-\(types.map(\.rawValue).joined(separator: "-"))"
    }

    var primaryType: ExercisePRType {
        types.min(by: { $0.priority < $1.priority }) ?? .repetitionsAtWeight
    }

    var typeDescription: String {
        types.map(\.title).joined(separator: " · ")
    }

    var metricDescription: String? {
        switch primaryType {
        case .weight, .repetitionsAtWeight:
            nil
        case .estimatedOneRepMax:
            record.estimatedOneRepMax.map {
                "\(GymFlowFormatters.weight($0)) kg estimated"
            }
        case .setVolume:
            "\(GymFlowFormatters.weight(record.setVolume)) kg volume"
        }
    }
}

struct ExerciseBestSummary {
    let heaviestWeightRecord: ExercisePerformanceRecord?
    let bestRepetitionRecord: ExercisePerformanceRecord?
    let estimatedOneRepMaxRecord: ExercisePerformanceRecord?
    let bestSetVolumeRecord: ExercisePerformanceRecord?
    let repRecordsByWeight: [Double: ExercisePerformanceRecord]
    let personalBestEvents: [ExercisePREvent]

    var isEmpty: Bool {
        heaviestWeightRecord == nil
            && bestRepetitionRecord == nil
            && estimatedOneRepMaxRecord == nil
            && bestSetVolumeRecord == nil
    }
}

enum ExercisePerformanceService {
    static let estimatedOneRepMaxRepetitionRange = 1 ... 15
    static let relevantLoadFraction = 0.5
    private static let comparisonTolerance = 0.000_1

    static func estimatedOneRepMax(weight: Double, repetitions: Int) -> Double? {
        guard weight.isFinite,
              weight > 0,
              estimatedOneRepMaxRepetitionRange.contains(repetitions) else { return nil }
        return weight * (1 + Double(repetitions) / 30)
    }

    static func summary(
        for exercise: ExerciseDefinition,
        sessions: [WorkoutSession]
    ) -> ExerciseBestSummary {
        summary(
            exerciseID: exercise.id,
            exerciseName: exercise.name,
            sessions: sessions
        )
    }

    static func summary(
        exerciseID: UUID?,
        exerciseName: String,
        sessions: [WorkoutSession]
    ) -> ExerciseBestSummary {
        let identity = ExerciseIdentity(id: exerciseID, name: exerciseName)
        let orderedSessions = validSessions(from: sessions)
        let records = orderedSessions.flatMap { session in
            performanceRecords(in: session, matching: identity)
        }
        let repRecords = bestRepRecordsByWeight(from: records)
        let heaviest = bestRecord(in: records) { $0.weight > 0 ? $0.weight : nil }
        let bestEstimated = bestRecord(in: records, value: \.estimatedOneRepMax)
        let bestVolume = bestRecord(in: records) { $0.setVolume > 0 ? $0.setVolume : nil }

        return ExerciseBestSummary(
            heaviestWeightRecord: heaviest,
            bestRepetitionRecord: bestRepetitionRecord(
                from: records,
                heaviestWeight: heaviest?.weight
            ),
            estimatedOneRepMaxRecord: bestEstimated,
            bestSetVolumeRecord: bestVolume,
            repRecordsByWeight: repRecords,
            personalBestEvents: personalBestEvents(
                matching: identity,
                sessions: orderedSessions
            )
        )
    }

    /// The personal bests `session` set, judged against everything logged before it.
    ///
    /// History is indexed once up front rather than rescanned for each exercise in the finished
    /// workout: a rescan per exercise made finishing a workout cost time proportional to
    /// *exercises times sessions*, which grows painful over a training year.
    static func personalBestEvents(
        in session: WorkoutSession,
        sessions: [WorkoutSession]
    ) -> [ExercisePREvent] {
        guard isValid(session: session) else { return [] }

        let priorSessions = validSessions(from: sessions).filter { candidate in
            candidate.id != session.id && occurs(candidate, before: session)
        }
        let history = PerformanceHistory(priorSessions)
        var events: [ExercisePREvent] = []
        var processedExerciseIdentities: Set<String> = []

        for exerciseRecord in session.orderedExerciseRecords {
            let key = exerciseIdentityKey(for: exerciseRecord)
            guard processedExerciseIdentities.insert(key).inserted else { continue }
            let identity = ExerciseIdentity(
                id: exerciseRecord.exerciseID,
                name: exerciseRecord.exerciseNameSnapshot
            )
            let currentRecords = performanceRecords(in: session, matching: identity)
            guard !currentRecords.isEmpty else { continue }

            events.append(contentsOf: recordEvents(
                in: currentRecords,
                comparedTo: history.bests(for: identity)
            ))
        }

        return sortedEvents(events)
    }

    private static func personalBestEvents(
        matching identity: ExerciseIdentity,
        sessions: [WorkoutSession]
    ) -> [ExercisePREvent] {
        var state = PerformanceState()
        var events: [ExercisePREvent] = []

        for session in sessions {
            let records = performanceRecords(in: session, matching: identity)
            guard !records.isEmpty else { continue }
            events.append(contentsOf: recordEvents(in: records, comparedTo: state))
            state.add(records)
        }

        return sortedEvents(events)
    }

    private static func recordEvents(
        in records: [ExercisePerformanceRecord],
        comparedTo state: PerformanceState
    ) -> [ExercisePREvent] {
        var typesBySetID: [UUID: Set<ExercisePRType>] = [:]
        var recordsBySetID: [UUID: ExercisePerformanceRecord] = [:]

        if let weightRecord = bestRecord(in: records, value: { $0.weight > 0 ? $0.weight : nil }),
           weightRecord.weight > state.maximumWeight + comparisonTolerance {
            typesBySetID[weightRecord.setID, default: []].insert(.weight)
            recordsBySetID[weightRecord.setID] = weightRecord
        }

        if let estimatedRecord = bestRecord(in: records, value: \.estimatedOneRepMax),
           let estimated = estimatedRecord.estimatedOneRepMax,
           estimated > state.maximumEstimatedOneRepMax + comparisonTolerance {
            typesBySetID[estimatedRecord.setID, default: []].insert(.estimatedOneRepMax)
            recordsBySetID[estimatedRecord.setID] = estimatedRecord
        }

        if let volumeRecord = bestRecord(in: records, value: { $0.setVolume > 0 ? $0.setVolume : nil }),
           volumeRecord.setVolume > state.maximumSetVolume + comparisonTolerance {
            typesBySetID[volumeRecord.setID, default: []].insert(.setVolume)
            recordsBySetID[volumeRecord.setID] = volumeRecord
        }

        for (weight, record) in bestRepRecordsByWeight(from: records) {
            if let previous = state.repRecordsByWeight[weight] {
                guard record.repetitions > previous.repetitions else { continue }
            } else {
                guard weight == 0 else { continue }
            }
            typesBySetID[record.setID, default: []].insert(.repetitionsAtWeight)
            recordsBySetID[record.setID] = record
        }

        return typesBySetID.compactMap { setID, types in
            guard let record = recordsBySetID[setID] else { return nil }
            return ExercisePREvent(
                record: record,
                types: types.sorted { $0.priority < $1.priority }
            )
        }
    }

    /// The valid working sets logged for one exercise in one session.
    ///
    /// Takes a prepared ``ExerciseIdentity`` rather than an ID and a name, so a scan over many
    /// sessions normalises the target name once instead of once per record it walks past.
    private static func performanceRecords(
        in session: WorkoutSession,
        matching identity: ExerciseIdentity
    ) -> [ExercisePerformanceRecord] {
        guard let completedAt = validCompletionDate(for: session) else { return [] }
        return session.orderedExerciseRecords
            .filter(identity.matches)
            .flatMap { performanceRecords(in: $0, of: session, completedAt: completedAt) }
    }

    /// The valid working sets logged under one exercise entry of an already-validated session.
    ///
    /// Takes the session's completion date rather than re-deriving it, so a scan over a whole
    /// history validates each session once instead of once per exercise entry it contains.
    private static func performanceRecords(
        in exerciseRecord: ExerciseRecord,
        of session: WorkoutSession,
        completedAt: Date
    ) -> [ExercisePerformanceRecord] {
        exerciseRecord.orderedSets.compactMap { set in
            guard isValidWorkingSet(set) else { return nil }
            return ExercisePerformanceRecord(
                sessionID: session.id,
                exerciseRecordID: exerciseRecord.id,
                setID: set.id,
                exerciseID: exerciseRecord.exerciseID,
                exerciseName: exerciseRecord.exerciseNameSnapshot,
                setNumber: set.setNumber,
                weight: set.weight,
                repetitions: set.repetitions,
                workoutDate: session.startedAt,
                sessionCompletedAt: completedAt
            )
        }
    }

    private static func validSessions(from sessions: [WorkoutSession]) -> [WorkoutSession] {
        sessions
            .filter { isValid(session: $0) }
            .sorted { lhs, rhs in
                let lhsCompletion = lhs.completedAt ?? lhs.startedAt
                let rhsCompletion = rhs.completedAt ?? rhs.startedAt
                if lhsCompletion != rhsCompletion { return lhsCompletion < rhsCompletion }
                if lhs.startedAt != rhs.startedAt { return lhs.startedAt < rhs.startedAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    private static func isValid(session: WorkoutSession) -> Bool {
        validCompletionDate(for: session) != nil
    }

    private static func validCompletionDate(for session: WorkoutSession) -> Date? {
        guard session.status == .completed,
              session.startedAt.timeIntervalSinceReferenceDate.isFinite,
              let completedAt = session.completedAt,
              completedAt.timeIntervalSinceReferenceDate.isFinite,
              completedAt >= session.startedAt else { return nil }
        return completedAt
    }

    private static func isValidWorkingSet(_ set: WorkoutSetRecord) -> Bool {
        set.isCompleted
            && !set.isWarmup
            && set.weight.isFinite
            && set.weight >= 0
            && set.repetitions > 0
            && (set.completedAt?.timeIntervalSinceReferenceDate.isFinite ?? true)
    }

    private static func occurs(_ candidate: WorkoutSession, before session: WorkoutSession) -> Bool {
        guard let candidateCompletion = candidate.completedAt,
              let sessionCompletion = session.completedAt else { return false }
        if candidateCompletion != sessionCompletion {
            return candidateCompletion < sessionCompletion
        }
        if candidate.startedAt != session.startedAt {
            return candidate.startedAt < session.startedAt
        }
        return candidate.id.uuidString < session.id.uuidString
    }

    /// The record scoring highest on `value`, ignoring records the metric does not apply to.
    ///
    /// Returning `nil` from `value` excludes a record — a bodyweight set has no heaviest weight and
    /// an unloaded set has no estimated one-rep max — so callers do not have to build a filtered
    /// copy of the array for each metric they ask about.
    private static func bestRecord(
        in records: [ExercisePerformanceRecord],
        value: (ExercisePerformanceRecord) -> Double?
    ) -> ExercisePerformanceRecord? {
        // Score every record once. Reading `value` inside the comparison instead would re-derive
        // each score on every one of the linear number of comparisons `max(by:)` makes.
        let scored = records.compactMap { record in
            value(record).map { (score: $0, record: record) }
        }
        return scored.max { lhs, rhs in
            if abs(lhs.score - rhs.score) > comparisonTolerance {
                return lhs.score < rhs.score
            }
            if lhs.record.repetitions != rhs.record.repetitions {
                return lhs.record.repetitions < rhs.record.repetitions
            }
            if lhs.record.weight != rhs.record.weight {
                return lhs.record.weight < rhs.record.weight
            }
            return lhs.record.sessionCompletedAt < rhs.record.sessionCompletedAt
        }?.record
    }

    private static func bestRepRecordsByWeight(
        from records: [ExercisePerformanceRecord]
    ) -> [Double: ExercisePerformanceRecord] {
        PerformanceState(records: records).repRecordsByWeight
    }

    /// Whether `record` beats `other` as the best repetition effort at a given weight.
    ///
    /// More repetitions wins; an equal effort logged more recently replaces the older one, so the
    /// date shown next to a repetition best is the last time the user actually hit it.
    private static func isBetterRepetitionRecord(
        _ record: ExercisePerformanceRecord,
        than other: ExercisePerformanceRecord
    ) -> Bool {
        if record.repetitions != other.repetitions {
            return record.repetitions > other.repetitions
        }
        return record.sessionCompletedAt > other.sessionCompletedAt
    }

    private static func bestRepetitionRecord(
        from records: [ExercisePerformanceRecord],
        heaviestWeight: Double?
    ) -> ExercisePerformanceRecord? {
        let candidates: [ExercisePerformanceRecord]
        if let heaviestWeight, heaviestWeight > 0 {
            let minimumRelevantWeight = heaviestWeight * relevantLoadFraction
            candidates = records.filter { $0.weight >= minimumRelevantWeight }
        } else {
            candidates = records.filter { $0.weight == 0 }
        }
        return candidates.max { lhs, rhs in
            if lhs.repetitions != rhs.repetitions {
                return lhs.repetitions < rhs.repetitions
            }
            if lhs.weight != rhs.weight {
                return lhs.weight < rhs.weight
            }
            return lhs.sessionCompletedAt < rhs.sessionCompletedAt
        }
    }

    private static func normalizedWeight(_ weight: Double) -> Double {
        (weight * 100).rounded() / 100
    }

    private static func exerciseIdentityKey(for record: ExerciseRecord) -> String {
        if let exerciseID = record.exerciseID {
            return "id:\(exerciseID.uuidString)"
        }
        return "legacy:\(ExerciseLibraryService.normalizedName(record.exerciseNameSnapshot))"
    }

    private static func sortedEvents(_ events: [ExercisePREvent]) -> [ExercisePREvent] {
        events.sorted { lhs, rhs in
            if lhs.record.sessionCompletedAt != rhs.record.sessionCompletedAt {
                return lhs.record.sessionCompletedAt > rhs.record.sessionCompletedAt
            }
            if lhs.primaryType.priority != rhs.primaryType.priority {
                return lhs.primaryType.priority < rhs.primaryType.priority
            }
            if lhs.record.exerciseName != rhs.record.exerciseName {
                return lhs.record.exerciseName < rhs.record.exerciseName
            }
            if lhs.record.setNumber != rhs.record.setNumber {
                return lhs.record.setNumber < rhs.record.setNumber
            }
            return lhs.record.setID.uuidString < rhs.record.setID.uuidString
        }
    }

    /// The running bests for one exercise, folded over the sets that came before.
    ///
    /// Held as maxima plus a repetition best per weight rather than as the records themselves, so
    /// a long history collapses to a fixed-size value instead of every set it contains.
    private struct PerformanceState {
        private(set) var maximumWeight = 0.0
        private(set) var maximumEstimatedOneRepMax = 0.0
        private(set) var maximumSetVolume = 0.0
        private(set) var repRecordsByWeight: [Double: ExercisePerformanceRecord] = [:]

        init(records: [ExercisePerformanceRecord] = []) {
            add(records)
        }

        mutating func add(_ records: [ExercisePerformanceRecord]) {
            for record in records {
                maximumWeight = max(maximumWeight, record.weight)
                maximumEstimatedOneRepMax = max(
                    maximumEstimatedOneRepMax,
                    record.estimatedOneRepMax ?? 0
                )
                maximumSetVolume = max(maximumSetVolume, record.setVolume)
                addRepetitionBest(record)
            }
        }

        /// Folds `other` in, as if every set it saw had been added to this state.
        ///
        /// Only the repetition bests need re-comparing: the maxima are already maxima, and the best
        /// repetition effort at a weight across both states is whichever of their two bests wins.
        mutating func formUnion(_ other: PerformanceState) {
            maximumWeight = max(maximumWeight, other.maximumWeight)
            maximumEstimatedOneRepMax = max(
                maximumEstimatedOneRepMax,
                other.maximumEstimatedOneRepMax
            )
            maximumSetVolume = max(maximumSetVolume, other.maximumSetVolume)
            for record in other.repRecordsByWeight.values {
                addRepetitionBest(record)
            }
        }

        private mutating func addRepetitionBest(_ record: ExercisePerformanceRecord) {
            let key = normalizedWeight(record.weight)
            guard let existing = repRecordsByWeight[key] else {
                repRecordsByWeight[key] = record
                return
            }
            if isBetterRepetitionRecord(record, than: existing) {
                repRecordsByWeight[key] = record
            }
        }
    }

    /// The bests of every exercise in a stretch of history, indexed for lookup by exercise.
    ///
    /// A logged exercise is matched to a library exercise by ID when it carries one and by name
    /// when it does not — see ``ExerciseIdentity`` — so history is indexed both ways and a lookup
    /// merges the two. Building the index once is what lets a finished workout be judged against
    /// the whole history in a single pass over it.
    private struct PerformanceHistory {
        private var statesByExerciseID: [UUID: PerformanceState] = [:]
        private var legacyStatesByNormalizedName: [String: PerformanceState] = [:]

        init(_ priorSessions: [WorkoutSession]) {
            for session in priorSessions {
                guard let completedAt = validCompletionDate(for: session) else { continue }
                for exerciseRecord in session.exerciseRecords {
                    let records = performanceRecords(
                        in: exerciseRecord,
                        of: session,
                        completedAt: completedAt
                    )
                    guard !records.isEmpty else { continue }
                    if let exerciseID = exerciseRecord.exerciseID {
                        statesByExerciseID[exerciseID, default: PerformanceState()].add(records)
                    } else {
                        let name = ExerciseLibraryService.normalizedName(
                            exerciseRecord.exerciseNameSnapshot
                        )
                        legacyStatesByNormalizedName[name, default: PerformanceState()].add(records)
                    }
                }
            }
        }

        /// Everything logged for `identity` before the workout being judged.
        func bests(for identity: ExerciseIdentity) -> PerformanceState {
            var state = identity.id.flatMap { statesByExerciseID[$0] } ?? PerformanceState()
            if let legacy = legacyStatesByNormalizedName[identity.normalizedName] {
                state.formUnion(legacy)
            }
            return state
        }
    }
}
