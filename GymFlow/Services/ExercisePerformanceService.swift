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

    var id: UUID { setID }
    var setVolume: Double { weight * Double(repetitions) }

    var estimatedOneRepMax: Double? {
        ExercisePerformanceService.estimatedOneRepMax(weight: weight, repetitions: repetitions)
    }

    var setDescription: String {
        if weight > 0 {
            return "\(GymFlowFormatters.weight(weight)) kg × \(repetitions)"
        }
        return "\(repetitions) reps"
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
        let orderedSessions = validSessions(from: sessions)
        let records = orderedSessions.flatMap { session in
            performanceRecords(
                in: session,
                matchingExerciseID: exerciseID,
                exerciseName: exerciseName
            )
        }
        let repRecords = bestRepRecordsByWeight(from: records)
        let heaviest = bestRecord(in: records.filter { $0.weight > 0 }) { record in
            record.weight
        }
        let bestEstimated = bestRecord(in: records.filter { $0.estimatedOneRepMax != nil }) {
            $0.estimatedOneRepMax ?? 0
        }
        let bestVolume = bestRecord(in: records.filter { $0.setVolume > 0 }) {
            $0.setVolume
        }

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
                exerciseID: exerciseID,
                exerciseName: exerciseName,
                sessions: orderedSessions
            )
        )
    }

    static func personalBestEvents(
        in session: WorkoutSession,
        sessions: [WorkoutSession]
    ) -> [ExercisePREvent] {
        guard isValid(session: session) else { return [] }

        let priorSessions = validSessions(from: sessions).filter { candidate in
            candidate.id != session.id && occurs(candidate, before: session)
        }
        var events: [ExercisePREvent] = []
        var processedExerciseIdentities: Set<String> = []

        for exerciseRecord in session.orderedExerciseRecords {
            let identity = exerciseIdentityKey(for: exerciseRecord)
            guard processedExerciseIdentities.insert(identity).inserted else { continue }
            let currentRecords = performanceRecords(
                in: session,
                matchingExerciseID: exerciseRecord.exerciseID,
                exerciseName: exerciseRecord.exerciseNameSnapshot
            )
            guard !currentRecords.isEmpty else { continue }

            let previousRecords = priorSessions.flatMap { candidate in
                performanceRecords(
                    in: candidate,
                    matchingExerciseID: exerciseRecord.exerciseID,
                    exerciseName: exerciseRecord.exerciseNameSnapshot
                )
            }
            let state = PerformanceState(records: previousRecords)
            events.append(contentsOf: recordEvents(in: currentRecords, comparedTo: state))
        }

        return sortedEvents(events)
    }

    private static func personalBestEvents(
        exerciseID: UUID?,
        exerciseName: String,
        sessions: [WorkoutSession]
    ) -> [ExercisePREvent] {
        var state = PerformanceState()
        var events: [ExercisePREvent] = []

        for session in sessions {
            let records = performanceRecords(
                in: session,
                matchingExerciseID: exerciseID,
                exerciseName: exerciseName
            )
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

        if let weightRecord = bestRecord(in: records.filter { $0.weight > 0 }, value: { $0.weight }),
           weightRecord.weight > state.maximumWeight + comparisonTolerance {
            typesBySetID[weightRecord.setID, default: []].insert(.weight)
            recordsBySetID[weightRecord.setID] = weightRecord
        }

        if let estimatedRecord = bestRecord(
            in: records.filter { $0.estimatedOneRepMax != nil },
            value: { $0.estimatedOneRepMax ?? 0 }
        ), let estimated = estimatedRecord.estimatedOneRepMax,
           estimated > state.maximumEstimatedOneRepMax + comparisonTolerance {
            typesBySetID[estimatedRecord.setID, default: []].insert(.estimatedOneRepMax)
            recordsBySetID[estimatedRecord.setID] = estimatedRecord
        }

        if let volumeRecord = bestRecord(in: records.filter { $0.setVolume > 0 }, value: { $0.setVolume }),
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

    private static func performanceRecords(
        in session: WorkoutSession,
        matchingExerciseID exerciseID: UUID?,
        exerciseName: String
    ) -> [ExercisePerformanceRecord] {
        guard let completedAt = validCompletionDate(for: session) else { return [] }
        let matchingRecords = session.orderedExerciseRecords.filter {
            matches(
                record: $0,
                exerciseID: exerciseID,
                exerciseName: exerciseName
            )
        }

        return matchingRecords.flatMap { exerciseRecord in
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

    private static func matches(
        record: ExerciseRecord,
        exerciseID: UUID?,
        exerciseName: String
    ) -> Bool {
        if let recordExerciseID = record.exerciseID {
            return exerciseID == recordExerciseID
        }
        return ExerciseLibraryService.normalizedName(record.exerciseNameSnapshot)
            == ExerciseLibraryService.normalizedName(exerciseName)
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

    private static func bestRecord(
        in records: [ExercisePerformanceRecord],
        value: (ExercisePerformanceRecord) -> Double
    ) -> ExercisePerformanceRecord? {
        records.max { lhs, rhs in
            let lhsValue = value(lhs)
            let rhsValue = value(rhs)
            if abs(lhsValue - rhsValue) > comparisonTolerance {
                return lhsValue < rhsValue
            }
            if lhs.repetitions != rhs.repetitions {
                return lhs.repetitions < rhs.repetitions
            }
            if lhs.weight != rhs.weight {
                return lhs.weight < rhs.weight
            }
            return lhs.sessionCompletedAt < rhs.sessionCompletedAt
        }
    }

    private static func bestRepRecordsByWeight(
        from records: [ExercisePerformanceRecord]
    ) -> [Double: ExercisePerformanceRecord] {
        var result: [Double: ExercisePerformanceRecord] = [:]
        for record in records {
            let key = normalizedWeight(record.weight)
            guard let existing = result[key] else {
                result[key] = record
                continue
            }
            if record.repetitions > existing.repetitions
                || (record.repetitions == existing.repetitions
                    && record.sessionCompletedAt > existing.sessionCompletedAt) {
                result[key] = record
            }
        }
        return result
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
}

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

            let key = (record.weight * 100).rounded() / 100
            if let existing = repRecordsByWeight[key] {
                if record.repetitions > existing.repetitions
                    || (record.repetitions == existing.repetitions
                        && record.sessionCompletedAt > existing.sessionCompletedAt) {
                    repRecordsByWeight[key] = record
                }
            } else {
                repRecordsByWeight[key] = record
            }
        }
    }
}
