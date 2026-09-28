import SwiftUI

/// Modernized rest timer card featuring a luminous circular countdown ring and tactile gym controls.
struct RestTimerRingCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var timer: RestTimerService
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 16) {
            headerRow

            if timer.didComplete {
                completedStateView
            } else {
                circularCountdownView
                controlsRow
            }
        }
        .gymGlassCard(
            highlighted: timer.isRunning,
            highlightColor: GymTheme.cyan
        )
        .accessibilityIdentifier("restTimerCard")
        .accessibilityElement(children: .contain)
        .onAppear {
            if timer.isRunning { startPulse() }
        }
        .onChange(of: timer.isRunning) { _, isRunning in
            if isRunning { startPulse() } else { isPulsing = false }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .glow(color: statusColor, radius: 4)

            Text(statusTitle)
                .font(.headline)
                .foregroundStyle(statusColor)

            Spacer()

            if !timer.didComplete {
                Text(timer.isPaused ? "PAUSED" : "ACTIVE")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.15))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Circular Countdown Ring

    private var circularCountdownView: some View {
        ZStack {
            // Background Track
            Circle()
                .stroke(Color.primary.opacity(0.06), lineWidth: 10)

            // Glowing Progress Arc
            Circle()
                .trim(from: 0, to: progressFraction)
                .stroke(
                    GymTheme.timerGradient,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .glow(color: timer.isRunning ? GymTheme.cyan : .clear, radius: isPulsing ? 8 : 4)
                .animation(.linear(duration: 0.25), value: progressFraction)

            // Center Countdown
            VStack(spacing: 2) {
                Text(GymFlowFormatters.duration(TimeInterval(timer.remainingSeconds)))
                    .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                    .foregroundStyle(.primary)

                Text("REST REMAINING")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 160, height: 160)
        .padding(.vertical, 6)
    }

    // MARK: - Completed State

    private var completedStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.green)
                .glow(color: .green, radius: 10)
                .symbolEffect(.bounce, value: timer.didComplete)

            Text("Ready For Your Next Set")
                .font(.headline.weight(.bold))

            HStack(spacing: 12) {
                Button("Restart", systemImage: "arrow.counterclockwise") {
                    timer.restart()
                }
                .buttonStyle(.bordered)

                Button("Dismiss", systemImage: "xmark") {
                    timer.dismissCompletion()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Controls

    private var controlsRow: some View {
        HStack(spacing: 10) {
            // Play / Pause
            Button {
                timer.isPaused ? timer.resume() : timer.pause()
            } label: {
                Label(
                    timer.isPaused ? "Resume" : "Pause",
                    systemImage: timer.isPaused ? "play.fill" : "pause.fill"
                )
                .labelStyle(.iconOnly)
                .font(.headline)
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(timer.isPaused ? GymTheme.volt : Color(uiColor: .tertiarySystemFill))
            .foregroundStyle(timer.isPaused ? Color.black : Color.primary)
            .accessibilityLabel(timer.isPaused ? "Resume Rest" : "Pause Rest")

            // +30 Sec
            Button {
                timer.addThirtySeconds()
            } label: {
                Text("+30 sec")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .frame(minHeight: 44)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.bordered)
            .tint(GymTheme.cyan)

            // Skip
            Button {
                timer.skip()
            } label: {
                Text("Skip")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Skip Rest")

            Spacer(minLength: 0)

            // More Options Menu
            Menu {
                Button("Restart", systemImage: "arrow.counterclockwise") {
                    timer.restart()
                }
                Button("Cancel Timer", systemImage: "xmark.circle", role: .destructive) {
                    timer.cancel()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var statusTitle: String {
        if timer.didComplete { return "Rest Complete" }
        return timer.isPaused ? "Rest Paused" : "Rest"
    }

    private var statusColor: Color {
        if timer.didComplete { return .green }
        return timer.isPaused ? GymTheme.amber : GymTheme.cyan
    }

    private var progressFraction: CGFloat {
        let remaining = Double(timer.remainingSeconds)
        let total = max(1.0, Double(max(timer.remainingSeconds, 60)))
        return CGFloat(max(0.0, min(1.0, remaining / total)))
    }

    private func startPulse() {
        guard !GymTheme.isRunningTests else { return }
        withAnimation(
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        ) {
            isPulsing = true
        }
    }
}
