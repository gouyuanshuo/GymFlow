import SwiftUI

/// Design system definitions for GymFlow's modern athletic interface ("Onyx & Volt").
enum GymTheme {
    // MARK: - Athletic Neon Accents
    /// Electric Volt: High-energy athletic neon yellow-green for active states and primary accents.
    static let volt = Color(red: 0.83, green: 1.0, blue: 0.0)
    /// Cyber Cyan: Vibrant cyan for rest timers, recovery, and tempo metrics.
    static let cyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    /// Warm Gold: Prestige accent for Personal Bests, records, and celebrations.
    static let gold = Color(red: 1.0, green: 0.72, blue: 0.0)
    /// Warm Amber: Alias for gold / pause states.
    static let amber = gold
    /// Energetic Coral: Warm accent for intense effort or heavy working sets.
    static let coral = Color(red: 1.0, green: 0.35, blue: 0.25)

    /// Adaptive accents for text, borders, and controls on system-colored surfaces.
    static let voltForeground = foreground(
        light: AccentForegroundPalette.voltLight,
        dark: AccentForegroundPalette.voltDark
    )
    static let cyanForeground = foreground(
        light: AccentForegroundPalette.cyanLight,
        dark: AccentForegroundPalette.cyanDark
    )
    static let goldForeground = foreground(
        light: AccentForegroundPalette.goldLight,
        dark: AccentForegroundPalette.goldDark
    )
    static let coralForeground = foreground(
        light: AccentForegroundPalette.coralLight,
        dark: AccentForegroundPalette.coralDark
    )

    private static func foreground(light: AccentRGB, dark: AccentRGB) -> Color {
        Color(uiColor: UIColor { traits in
            let accent = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: accent.red,
                green: accent.green,
                blue: accent.blue,
                alpha: 1
            )
        })
    }

    // MARK: - Gradients
    static let voltGradient = LinearGradient(
        colors: [volt, Color(red: 0.55, green: 0.95, blue: 0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let timerGradient = LinearGradient(
        colors: [cyan, volt],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let goldGradient = LinearGradient(
        colors: [gold, Color(red: 1.0, green: 0.50, blue: 0.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardBackgroundGradient = LinearGradient(
        colors: [
            Color(uiColor: .secondarySystemBackground).opacity(0.85),
            Color(uiColor: .tertiarySystemBackground).opacity(0.65)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Whether tests or automated previews are currently running, to suppress infinite animation loops.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.arguments.contains("-testing")
    }
}

// MARK: - View Modifiers

struct GlassCardModifier: ViewModifier {
    var highlighted: Bool = false
    var highlightColor: Color = GymTheme.volt
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(.ultraThinMaterial)
            .background(GymTheme.cardBackgroundGradient)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        highlighted
                            ? highlightColor.opacity(0.40)
                            : Color.primary.opacity(0.08),
                        lineWidth: highlighted ? 1.5 : 1
                    )
            }
            .shadow(
                color: highlighted ? highlightColor.opacity(0.12) : Color.black.opacity(0.06),
                radius: highlighted ? 12 : 6,
                x: 0,
                y: highlighted ? 4 : 2
            )
    }
}

struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.6), radius: radius * 0.5, x: 0, y: 0)
            .shadow(color: color.opacity(0.3), radius: radius, x: 0, y: 0)
    }
}

extension View {
    /// Applies the modern glassmorphic athletic card styling.
    func gymGlassCard(
        highlighted: Bool = false,
        highlightColor: Color = GymTheme.volt,
        cornerRadius: CGFloat = 20
    ) -> some View {
        modifier(GlassCardModifier(
            highlighted: highlighted,
            highlightColor: highlightColor,
            cornerRadius: cornerRadius
        ))
    }

    /// Adds a luminous glow aura around the view.
    func glow(color: Color = GymTheme.volt, radius: CGFloat = 10) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }
}
