import SwiftUI

struct WorkoutShareBackgroundView: View {
    let background: WorkoutShareBackground

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                baseGradient
                decorations(size: geometry.size)
                legibilityOverlay
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var baseGradient: some View {
        switch background {
        case .obsidian:
            LinearGradient(
                colors: [Color(red: 0.015, green: 0.02, blue: 0.04),
                         Color(red: 0.03, green: 0.09, blue: 0.16),
                         Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .electricBlue:
            LinearGradient(
                colors: [Color(red: 0.01, green: 0.08, blue: 0.22),
                         Color(red: 0.00, green: 0.38, blue: 0.92),
                         Color(red: 0.00, green: 0.12, blue: 0.34)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .velocityRed:
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.01, blue: 0.025),
                         Color(red: 0.82, green: 0.04, blue: 0.09),
                         Color(red: 0.11, green: 0.01, blue: 0.02)],
                startPoint: .top,
                endPoint: .bottomTrailing
            )
        case .ultraviolet:
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.02, blue: 0.20),
                         Color(red: 0.48, green: 0.04, blue: 0.72),
                         Color(red: 0.03, green: 0.18, blue: 0.34)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .graphite:
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.045, blue: 0.055),
                         Color(red: 0.25, green: 0.26, blue: 0.28),
                         Color(red: 0.025, green: 0.028, blue: 0.035)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .solarFlare:
            LinearGradient(
                colors: [Color(red: 0.22, green: 0.03, blue: 0.18),
                         Color(red: 0.94, green: 0.27, blue: 0.10),
                         Color(red: 0.97, green: 0.62, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .midnightGrid:
            LinearGradient(
                colors: [Color(red: 0.01, green: 0.03, blue: 0.09),
                         Color(red: 0.02, green: 0.14, blue: 0.22),
                         Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        case .arctic:
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.98, blue: 1.00),
                         Color(red: 0.68, green: 0.86, blue: 0.97),
                         Color(red: 0.83, green: 0.92, blue: 0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .evergreen:
            LinearGradient(
                colors: [Color(red: 0.01, green: 0.09, blue: 0.07),
                         Color(red: 0.02, green: 0.39, blue: 0.24),
                         Color(red: 0.005, green: 0.06, blue: 0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .blackGold:
            LinearGradient(
                colors: [Color.black,
                         Color(red: 0.12, green: 0.10, blue: 0.06),
                         Color(red: 0.025, green: 0.023, blue: 0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func decorations(size: CGSize) -> some View {
        switch background {
        case .obsidian:
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.23))
                    .frame(width: size.width * 0.72)
                    .blur(radius: size.width * 0.10)
                    .offset(x: size.width * 0.34, y: -size.height * 0.31)
                Capsule()
                    .fill(Color.blue.opacity(0.18))
                    .frame(width: size.width * 1.15, height: size.height * 0.12)
                    .rotationEffect(.degrees(-24))
                    .offset(x: -size.width * 0.18, y: size.height * 0.30)
            }
        case .electricBlue:
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    let step = CGFloat(index)
                    RoundedRectangle(cornerRadius: size.width * 0.04)
                        .stroke(Color.white.opacity(0.16), lineWidth: max(1, size.width * 0.006))
                        .frame(
                            width: size.width * (0.48 + step * 0.18),
                            height: size.width * (0.48 + step * 0.18)
                        )
                        .rotationEffect(.degrees(32))
                        .offset(x: size.width * 0.34, y: -size.height * 0.28)
                }
                Circle()
                    .fill(Color.cyan.opacity(0.24))
                    .frame(width: size.width * 0.58)
                    .blur(radius: size.width * 0.08)
                    .offset(x: -size.width * 0.35, y: size.height * 0.34)
            }
        case .velocityRed:
            ZStack {
                ForEach(0..<4, id: \.self) { index in
                    let step = CGFloat(index)
                    Capsule()
                        .fill(Color.white.opacity(0.08 + Double(index) * 0.025))
                        .frame(width: size.width * 1.25, height: size.height * 0.035)
                        .rotationEffect(.degrees(-23))
                        .offset(y: size.height * (-0.30 + step * 0.22))
                }
            }
        case .ultraviolet:
            ZStack {
                Circle()
                    .fill(Color.pink.opacity(0.33))
                    .frame(width: size.width * 0.68)
                    .blur(radius: size.width * 0.10)
                    .offset(x: size.width * 0.32, y: -size.height * 0.34)
                Circle()
                    .fill(Color.cyan.opacity(0.26))
                    .frame(width: size.width * 0.62)
                    .blur(radius: size.width * 0.11)
                    .offset(x: -size.width * 0.38, y: size.height * 0.34)
            }
        case .graphite:
            ZStack {
                ForEach(0..<4, id: \.self) { index in
                    let step = CGFloat(index)
                    Circle()
                        .stroke(Color.white.opacity(0.07), lineWidth: max(1, size.width * 0.006))
                        .frame(width: size.width * (0.38 + step * 0.20))
                }
                .offset(x: size.width * 0.42, y: -size.height * 0.28)
            }
        case .solarFlare:
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.34))
                    .frame(width: size.width * 0.76)
                    .blur(radius: size.width * 0.07)
                    .offset(x: size.width * 0.33, y: -size.height * 0.34)
                Capsule()
                    .fill(Color.purple.opacity(0.22))
                    .frame(width: size.width * 1.25, height: size.height * 0.18)
                    .rotationEffect(.degrees(20))
                    .offset(x: -size.width * 0.24, y: size.height * 0.35)
            }
        case .midnightGrid:
            Canvas { context, canvasSize in
                let spacing = max(14, canvasSize.width / 12)
                var path = Path()
                stride(from: 0.0, through: canvasSize.width, by: spacing).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: canvasSize.height))
                }
                stride(from: 0.0, through: canvasSize.height, by: spacing).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                }
                context.stroke(path, with: .color(Color.cyan.opacity(0.11)), lineWidth: 0.7)
            }
            .rotationEffect(.degrees(-9))
            .scaleEffect(1.15)
        case .arctic:
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.75), lineWidth: max(2, size.width * 0.035))
                    .frame(width: size.width * 0.72)
                    .offset(x: size.width * 0.36, y: -size.height * 0.30)
                Circle()
                    .fill(Color.blue.opacity(0.10))
                    .frame(width: size.width * 0.60)
                    .offset(x: -size.width * 0.38, y: size.height * 0.36)
            }
        case .evergreen:
            ZStack {
                Circle()
                    .fill(Color.mint.opacity(0.22))
                    .frame(width: size.width * 0.75)
                    .blur(radius: size.width * 0.09)
                    .offset(x: size.width * 0.37, y: -size.height * 0.30)
                Circle()
                    .stroke(Color.white.opacity(0.09), lineWidth: max(1, size.width * 0.015))
                    .frame(width: size.width * 0.85)
                    .offset(x: -size.width * 0.40, y: size.height * 0.34)
            }
        case .blackGold:
            ZStack {
                Capsule()
                    .fill(Color(red: 0.88, green: 0.66, blue: 0.25).opacity(0.30))
                    .frame(width: size.width * 1.35, height: size.height * 0.06)
                    .rotationEffect(.degrees(-30))
                    .offset(x: size.width * 0.10, y: -size.height * 0.15)
                Circle()
                    .stroke(Color(red: 0.88, green: 0.66, blue: 0.25).opacity(0.22),
                            lineWidth: max(1, size.width * 0.018))
                    .frame(width: size.width * 0.82)
                    .offset(x: size.width * 0.42, y: size.height * 0.34)
            }
        }
    }

    @ViewBuilder
    private var legibilityOverlay: some View {
        if background.isLight {
            LinearGradient(
                colors: [Color.white.opacity(0.04), Color.white.opacity(0.26)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            LinearGradient(
                colors: [Color.black.opacity(0.05), Color.black.opacity(0.13), Color.black.opacity(0.30)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
