import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(isEnabled ? Color.black : Color.secondary)
            .background(
                isEnabled
                    ? (configuration.isPressed ? GymTheme.volt.opacity(0.85) : GymTheme.volt)
                    : Color(uiColor: .tertiarySystemFill)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .background(GymTheme.cardBackgroundGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }
}

extension View {
    func gymCard() -> some View { modifier(CardModifier()) }
}
