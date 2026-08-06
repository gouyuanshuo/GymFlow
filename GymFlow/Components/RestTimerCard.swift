import SwiftUI

struct RestTimerCard: View {
    @ObservedObject var timer: RestTimerService

    var body: some View {
        VStack(spacing: 12) {
            Label(timer.isPaused ? "Rest Paused" : "Rest Timer", systemImage: "timer")
                .font(.headline)
            Text(GymFlowFormatters.duration(TimeInterval(timer.remainingSeconds)))
                .font(.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit())
                .contentTransition(.numericText())
            HStack {
                Button(timer.isPaused ? "Resume" : "Pause", systemImage: timer.isPaused ? "play.fill" : "pause.fill") {
                    timer.isPaused ? timer.resume() : timer.pause()
                }
                Button("+30", systemImage: "plus.circle") { timer.addThirtySeconds() }
                Button("Restart", systemImage: "arrow.counterclockwise") { timer.restart() }
                Button("Skip", systemImage: "forward.end.fill") { timer.skip() }
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .gymCard()
        .accessibilityIdentifier("restTimerCard")
        .accessibilityElement(children: .contain)
    }
}
