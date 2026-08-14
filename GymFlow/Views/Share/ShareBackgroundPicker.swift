import SwiftUI

struct ShareBackgroundPicker: View {
    let backgrounds: [WorkoutShareBackground]
    let selected: WorkoutShareBackground
    let onSelect: (WorkoutShareBackground) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(backgrounds) { background in
                    Button {
                        onSelect(background)
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            WorkoutShareBackgroundView(background: background)
                                .frame(width: 58, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            selected == background ? Color.accentColor : Color.secondary.opacity(0.25),
                                            lineWidth: selected == background ? 3 : 1
                                        )
                                }

                            if selected == background {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, Color.accentColor)
                                    .padding(4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(background.displayName)
                    .accessibilityValue(selected == background ? "Selected" : "Not selected")
                    .accessibilityIdentifier("share-background-\(background.rawValue)")
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("share-background-picker")
    }
}
