import SwiftUI

struct RestTimerCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var timer: RestTimerService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Label(title, systemImage: timer.didComplete ? "checkmark.circle.fill" : "timer")
                    .font(.headline)
                    .foregroundStyle(timer.didComplete ? Color.green : Color.primary)

                Spacer()

                if !timer.didComplete {
                    Text(GymFlowFormatters.duration(TimeInterval(timer.remainingSeconds)))
                        .font(.system(.title, design: .rounded, weight: .bold).monospacedDigit())
                        .contentTransition(.numericText())
                        .accessibilityLabel("Rest time remaining")
                }
            }

            if timer.didComplete {
                HStack(spacing: 8) {
                    Text("Ready for your next set")
                        .font(.subheadline.weight(.semibold))

                    Spacer(minLength: 8)

                    Button("Restart", systemImage: "arrow.counterclockwise") {
                        timer.restart()
                    }
                    Button("Dismiss", systemImage: "xmark") {
                        timer.dismissCompletion()
                    }
                }
                .buttonStyle(.bordered)
            } else {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            pauseButton
                            addThirtySecondsButton
                        }
                        HStack(spacing: 8) {
                            skipButton
                            moreOptionsMenu
                        }
                    }
                    .buttonStyle(.bordered)
                } else {
                    HStack(spacing: 8) {
                        pauseButton
                        addThirtySecondsButton
                        skipButton
                        Spacer(minLength: 0)
                        moreOptionsMenu
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .gymCard()
        .accessibilityIdentifier("restTimerCard")
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        if timer.didComplete { return "Rest Complete" }
        return timer.isPaused ? "Rest Paused" : "Rest"
    }

    private var pauseButton: some View {
        Button(
            timer.isPaused ? "Resume" : "Pause",
            systemImage: timer.isPaused ? "play.fill" : "pause.fill"
        ) {
            timer.isPaused ? timer.resume() : timer.pause()
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel(timer.isPaused ? "Resume Rest" : "Pause Rest")
    }

    private var addThirtySecondsButton: some View {
        Button { timer.addThirtySeconds() } label: {
            Text("+30 sec")
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var skipButton: some View {
        Button { timer.skip() } label: {
            Text("Skip")
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityLabel("Skip Rest")
    }

    private var moreOptionsMenu: some View {
        Menu("More timer options", systemImage: "ellipsis.circle") {
            Button("Restart", systemImage: "arrow.counterclockwise") {
                timer.restart()
            }
            Button("Cancel Timer", systemImage: "xmark.circle", role: .destructive) {
                timer.cancel()
            }
        }
        .labelStyle(.iconOnly)
        .frame(width: 44, height: 44)
    }
}
