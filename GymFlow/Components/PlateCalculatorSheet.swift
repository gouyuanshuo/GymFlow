import SwiftUI

/// Modern visual barbell plate calculator sheet.
struct PlateCalculatorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var targetWeight: Double
    @State private var barWeight: Double = 20.0

    init(initialWeight: Double) {
        _targetWeight = State(
            initialValue: initialWeight.isFinite ? max(20.0, initialWeight) : initialWeight
        )
    }

    var body: some View {
        let result = PlateCalculator.calculate(targetWeight: targetWeight, barWeight: barWeight)

        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if result.isSupported {
                        weightHeader(result)
                        barbellVisual(result)
                        plateBreakdown(result)
                        quickAdjustments
                        barSelector
                    } else {
                        ContentUnavailableView(
                            "Target Out of Range",
                            systemImage: "scalemass",
                            description: Text(
                                "The plate calculator supports finite targets up to 10,000 kg. Your workout weight has not changed."
                            )
                        )
                        Button("Use 20 kg in Calculator") {
                            targetWeight = 20
                            barWeight = 20
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .accessibilityIdentifier("plate-calculator-scroll")
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    private func weightHeader(_ result: PlateLoadingResult) -> some View {
        VStack(spacing: 4) {
            Text("TARGET WEIGHT")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(GymFlowFormatters.plateWeight(targetWeight))
                    .font(.system(size: 44, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("plate-target-weight")

                Text("kg")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            if result.remainder > 0 {
                Text("(\(GymFlowFormatters.plateWeight(result.remainder)) kg remainder with available plates)")
                    .font(.caption)
                    .foregroundStyle(GymTheme.coralForeground)
            } else {
                Text("Each side: \(GymFlowFormatters.plateWeight(result.weightPerSide)) kg")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GymTheme.voltForeground)
            }
        }
        .padding(.vertical, 8)
    }

    /// Renders a graphical Olympic barbell sleeve with color-coded bumper plates.
    private func barbellVisual(_ result: PlateLoadingResult) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .leading) {
                // Barbell Shaft & Sleeve
                HStack(spacing: 0) {
                    // Inside bar grip
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(uiColor: .tertiaryLabel))
                        .frame(width: 40, height: 14)

                    // Collar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(uiColor: .secondaryLabel))
                        .frame(width: 14, height: 48)

                    // Sleeve
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(uiColor: .systemFill))
                        .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24)
                }
                .padding(.horizontal, 16)

                // Loaded Plates on the Sleeve
                HStack(alignment: .center, spacing: 3) {
                    Spacer().frame(width: 70) // Offset past collar

                    if result.loadedSequence.isEmpty {
                        Text("No plates needed")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 8)
                    } else {
                        ForEach(Array(result.loadedSequence.enumerated()), id: \.offset) { _, plate in
                            PlateView(plate: plate)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .frame(height: 120)
            .gymGlassCard()
            .animation(
                reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.75),
                value: result.loadedSequence
            )
        }
    }

    private func plateBreakdown(_ result: PlateLoadingResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Plates Per Side", systemImage: "circle.circle")
                .font(.headline)

            if result.platesPerSide.isEmpty {
                Text("Only the empty bar is needed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                    ForEach(result.platesPerSide, id: \.plate.id) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.plate.color)
                                .frame(width: 14, height: 14)

                            Text("\(item.count) × \(item.plate.displayName) kg")
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gymGlassCard()
    }

    private var quickAdjustments: some View {
        HStack(spacing: 12) {
            adjustButton(amount: -5.0)
            adjustButton(amount: -2.5)
            adjustButton(amount: 2.5)
            adjustButton(amount: 5.0)
        }
    }

    private func adjustButton(amount: Double) -> some View {
        Button {
            let next = max(barWeight, targetWeight + amount)
            if reduceMotion {
                targetWeight = next
            } else {
                withAnimation(.snappy) { targetWeight = next }
            }
        } label: {
            Text(amount > 0 ? "+\(GymFlowFormatters.weight(amount))" : GymFlowFormatters.weight(amount))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.bordered)
        .tint(amount > 0 ? GymTheme.voltForeground : .secondary)
    }

    private var barSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Barbell Weight")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach([20.0, 15.0, 10.0], id: \.self) { weight in
                barChoice(weight)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func barChoice(_ weight: Double) -> some View {
        let selected = barWeight == weight
        let label: String
        switch weight {
        case 20: label = "20 kg (Olympic)"
        case 15: label = "15 kg (Women's)"
        default: label = "10 kg (Technique)"
        }

        return Button {
            barWeight = weight
            targetWeight = max(targetWeight, weight)
        } label: {
            HStack(spacing: 8) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(GymTheme.voltForeground)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 12)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(selected ? GymTheme.volt.opacity(0.15) : Color(uiColor: .tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(selected ? GymTheme.voltForeground : .clear, lineWidth: 1)
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier("plate-bar-weight-\(Int(weight))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A graphical representation of an individual bumper plate on a barbell.
private struct PlateView: View {
    let plate: OlympicPlate

    var body: some View {
        VStack(spacing: 2) {
            Text(plate.displayName)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(plate.labelColor)
                .rotationEffect(.degrees(-90))
        }
        .frame(width: max(16, CGFloat(plate.weight) * 0.9 + 10), height: 95 * plate.relativeHeight)
        .background(plate.color)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 1, y: 1)
    }
}
