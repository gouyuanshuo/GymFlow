import SwiftData
import SwiftUI

struct ExerciseProgressView: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    let exerciseName: String

    private var history: [(session: WorkoutSession, record: ExerciseRecord)] {
        sessions.compactMap { session in
            guard session.status == .completed,
                let record = session.orderedExerciseRecords.first(where: {
                    $0.exerciseNameSnapshot == exerciseName
                        && $0.orderedSets.contains(where: \.isCompleted)
                })
            else { return nil }
            return (session, record)
        }
    }

    private var chartDataPoints: [StrengthDataPoint] {
        // Chronological order (oldest to newest) for chart left-to-right progression
        history.reversed().compactMap { item in
            let completed = item.record.orderedSets.filter(\.isCompleted)
            guard let bestSet = completed.max(by: { a, b in
                let e1RMA = (a.weight > 0 && a.repetitions > 0)
                    ? a.weight * (1.0 + Double(a.repetitions) / 30.0) : a.weight
                let e1RMB = (b.weight > 0 && b.repetitions > 0)
                    ? b.weight * (1.0 + Double(b.repetitions) / 30.0) : b.weight
                return e1RMA < e1RMB
            }) else { return nil }

            let volume = completed.reduce(0.0) { $0 + ($1.weight * Double($1.repetitions)) }

            return StrengthDataPoint(
                date: item.session.startedAt,
                weight: bestSet.weight,
                repetitions: bestSet.repetitions,
                totalVolume: volume,
                sessionName: item.session.planNameSnapshot
            )
        }
    }

    private var bestWeight: Double {
        history.flatMap { $0.record.orderedSets }.filter(\.isCompleted).map(\.weight).max() ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Interactive Strength Chart
                StrengthProgressionChart(dataPoints: chartDataPoints)

                // Recent Sessions Breakdown
                VStack(alignment: .leading, spacing: 14) {
                    Label("Recent Sessions", systemImage: "clock.arrow.circlepath")
                        .font(.headline)

                    if history.isEmpty {
                        Text("Complete this exercise in a workout to see history.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(history.prefix(20), id: \.session.id) { item in
                            sessionHistoryRow(item)
                        }
                    }
                }
                .gymGlassCard()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sessionHistoryRow(_ item: (session: WorkoutSession, record: ExerciseRecord)) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.session.startedAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(item.session.planNameSnapshot)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Sets horizontal flow
            HStack(spacing: 8) {
                let completedSets = item.record.orderedSets.filter(\.isCompleted)
                ForEach(Array(completedSets.enumerated()), id: \.offset) { _, set in
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
                }
            }
        }
        .padding(.vertical, 4)
    }
}
