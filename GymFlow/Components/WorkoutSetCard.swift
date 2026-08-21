import SwiftUI

struct WorkoutSetCard: View {
    let set: WorkoutSetRecord
    let canRemove: Bool
    let onChange: () -> Void
    let onToggleCompletion: () -> Void
    let onRemove: () -> Void
    @State private var activePicker: WorkoutValuePickerKind?

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
                WorkoutValueButton(
                    title: "Weight",
                    unit: "kg",
                    value: GymFlowFormatters.weight(set.weight),
                    accessibilityLabel: "Set \(set.setNumber) weight",
                    accessibilityValue: "\(GymFlowFormatters.weight(set.weight)) kilograms",
                    accessibilityIdentifier: "set-\(set.setNumber)-weight-picker"
                ) {
                    activePicker = .weight
                }

                WorkoutValueButton(
                    title: "Reps",
                    unit: "reps",
                    value: "\(set.repetitions)",
                    accessibilityLabel: "Set \(set.setNumber) repetitions",
                    accessibilityValue: "\(set.repetitions) repetitions",
                    accessibilityIdentifier: "set-\(set.setNumber)-repetitions-picker"
                ) {
                    activePicker = .repetitions
                }
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
        .sheet(item: $activePicker) { kind in
            WorkoutValuePickerSheet(
                setNumber: set.setNumber,
                transaction: transaction(for: kind)
            ) { transaction in
                transaction.commit(to: set)
                onChange()
            }
        }
    }

    private var cardBackground: Color {
        if set.isCompleted {
            return Color.green.opacity(0.07)
        }
        return Color(uiColor: .secondarySystemBackground)
    }

    private func transaction(for kind: WorkoutValuePickerKind) -> WorkoutValuePickerTransaction {
        switch kind {
        case .weight:
            WorkoutValuePickerTransaction(weight: set.weight)
        case .repetitions:
            WorkoutValuePickerTransaction(repetitions: set.repetitions)
        }
    }
}

/// A labelled field that opens a wheel picker instead of a keyboard, for weight and repetitions.
private struct WorkoutValueButton: View {
    let title: String
    let unit: String?
    let value: String
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Button(action: action) {
                HStack(spacing: 6) {
                    Text(value)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let unit {
                        Text(unit)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color(uiColor: .tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
            .accessibilityHint("Opens a wheel picker")
            .accessibilityIdentifier(accessibilityIdentifier)
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
