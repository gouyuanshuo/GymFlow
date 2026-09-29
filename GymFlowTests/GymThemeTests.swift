import Testing
@testable import GymFlow

@Suite("Readable foreground accents")
struct GymThemeTests {
    @Test("Accent foregrounds meet contrast on light and dark card backgrounds")
    func foregroundContrast() {
        let lightCard = AccentRGB(red: 0.95, green: 0.95, blue: 0.97)
        let darkCard = AccentRGB(red: 0.11, green: 0.11, blue: 0.12)
        let lightAccents = [
            AccentForegroundPalette.voltLight,
            AccentForegroundPalette.cyanLight,
            AccentForegroundPalette.goldLight,
            AccentForegroundPalette.coralLight,
        ]
        let darkAccents = [
            AccentForegroundPalette.voltDark,
            AccentForegroundPalette.cyanDark,
            AccentForegroundPalette.goldDark,
            AccentForegroundPalette.coralDark,
        ]

        for accent in lightAccents {
            #expect(accent.contrastRatio(against: lightCard) >= 4.5)
        }
        for accent in darkAccents {
            #expect(accent.contrastRatio(against: darkCard) >= 4.5)
        }
    }
}
