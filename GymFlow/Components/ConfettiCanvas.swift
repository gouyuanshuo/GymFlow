import SwiftUI

/// A single celebratory confetti particle.
private struct ConfettiParticle {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var size: CGFloat
    var rotation: Double
    var rotationSpeed: Double
    var color: Color
    var opacity: Double = 1.0
}

/// GPU-accelerated 2D immediate-mode celebratory particle canvas.
struct ConfettiCanvas: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var particles: [ConfettiParticle] = []
    @State private var startDate = Date()
    @State private var isActive = true
    private var reduceMotion: Bool {
        systemReduceMotion || GymTheme.reduceMotionForUITests
    }
    private let colors: [Color] = [
        GymTheme.volt,
        GymTheme.cyan,
        GymTheme.gold,
        GymTheme.coral,
        Color.purple,
        Color.pink
    ]

    var body: some View {
        Group {
            if reduceMotion {
                HStack {
                    Image(systemName: "sparkle")
                    Spacer()
                    Image(systemName: "sparkle")
                }
                .font(.title2)
                .foregroundStyle(GymTheme.gold)
                .padding(.horizontal, 48)
                .padding(.top, 40)
                .frame(maxHeight: .infinity, alignment: .top)
                .accessibilityHidden(true)
            } else if !GymTheme.isRunningTests {
                TimelineView(.animation(paused: !isActive)) { timeline in
                    Canvas { context, _ in
                        let elapsed = timeline.date.timeIntervalSince(startDate)
                        guard elapsed < 4.0 else { return }

                        for particle in particles {
                            let t = CGFloat(elapsed)
                            let currentX = particle.x + particle.vx * t * 60
                            let currentY = particle.y + particle.vy * t * 60 + 0.5 * 380 * t * t
                            let currentRot = particle.rotation + particle.rotationSpeed * Double(t) * 60
                            let fade = max(0.0, 1.0 - (elapsed / 3.5))

                            var particleContext = context
                            particleContext.opacity = fade
                            particleContext.translateBy(x: currentX, y: currentY)
                            particleContext.rotate(by: .degrees(currentRot))

                            let rect = CGRect(
                                x: -particle.size / 2,
                                y: -particle.size / 2,
                                width: particle.size,
                                height: particle.size * 0.6
                            )
                            particleContext.fill(
                                Path(roundedRect: rect, cornerRadius: 2),
                                with: .color(particle.color)
                            )
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear {
            guard !GymTheme.isRunningTests, !reduceMotion else { return }
            generateParticles()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                isActive = false
            }
        }
        .onChange(of: reduceMotion) { _, shouldReduceMotion in
            if shouldReduceMotion { isActive = false }
        }
    }

    private func generateParticles() {
        var items: [ConfettiParticle] = []
        let screenWidth = UIScreen.main.bounds.width
        let count = 65

        for _ in 0..<count {
            let startX = screenWidth / 2 + CGFloat.random(in: -40...40)
            let startY = CGFloat.random(in: 180...260)
            let angle = Double.random(in: -Double.pi * 0.85 ... -Double.pi * 0.15)
            let speed = CGFloat.random(in: 6...14)

            items.append(ConfettiParticle(
                x: startX,
                y: startY,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed,
                size: CGFloat.random(in: 8...14),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -12...12),
                color: colors.randomElement() ?? GymTheme.volt
            ))
        }
        particles = items
        startDate = Date()
    }
}
