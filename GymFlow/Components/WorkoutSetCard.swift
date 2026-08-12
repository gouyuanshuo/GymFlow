import SwiftUI
import UIKit

struct WorkoutSetCard: View {
    let set: WorkoutSetRecord
    let canRemove: Bool
    let onChange: () -> Void
    let onToggleCompletion: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("Set \(set.setNumber)")
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 8)

                if canRemove {
                    Menu("Set \(set.setNumber) actions", systemImage: "ellipsis") {
                        Button("Remove Set", systemImage: "trash", role: .destructive) {
                            onRemove()
                        }
                        .accessibilityIdentifier("remove-set-\(set.setNumber)")
                    }
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("set-actions-\(set.setNumber)")
                }

                SetCompletionButton(
                    setNumber: set.setNumber,
                    isCompleted: set.isCompleted,
                    action: onToggleCompletion
                )
            }

            HStack(alignment: .top, spacing: 12) {
                WorkoutNumberInput(
                    title: "Weight",
                    unit: "kg",
                    value: Binding(
                        get: { set.weight },
                        set: {
                            set.weight = max(0, $0)
                            onChange()
                        }
                    ),
                    keyboardType: .decimalPad,
                    accessibilityLabel: "Set \(set.setNumber) weight"
                )

                WorkoutNumberInput(
                    title: "Reps",
                    value: Binding(
                        get: { Double(set.repetitions) },
                        set: {
                            set.repetitions = max(0, Int($0))
                            onChange()
                        }
                    ),
                    keyboardType: .numberPad,
                    accessibilityLabel: "Set \(set.setNumber) repetitions",
                    format: .number.precision(.fractionLength(0))
                )
            }

            WarmupChip(
                setNumber: set.setNumber,
                isSelected: set.isWarmup
            ) {
                set.isWarmup.toggle()
                onChange()
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    set.isCompleted ? Color.green.opacity(0.32) : Color.secondary.opacity(0.08),
                    lineWidth: 1
                )
        }
        .animation(.snappy, value: set.isCompleted)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workout-set-card-\(set.setNumber)")
    }

    private var cardBackground: Color {
        if set.isCompleted {
            return Color.green.opacity(0.07)
        }
        return Color(uiColor: .secondarySystemBackground)
    }
}

private struct WorkoutNumberInput: View {
    let title: String
    let unit: String?
    @Binding var value: Double
    let keyboardType: UIKeyboardType
    let accessibilityLabel: String
    let format: FloatingPointFormatStyle<Double>

    init(
        title: String,
        unit: String? = nil,
        value: Binding<Double>,
        keyboardType: UIKeyboardType,
        accessibilityLabel: String,
        format: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0 ... 2))
    ) {
        self.title = title
        self.unit = unit
        _value = value
        self.keyboardType = keyboardType
        self.accessibilityLabel = accessibilityLabel
        self.format = format
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                TextField(title, value: $value, format: format)
                    .keyboardType(keyboardType)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .accessibilityLabel(accessibilityLabel)

                if let unit {
                    Text(unit)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color(uiColor: .tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WarmupChip: View {
    let setNumber: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
                Text("Warm-up")
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? Color.orange : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.orange.opacity(0.16) : Color.secondary.opacity(0.1),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("Set \(setNumber) warm-up")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Toggles warm-up status")
    }
}

private struct SetCompletionButton: View {
    let setNumber: Int
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(isCompleted ? Color.green : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(
            isCompleted ? "Mark set \(setNumber) incomplete" : "Complete set \(setNumber)"
        )
        .accessibilityValue(isCompleted ? "Completed" : "Not completed")
        .accessibilityHint(isCompleted ? "Removes completion" : "Starts the rest timer")
    }
}
