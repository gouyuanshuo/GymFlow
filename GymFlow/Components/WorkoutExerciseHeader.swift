import SwiftUI

struct WorkoutExerciseHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let exerciseName: String
    let exerciseNumber: Int
    let exerciseCount: Int
    let currentSetNumber: Int
    let setCount: Int
    let completedSetCount: Int
    let workoutStartDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(exerciseName)
                .font(.title.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("active-exercise-name")

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    exercisePosition
                    elapsedTime
                }
            } else {
                HStack(spacing: 12) {
                    exercisePosition
                        .frame(maxWidth: .infinity, alignment: .leading)
                    elapsedTime
                        .fixedSize(horizontal: true, vertical: false)
                }
            }

            ProgressView(
                value: Double(completedSetCount),
                total: Double(max(1, setCount))
            )
            .tint(completedSetCount == setCount ? .green : .accentColor)
            .accessibilityLabel("Exercise set progress")
            .accessibilityValue("\(completedSetCount) of \(setCount) sets completed")

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    setPosition
                    Spacer(minLength: 4)
                    completionStatus
                }

                VStack(alignment: .leading, spacing: 4) {
                    setPosition
                    completionStatus
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var exercisePosition: some View {
        Label(
            "Exercise \(exerciseNumber) of \(exerciseCount)",
            systemImage: "figure.strengthtraining.traditional"
        )
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
    }

    private var elapsedTime: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Label(
                GymFlowFormatters.duration(
                    context.date.timeIntervalSince(workoutStartDate)
                ),
                systemImage: "clock"
            )
            .monospacedDigit()
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
    }

    private var setPosition: some View {
        HStack(spacing: 8) {
            Text("Set \(currentSetNumber) of \(max(1, setCount))")
                .fontWeight(.semibold)
            Text("·")
                .accessibilityHidden(true)
            Text("\(completedSetCount) completed")
        }
    }

    @ViewBuilder
    private var completionStatus: some View {
        if completedSetCount == setCount, setCount > 0 {
            Label("Complete", systemImage: "checkmark.seal.fill")
                .fontWeight(.semibold)
                .foregroundStyle(.green)
        }
    }
}
