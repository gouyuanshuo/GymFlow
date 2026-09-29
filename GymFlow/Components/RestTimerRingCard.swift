import SwiftUI

/// Modernized rest timer card featuring a luminous circular countdown ring and tactile gym controls.
struct RestTimerRingCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @ObservedObject var timer: RestTimerService
    @State private var isPulsing = false

    private var reduceMotion: Bool {
        systemReduceMotion || GymTheme.reduceMotionForUITests
    }

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
        .onChange(of: reduceMotion) { _, shouldReduceMotion in
            if shouldReduceMotion { isPulsing = false }
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
                .foregroundStyle(statusForegroundColor)

            Spacer()

            if !timer.didComplete && !dynamicTypeSize.isAccessibilitySize {
                Text(timer.isPaused ? "PAUSED" : "ACTIVE")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.15))
                    .foregroundStyle(statusForegroundColor)
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
                .trim(from: 0, to: CGFloat(timer.progressFraction))
                .stroke(
                    GymTheme.timerGradient,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .glow(color: timer.isRunning ? GymTheme.cyan : .clear, radius: isPulsing ? 8 : 4)
                .animation(
                    reduceMotion ? nil : .linear(duration: 0.25),
                    value: timer.progressFraction
                )

            // Center Countdown
            VStack(spacing: 2) {
                Text(GymFlowFormatters.duration(TimeInterval(timer.remainingSeconds)))
                    .font(.system(.title, design: .rounded, weight: .bold).monospacedDigit())
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityLabel("Rest time remaining")
                    .accessibilityValue(
                        GymFlowFormatters.duration(TimeInterval(timer.remainingSeconds))
                    )

                if !dynamicTypeSize.isAccessibilitySize {
                    Text("REST REMAINING")
                        .font(.caption2.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(
            width: dynamicTypeSize.isAccessibilitySize ? 200 : 160,
            height: dynamicTypeSize.isAccessibilitySize ? 200 : 160
        )
        .padding(.vertical, 6)
    }

    // MARK: - Completed State

    private var completedStateView: some View {
        VStack(spacing: 12) {
            completionIcon

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

    @ViewBuilder
    private var completionIcon: some View {
        let icon = Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 48, weight: .semibold))
            .foregroundStyle(.green)
            .glow(color: .green, radius: 10)

        if reduceMotion {
            icon
        } else {
            icon.symbolEffect(.bounce, value: timer.didComplete)
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlsRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    pauseButton
                    addThirtySecondsButton
                }
                HStack(spacing: 8) {
                    skipButton
                    Spacer(minLength: 0)
                    moreOptionsMenu
                }
            }
        } else {
            HStack(spacing: 10) {
                pauseButton
                addThirtySecondsButton
                skipButton
                Spacer(minLength: 0)
                moreOptionsMenu
            }
        }
    }

    private var pauseButton: some View {
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
    }

    private var addThirtySecondsButton: some View {
        Button {
            timer.addThirtySeconds()
        } label: {
            Text("+30 sec")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minHeight: 44)
                .padding(.horizontal, 8)
        }
        .buttonStyle(.bordered)
        .tint(GymTheme.cyanForeground)
    }

    private var skipButton: some View {
        Button {
            timer.skip()
        } label: {
            Text("Skip")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minHeight: 44)
                .padding(.horizontal, 8)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Skip Rest")
    }

    private var moreOptionsMenu: some View {
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
        .accessibilityLabel("More timer options")
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

    private var statusForegroundColor: Color {
        if timer.didComplete { return .green }
        return timer.isPaused ? GymTheme.goldForeground : GymTheme.cyanForeground
    }

    private func startPulse() {
        guard !GymTheme.isRunningTests, !reduceMotion else { return }
        withAnimation(
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        ) {
            isPulsing = true
        }
    }
}
