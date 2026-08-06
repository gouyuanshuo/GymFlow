import SwiftUI

struct RestTimerCard: View {
    @ObservedObject var timer: RestTimerService

    var body: some View {
        VStack(spacing: 12) {
            Label(title, systemImage: timer.didComplete ? "checkmark.circle.fill" : "timer")
                .font(.headline)
                .foregroundStyle(timer.didComplete ? Color.green : Color.primary)

            if timer.didComplete {
                Text("Ready for your next set")
                    .font(.title3.weight(.semibold))
                HStack {
                    Button("Restart", systemImage: "arrow.counterclockwise") { timer.restart() }
                    Button("Dismiss", systemImage: "xmark") { timer.dismissCompletion() }
                }
                .buttonStyle(.bordered)
            } else {
                Text(GymFlowFormatters.duration(TimeInterval(timer.remainingSeconds)))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit())
                    .contentTransition(.numericText())
                HStack {
                    Button(timer.isPaused ? "Resume" : "Pause", systemImage: timer.isPaused ? "play.fill" : "pause.fill") {
                        timer.isPaused ? timer.resume() : timer.pause()
                    }
                    Button("+30 sec", systemImage: "plus.circle") { timer.addThirtySeconds() }
                    Button("Skip", systemImage: "forward.end.fill") { timer.skip() }
                }
                .buttonStyle(.bordered)
                HStack {
                    Button("Restart", systemImage: "arrow.counterclockwise") { timer.restart() }
                    Button("Cancel Timer", systemImage: "xmark.circle", role: .destructive) { timer.cancel() }
                }
                .buttonStyle(.bordered)
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity)
        .gymCard()
        .accessibilityIdentifier("restTimerCard")
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        if timer.didComplete { return "Rest Complete" }
        return timer.isPaused ? "Rest Paused" : "Rest Timer"
    }
}
