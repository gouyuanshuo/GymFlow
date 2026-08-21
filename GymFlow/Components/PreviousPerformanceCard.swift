import SwiftUI

struct PreviousPerformanceCard: View {
    let sets: [WorkoutSetRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Previous Performance", systemImage: "clock.arrow.circlepath")
                .font(.subheadline.weight(.semibold))

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(sets) { set in
                        Text(GymFlowFormatters.set(weight: set.weight, repetitions: set.repetitions))
                            .font(.caption.weight(.medium))
                            .monospacedDigit()
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.quaternary, in: Capsule())
                            .accessibilityLabel(
                                GymFlowFormatters.setAccessibilityLabel(
                                    weight: set.weight,
                                    repetitions: set.repetitions
                                )
                            )
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gymCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("previous-performance-card")
    }
}
