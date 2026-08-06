import ActivityKit
import SwiftUI
import WidgetKit

@main
struct GymFlowLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        GymFlowLiveActivity()
    }
}

struct GymFlowLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutActivityLockScreenView(context: context)
                .activityBackgroundTint(Color(.secondarySystemBackground))
                .activitySystemActionForegroundColor(.accentColor)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if isExpired(context) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                    } else {
                        Label(
                            "\(context.state.completedExercises)/\(context.state.totalExercises)",
                            systemImage: "figure.strengthtraining.traditional"
                        )
                        .font(.caption.weight(.semibold))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    WorkoutActivityStatusView(
                        state: context.state,
                        isStale: context.isStale,
                        compact: true
                    )
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(isExpired(context) ? "Workout status unavailable" : context.state.exerciseName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if isExpired(context) {
                        Text("Open GymFlow to confirm")
                            .font(.caption)
                    } else {
                        HStack {
                            Text("Set \(context.state.currentSet) of \(context.state.totalSets)")
                            Spacer()
                            Text(context.state.workoutStartDate, style: .timer)
                                .monospacedDigit()
                        }
                        .font(.caption)
                    }
                }
            } compactLeading: {
                Image(systemName: isExpired(context)
                    ? "exclamationmark.triangle.fill"
                    : "figure.strengthtraining.traditional")
            } compactTrailing: {
                WorkoutActivityStatusView(
                    state: context.state,
                    isStale: context.isStale,
                    compact: true
                )
            } minimal: {
                Image(systemName: minimalSymbol(context))
            }
            .keylineTint(.accentColor)
        }
    }

    private func isExpired(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> Bool {
        WorkoutActivityPolicy.displayState(
            for: context.state,
            isStale: context.isStale,
            now: Date()
        ) == .stale
    }

    private func minimalSymbol(
        _ context: ActivityViewContext<WorkoutActivityAttributes>
    ) -> String {
        switch WorkoutActivityPolicy.displayState(
            for: context.state,
            isStale: context.isStale,
            now: Date()
        ) {
        case .resting, .paused: "timer"
        case .ready: "checkmark.circle.fill"
        case .training: "dumbbell.fill"
        case .stale: "exclamationmark.triangle.fill"
        }
    }
}

private struct WorkoutActivityLockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        Group {
            if displayState == .stale {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Workout status unavailable", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                    Text("Open GymFlow to confirm whether this workout is still active.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(context.attributes.workoutName, systemImage: "dumbbell.fill")
                            .font(.headline)
                            .lineLimit(1)
                        Spacer()
                        Text(context.state.workoutStartDate, style: .timer)
                            .font(.subheadline.monospacedDigit())
                    }
                    Text(context.state.exerciseName)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    HStack {
                        Text("Set \(context.state.currentSet) of \(context.state.totalSets)")
                        Spacer()
                        WorkoutActivityStatusView(
                            state: context.state,
                            isStale: context.isStale,
                            compact: false
                        )
                    }
                    .font(.subheadline)
                    ProgressView(
                        value: Double(context.state.completedExercises),
                        total: Double(max(1, context.state.totalExercises))
                    )
                    .tint(.accentColor)
                }
            }
        }
        .padding()
    }

    private var displayState: WorkoutActivityDisplayState {
        WorkoutActivityPolicy.displayState(
            for: context.state,
            isStale: context.isStale,
            now: Date()
        )
    }
}

private struct WorkoutActivityStatusView: View {
    let state: WorkoutActivityAttributes.ContentState
    let isStale: Bool
    let compact: Bool

    var body: some View {
        switch WorkoutActivityPolicy.displayState(
            for: state,
            isStale: isStale,
            now: Date()
        ) {
        case .resting(let endDate):
            let startDate = min(Date(), endDate)
            Text(timerInterval: startDate...endDate, countsDown: true)
                .monospacedDigit()
        case .paused(let seconds):
            Label(duration(seconds), systemImage: "pause.fill")
                .monospacedDigit()
        case .ready:
            Label(compact ? "Ready" : "Rest complete", systemImage: "checkmark.circle.fill")
                .lineLimit(1)
        case .training(let currentSet, let totalSets):
            if compact {
                Text("\(currentSet)/\(totalSets)")
                    .monospacedDigit()
            } else {
                Label("Training", systemImage: "figure.strengthtraining.traditional")
            }
        case .stale:
            Image(systemName: "exclamationmark.triangle.fill")
                .accessibilityLabel("Workout status unavailable")
        }
    }

    private func duration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
