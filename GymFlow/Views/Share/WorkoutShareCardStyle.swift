import SwiftUI

/// The scale factor and palette shared by every element of the workout share card.
///
/// The card is laid out against a fixed design size and then scaled to fit whatever space it is
/// rendered into, so every font size, padding, and corner radius is a design-space value multiplied
/// by ``scale``. Passing that factor and the background palette into each section's initialiser
/// would repeat the same two arguments at every call site, so both travel in the environment and
/// sections take only the data they draw.
struct WorkoutShareCardStyle {
    /// The size the card is designed against. Layout values are expressed in this space.
    static let designSize = CGSize(width: 393, height: 852)

    var scale: CGFloat = 1
    var background: WorkoutShareBackground = .obsidian

    /// The scale at which the card fills `size` without distorting its aspect ratio.
    static func scale(fitting size: CGSize) -> CGFloat {
        min(size.width / designSize.width, size.height / designSize.height)
    }

    /// Converts a design-space length to the rendered size.
    func length(_ designValue: CGFloat) -> CGFloat { designValue * scale }

    /// The card's typeface at a design-space point size.
    ///
    /// Every label on the card is rounded, so the design is expressed as size and weight alone.
    func font(_ designSize: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: designSize * scale, weight: weight, design: .rounded)
    }

    /// Letter spacing in design space.
    func tracking(_ designValue: CGFloat) -> CGFloat { designValue * scale }

    /// A hairline that stays visible when the card is rendered below its design size.
    var hairlineWidth: CGFloat { max(0.7, scale) }

    var foregroundColor: Color { background.foregroundColor }
    var secondaryForegroundColor: Color { background.secondaryForegroundColor }
    var panelColor: Color { background.panelColor }
    var separatorColor: Color { background.separatorColor }
}

private struct WorkoutShareCardStyleKey: EnvironmentKey {
    static let defaultValue = WorkoutShareCardStyle()
}

extension EnvironmentValues {
    var workoutShareCardStyle: WorkoutShareCardStyle {
        get { self[WorkoutShareCardStyleKey.self] }
        set { self[WorkoutShareCardStyleKey.self] = newValue }
    }
}

extension View {
    func workoutShareCardStyle(_ style: WorkoutShareCardStyle) -> some View {
        environment(\.workoutShareCardStyle, style)
    }

    /// Applies the card's panel treatment: a translucent fill, rounded corners, and a hairline edge.
    ///
    /// Three of the card's sections share this treatment and differ only in corner radius and edge
    /// colour, so it is defined once here rather than restated as a `background`/`clipShape`/
    /// `overlay` trio in each of them.
    func workoutSharePanel(
        _ style: WorkoutShareCardStyle,
        cornerRadius: CGFloat,
        edgeColor: Color? = nil,
        edgeWidth: CGFloat? = nil
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: style.length(cornerRadius), style: .continuous)
        return background(style.panelColor)
            .clipShape(shape)
            .overlay {
                shape.stroke(
                    edgeColor ?? style.separatorColor,
                    lineWidth: edgeWidth ?? style.hairlineWidth
                )
            }
    }
}
