import SwiftUI

struct WorkoutExerciseNavigation: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let exerciseNumber: Int
    let exerciseCount: Int
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            navigationButton(
                title: "Previous",
                systemImage: "chevron.left",
                showsTitle: !dynamicTypeSize.isAccessibilitySize,
                isEnabled: canGoPrevious,
                action: onPrevious
            )

            Spacer(minLength: 4)

            VStack(spacing: 1) {
                Text("Exercise")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(exerciseNumber) of \(exerciseCount)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 4)

            navigationButton(
                title: "Next",
                systemImage: "chevron.right",
                imageAfterTitle: true,
                showsTitle: !dynamicTypeSize.isAccessibilitySize,
                isEnabled: canGoNext,
                action: onNext
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func navigationButton(
        title: String,
        systemImage: String,
        imageAfterTitle: Bool = false,
        showsTitle: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if !imageAfterTitle {
                    Image(systemName: systemImage)
                }
                if showsTitle {
                    Text(title)
                        .lineLimit(1)
                }
                if imageAfterTitle {
                    Image(systemName: systemImage)
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
            .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.65)
        .accessibilityLabel("\(title) Exercise")
    }
}
