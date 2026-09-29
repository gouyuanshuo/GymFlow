import Foundation

/// Relative sRGB channels used by adaptive foreground accents.
struct AccentRGB: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    func contrastRatio(against other: AccentRGB) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private var relativeLuminance: Double {
        0.2126 * Self.linear(red)
            + 0.7152 * Self.linear(green)
            + 0.0722 * Self.linear(blue)
    }

    private static func linear(_ channel: Double) -> Double {
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }
}

/// Foreground variants chosen for readable text on adaptive cards.
enum AccentForegroundPalette {
    static let voltLight = AccentRGB(red: 0.25, green: 0.34, blue: 0)
    static let cyanLight = AccentRGB(red: 0, green: 0.32, blue: 0.36)
    static let goldLight = AccentRGB(red: 0.48, green: 0.30, blue: 0)
    static let coralLight = AccentRGB(red: 0.55, green: 0.15, blue: 0.10)

    static let voltDark = AccentRGB(red: 0.83, green: 1, blue: 0)
    static let cyanDark = AccentRGB(red: 0, green: 0.94, blue: 1)
    static let goldDark = AccentRGB(red: 1, green: 0.72, blue: 0)
    static let coralDark = AccentRGB(red: 1, green: 0.35, blue: 0.25)
}
