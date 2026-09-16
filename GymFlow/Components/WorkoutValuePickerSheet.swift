import SwiftUI

enum WorkoutValuePickerKind: String, Identifiable {
    case weight
    case repetitions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: "Weight"
        case .repetitions: "Repetitions"
        }
    }
}

enum WorkoutSetValue: Equatable {
    case weight(Double)
    case repetitions(Int)
}

struct WorkoutValuePickerTransaction: Equatable {
    static let minimumWeight = 0.0
    static let maximumWeight = 500.0
    static let weightIncrement = 0.5
    static let repetitionRange = 0 ... 100

    let kind: WorkoutValuePickerKind
    let initialValue: WorkoutSetValue
    private(set) var selectedValue: WorkoutSetValue

    init(weight: Double) {
        let safeWeight = weight.isFinite ? max(Self.minimumWeight, weight) : Self.minimumWeight
        kind = .weight
        initialValue = .weight(safeWeight)
        selectedValue = .weight(safeWeight)
    }

    init(repetitions: Int) {
        let safeRepetitions = max(Self.repetitionRange.lowerBound, repetitions)
        kind = .repetitions
        initialValue = .repetitions(safeRepetitions)
        selectedValue = .repetitions(safeRepetitions)
    }

    var selectedWeight: Double {
        guard case let .weight(value) = selectedValue else { return Self.minimumWeight }
        return value
    }

    var selectedRepetitions: Int {
        guard case let .repetitions(value) = selectedValue else {
            return Self.repetitionRange.lowerBound
        }
        return value
    }

    var weightOptions: [Double] {
        var options = stride(
            from: Self.minimumWeight,
            through: Self.maximumWeight,
            by: Self.weightIncrement
        ).map { $0 }
        let current = selectedWeight
        if !options.contains(where: { abs($0 - current) < 0.000_1 }) {
            options.append(current)
            options.sort()
        }
        return options
    }

    var repetitionOptions: [Int] {
        var options = Array(Self.repetitionRange)
        let current = selectedRepetitions
        if !options.contains(current) {
            options.append(current)
            options.sort()
        }
        return options
    }

    mutating func selectWeight(_ value: Double) {
        guard kind == .weight, value.isFinite, value >= Self.minimumWeight else { return }
        selectedValue = .weight(value)
    }

    mutating func selectRepetitions(_ value: Int) {
        guard kind == .repetitions, value >= Self.repetitionRange.lowerBound else { return }
        selectedValue = .repetitions(value)
    }

    mutating func cancel() {
        selectedValue = initialValue
    }

    func commit(to set: WorkoutSetRecord) {
        switch selectedValue {
        case let .weight(weight):
            set.weight = weight
        case let .repetitions(repetitions):
            set.repetitions = repetitions
        }
    }
}

struct WorkoutValuePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let setNumber: Int
    let onCommit: (WorkoutValuePickerTransaction) -> Void
    @State private var transaction: WorkoutValuePickerTransaction

    init(
        setNumber: Int,
        transaction: WorkoutValuePickerTransaction,
        onCommit: @escaping (WorkoutValuePickerTransaction) -> Void
    ) {
        self.setNumber = setNumber
        self.onCommit = onCommit
        _transaction = State(initialValue: transaction)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                picker
                    .frame(maxWidth: .infinity, minHeight: 210)

                if transaction.kind == .weight {
                    Text("Kilograms")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
            .navigationTitle(transaction.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel-workout-value")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onCommit(transaction)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("confirm-workout-value")
                }
            }
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
        .accessibilityIdentifier("workout-value-picker-sheet")
    }

    @ViewBuilder
    private var picker: some View {
        switch transaction.kind {
        case .weight:
            Picker("Weight", selection: weightBinding) {
                ForEach(transaction.weightOptions, id: \.self) { weight in
                    Text(GymFlowFormatters.weight(weight))
                        .tag(weight)
                }
            }
            .pickerStyle(.wheel)
            .accessibilityLabel("Set \(setNumber) weight in kilograms")
            .accessibilityValue(
                "\(GymFlowFormatters.weight(transaction.selectedWeight)) kilograms"
            )

        case .repetitions:
            Picker("Repetitions", selection: repetitionsBinding) {
                ForEach(transaction.repetitionOptions, id: \.self) { repetitions in
                    Text("\(repetitions)")
                        .tag(repetitions)
                }
            }
            .pickerStyle(.wheel)
            .accessibilityLabel("Set \(setNumber) repetitions")
            .accessibilityValue("\(transaction.selectedRepetitions) repetitions")
        }
    }

    private var weightBinding: Binding<Double> {
        Binding(
            get: { transaction.selectedWeight },
            set: { transaction.selectWeight($0) }
        )
    }

    private var repetitionsBinding: Binding<Int> {
        Binding(
            get: { transaction.selectedRepetitions },
            set: { transaction.selectRepetitions($0) }
        )
    }
}
