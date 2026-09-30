import SwiftData
import SwiftUI

struct ExerciseProgressView: View {
    private typealias HistoryEntry = (session: WorkoutSession, sets: [WorkoutSetRecord])

    @Query(
        filter: WorkoutSession.predicate(status: .completed),
        sort: \WorkoutSession.startedAt,
        order: .reverse
    )
    private var sessions: [WorkoutSession]
    let exerciseID: UUID?
    let exerciseName: String

    private var history: [HistoryEntry] {
        let identity = ExerciseIdentity(id: exerciseID, name: exerciseName)
        return sessions.compactMap { session in
            let sets = ExerciseProgressHistory.completedWorkingSets(
                matching: identity,
                in: session
            )
            return sets.isEmpty ? nil : (session, sets)
        }
    }

    private func chartDataPoints(from history: [HistoryEntry]) -> [StrengthDataPoint] {
        // Chronological order (oldest to newest) for chart left-to-right progression
        history.reversed().compactMap { item in
            let metrics = item.sets.map {
                StrengthSetMetrics(weight: $0.weight, repetitions: $0.repetitions)
            }
            guard let bestSet = StrengthProgressionMetrics.strongestSet(in: metrics) else {
                return nil
            }

            let volume = item.sets.reduce(0.0) { $0 + ($1.weight * Double($1.repetitions)) }

            return StrengthDataPoint(
                id: item.session.id,
                date: item.session.startedAt,
                weight: bestSet.weight,
                repetitions: bestSet.repetitions,
                totalVolume: volume,
                sessionName: item.session.planNameSnapshot
            )
        }
    }

    private func bestWeight(in history: [HistoryEntry]) -> Double {
        let metrics = history.flatMap { item in
            item.sets.map {
                StrengthSetMetrics(weight: $0.weight, repetitions: $0.repetitions)
            }
        }
        return StrengthProgressionMetrics.bestWeight(in: metrics)
    }

    var body: some View {
        let completedHistory = history
        let points = chartDataPoints(from: completedHistory)
        let heaviestWeight = bestWeight(in: completedHistory)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Interactive Strength Chart
                StrengthProgressionChart(dataPoints: points, bestWeight: heaviestWeight)

                // Recent Sessions Breakdown
                VStack(alignment: .leading, spacing: 14) {
                    Label("Recent Sessions", systemImage: "clock.arrow.circlepath")
                        .font(.headline)

                    if completedHistory.isEmpty {
                        Text("Complete this exercise in a workout to see history.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(completedHistory.prefix(20), id: \.session.id) { item in
                            sessionHistoryRow(item)
                        }
                    }
                }
                .gymGlassCard()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .accessibilityIdentifier("exercise-progress-scroll")
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sessionHistoryRow(_ item: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.session.startedAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(item.session.planNameSnapshot)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Keep every completed set reachable without shrinking its text.
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(item.sets, id: \.id) { set in
                        HStack(spacing: 3) {
                            Text("\(GymFlowFormatters.weight(set.weight))kg")
                                .font(.caption.weight(.bold).monospacedDigit())
                            Text("×")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Text("\(set.repetitions)")
                                .font(.caption.weight(.medium).monospacedDigit())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(Capsule())
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("history-set-\(set.id.uuidString)")
                    }
                }
            }
            .accessibilityIdentifier("completed-sets-scroll-\(item.session.id.uuidString)")
            .accessibilityLabel("Completed sets")
        }
        .padding(.vertical, 4)
    }
}
