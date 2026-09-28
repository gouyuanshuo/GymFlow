import SwiftUI

/// Definition of a standard Olympic barbell plate.
struct OlympicPlate: Identifiable, Equatable, Hashable {
    let weight: Double
    let color: Color
    let labelColor: Color
    let relativeHeight: CGFloat // For visual rendering proportion

    var id: Double { weight }

    var displayName: String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.2g", weight)
    }

    static let available: [OlympicPlate] = [
        OlympicPlate(weight: 25.0, color: Color(red: 0.88, green: 0.18, blue: 0.18), labelColor: .white, relativeHeight: 1.0),
        OlympicPlate(weight: 20.0, color: Color(red: 0.15, green: 0.40, blue: 0.88), labelColor: .white, relativeHeight: 0.98),
        OlympicPlate(weight: 15.0, color: Color(red: 0.92, green: 0.74, blue: 0.12), labelColor: .black, relativeHeight: 0.90),
        OlympicPlate(weight: 10.0, color: Color(red: 0.18, green: 0.72, blue: 0.30), labelColor: .white, relativeHeight: 0.82),
        OlympicPlate(weight: 5.0,  color: Color(red: 0.90, green: 0.90, blue: 0.92), labelColor: .black, relativeHeight: 0.72),
        OlympicPlate(weight: 2.5,  color: Color(red: 0.24, green: 0.24, blue: 0.26), labelColor: .white, relativeHeight: 0.62),
        OlympicPlate(weight: 1.25, color: Color(red: 0.70, green: 0.70, blue: 0.75), labelColor: .black, relativeHeight: 0.54),
        OlympicPlate(weight: 0.5,  color: Color(red: 0.20, green: 0.60, blue: 0.65), labelColor: .white, relativeHeight: 0.46)
    ]
}

/// Result of loading plates onto a barbell.
struct PlateLoadingResult: Equatable {
    let targetWeight: Double
    let barWeight: Double
    let weightPerSide: Double
    let platesPerSide: [(plate: OlympicPlate, count: Int)]
    let loadedSequence: [OlympicPlate]
    let loadedTotal: Double
    let remainder: Double

    static func == (lhs: PlateLoadingResult, rhs: PlateLoadingResult) -> Bool {
        lhs.targetWeight == rhs.targetWeight &&
        lhs.barWeight == rhs.barWeight &&
        lhs.loadedSequence == rhs.loadedSequence
    }
}

/// Mathematical engine for calculating barbell plate loading.
enum PlateCalculator {
    /// Computes the optimal plates to load per side of a barbell.
    static func calculate(
        targetWeight: Double,
        barWeight: Double = 20.0,
        availablePlates: [OlympicPlate] = OlympicPlate.available
    ) -> PlateLoadingResult {
        guard targetWeight > barWeight else {
            return PlateLoadingResult(
                targetWeight: targetWeight,
                barWeight: barWeight,
                weightPerSide: 0,
                platesPerSide: [],
                loadedSequence: [],
                loadedTotal: barWeight,
                remainder: max(0, targetWeight - barWeight)
            )
        }

        var neededPerSide = (targetWeight - barWeight) / 2.0
        var counts: [(plate: OlympicPlate, count: Int)] = []
        var sequence: [OlympicPlate] = []

        // Sort descending by weight
        let sortedPlates = availablePlates.sorted { $0.weight > $1.weight }

        for plate in sortedPlates {
            if neededPerSide >= plate.weight - 0.001 {
                let count = Int(neededPerSide / plate.weight)
                if count > 0 {
                    counts.append((plate: plate, count: count))
                    for _ in 0..<count {
                        sequence.append(plate)
                    }
                    neededPerSide -= Double(count) * plate.weight
                }
            }
        }

        let loadedPerSide = sequence.reduce(0.0) { $0 + $1.weight }
        let totalLoaded = barWeight + (loadedPerSide * 2.0)
        let remainder = max(0, targetWeight - totalLoaded)

        return PlateLoadingResult(
            targetWeight: targetWeight,
            barWeight: barWeight,
            weightPerSide: loadedPerSide,
            platesPerSide: counts,
            loadedSequence: sequence,
            loadedTotal: totalLoaded,
            remainder: remainder
        )
    }
}
