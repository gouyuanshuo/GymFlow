import ActivityKit
import AppIntents
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
                    Text(isExpired(context) ? "Workout status unavailable" : exerciseName(context))
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    WorkoutActivityExpandedControls(context: context)
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

    private func exerciseName(
        _ context: ActivityViewContext<WorkoutActivityAttributes>
    ) -> String {
        switch WorkoutActivityPolicy.displayState(
            for: context.state,
            isStale: context.isStale,
            now: Date()
        ) {
        case .resting, .paused:
            return context.state.lastCompletedExerciseName ?? context.state.exerciseName
        case .ready, .training, .stale:
            return context.state.exerciseName
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

                    Text(displayExerciseName)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)

                    switch displayState {
                    case .resting, .paused:
                        restContent
                    case .ready, .training:
                        setContent
                    case .stale:
                        EmptyView()
                    }

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

    private var restContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let completedSet = context.state.lastCompletedSetNumber {
                    Text("Set \(completedSet) complete")
                } else {
                    Text("Rest")
                }
                Spacer()
                WorkoutActivityStatusView(
                    state: context.state,
                    isStale: context.isStale,
                    compact: false
                )
                .font(.title3.weight(.semibold))
            }
            RestActivityButtons(sessionID: context.attributes.sessionID)
        }
    }

    @ViewBuilder
    private var setContent: some View {
        if context.state.workoutReadyToFinish {
            Label("Workout ready to finish", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)
        } else {
            HStack {
                Text("Set \(context.state.currentSet) of \(context.state.totalSets)")
                Spacer()
                Text(targetDescription)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)

            if displayState == .ready {
                Label("Rest complete — ready", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }

            if let setID = context.state.currentSetID {
                Button(intent: CompleteCurrentSetIntent(
                    sessionID: context.attributes.sessionID,
                    setID: setID
                )) {
                    Label("Complete Set", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .accessibilityLabel("Complete set \(context.state.currentSet)")
            }
        }
    }

    private var displayState: WorkoutActivityDisplayState {
        WorkoutActivityPolicy.displayState(
            for: context.state,
            isStale: context.isStale,
            now: Date()
        )
    }

    private var displayExerciseName: String {
        switch displayState {
        case .resting, .paused:
            return context.state.lastCompletedExerciseName ?? context.state.exerciseName
        case .ready, .training, .stale:
            return context.state.exerciseName
        }
    }

    private var targetDescription: String {
        let weight = context.state.targetWeight.formatted(
            .number.precision(.fractionLength(0...2))
        )
        return "\(weight) kg × \(context.state.targetRepetitions)"
    }
}

private struct WorkoutActivityExpandedControls: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        switch displayState {
        case .resting, .paused:
            VStack(spacing: 8) {
                if let completedSet = context.state.lastCompletedSetNumber {
                    Text("Set \(completedSet) complete")
                        .font(.caption)
                }
                RestActivityButtons(sessionID: context.attributes.sessionID)
            }
        case .ready, .training:
            if context.state.workoutReadyToFinish {
                Label("Workout ready to finish", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
            } else if let setID = context.state.currentSetID {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Set \(context.state.currentSet) of \(context.state.totalSets)")
                        Text(targetDescription)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    Spacer()
                    Button(intent: CompleteCurrentSetIntent(
                        sessionID: context.attributes.sessionID,
                        setID: setID
                    )) {
                        Label("Complete", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                }
            }
        case .stale:
            Text("Open GymFlow to confirm")
                .font(.caption)
        }
    }

    private var displayState: WorkoutActivityDisplayState {
        WorkoutActivityPolicy.displayState(
            for: context.state,
            isStale: context.isStale,
            now: Date()
        )
    }

    private var targetDescription: String {
        let weight = context.state.targetWeight.formatted(
            .number.precision(.fractionLength(0...2))
        )
        return "\(weight) kg × \(context.state.targetRepetitions)"
    }
}

private struct RestActivityButtons: View {
    let sessionID: UUID

    var body: some View {
        HStack(spacing: 10) {
            Button(intent: AddThirtySecondsRestIntent(sessionID: sessionID)) {
                Label("30 sec", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            Button(intent: SkipRestIntent(sessionID: sessionID)) {
                Label("Skip", systemImage: "forward.end.fill")
                    .frame(maxWidth: .infinity)
            }
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
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
                Label("Ready", systemImage: "figure.strengthtraining.traditional")
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
