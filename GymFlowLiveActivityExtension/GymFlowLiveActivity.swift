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
                    Label(
                        "\(context.state.completedExercises)/\(context.state.totalExercises)",
                        systemImage: "figure.strengthtraining.traditional"
                    )
                    .font(.caption.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RestStatusView(state: context.state, compact: true)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.exerciseName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Set \(context.state.currentSet) of \(context.state.totalSets)")
                        Spacer()
                        Text(context.state.workoutStartDate, style: .timer)
                            .monospacedDigit()
                    }
                    .font(.caption)
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
            } compactTrailing: {
                RestStatusView(state: context.state, compact: true)
            } minimal: {
                Image(systemName: context.state.restEndDate == nil ? "dumbbell.fill" : "timer")
            }
            .keylineTint(.accentColor)
        }
    }
}

private struct WorkoutActivityLockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
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
                RestStatusView(state: context.state, compact: false)
            }
            .font(.subheadline)
            ProgressView(
                value: Double(context.state.completedExercises),
                total: Double(max(1, context.state.totalExercises))
            )
            .tint(.accentColor)
        }
        .padding()
    }
}

private struct RestStatusView: View {
    let state: WorkoutActivityAttributes.ContentState
    let compact: Bool

    var body: some View {
        if state.restComplete {
            Label(compact ? "Ready" : "Rest complete", systemImage: "checkmark.circle.fill")
                .lineLimit(1)
        } else if let endDate = state.restEndDate {
            let startDate = min(Date.now, endDate)
            Text(timerInterval: startDate...endDate, countsDown: true)
                .monospacedDigit()
        } else if state.pausedRestSeconds > 0 {
            Label(duration(state.pausedRestSeconds), systemImage: "pause.fill")
                .monospacedDigit()
        } else if !compact {
            Label("Training", systemImage: "figure.strengthtraining.traditional")
        }
    }

    private func duration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
