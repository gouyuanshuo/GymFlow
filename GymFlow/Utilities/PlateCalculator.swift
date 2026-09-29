import SwiftUI

/// Definition of a standard Olympic barbell plate.
struct OlympicPlate: Identifiable, Equatable, Hashable {
    let weight: Double
    let color: Color
    let labelColor: Color
    let relativeHeight: CGFloat // For visual rendering proportion

    var id: Double { weight }

    var displayName: String {
        GymFlowFormatters.plateWeight(weight)
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
    let isSupported: Bool
    let weightPerSide: Double
    let platesPerSide: [(plate: OlympicPlate, count: Int)]
    let loadedSequence: [OlympicPlate]
    let loadedTotal: Double
    let remainder: Double

    static func == (lhs: PlateLoadingResult, rhs: PlateLoadingResult) -> Bool {
        lhs.targetWeight == rhs.targetWeight &&
        lhs.barWeight == rhs.barWeight &&
        lhs.isSupported == rhs.isSupported &&
        lhs.loadedSequence == rhs.loadedSequence
    }
}

/// Mathematical engine for calculating barbell plate loading.
enum PlateCalculator {
    /// Keeps the plate search and rendered plate count within a useful range.
    static let maximumTargetWeight = 10_000.0

    /// Computes the optimal plates to load per side of a barbell.
    static func calculate(
        targetWeight: Double,
        barWeight: Double = 20.0,
        availablePlates: [OlympicPlate] = OlympicPlate.available
    ) -> PlateLoadingResult {
        guard targetWeight.isFinite,
              barWeight.isFinite,
              barWeight > 0,
              barWeight <= Self.maximumTargetWeight,
              targetWeight <= Self.maximumTargetWeight else {
            return PlateLoadingResult(
                targetWeight: targetWeight,
                barWeight: barWeight,
                isSupported: false,
                weightPerSide: 0,
                platesPerSide: [],
                loadedSequence: [],
                loadedTotal: barWeight.isFinite ? max(0, barWeight) : 0,
                remainder: 0
            )
        }

        guard targetWeight > barWeight else {
            return PlateLoadingResult(
                targetWeight: barWeight,
                barWeight: barWeight,
                isSupported: true,
                weightPerSide: 0,
                platesPerSide: [],
                loadedSequence: [],
                loadedTotal: barWeight,
                remainder: max(0, targetWeight - barWeight)
            )
        }

        let neededPerSide = (targetWeight - barWeight) / 2.0
        let targetUnits = Int((neededPerSide * 4.0).rounded(.down))
        let sortedPlates = availablePlates
            .filter {
                $0.weight.isFinite && $0.weight > 0
                    && $0.weight <= Self.maximumTargetWeight
                    && ($0.weight * 4.0).rounded() == $0.weight * 4.0
            }
            .sorted { $0.weight > $1.weight }
        let plateUnits = sortedPlates.map { Int(($0.weight * 4.0).rounded()) }

        var minimumPlateCount = Array(repeating: Int.max, count: targetUnits + 1)
        var lastPlateIndex = Array(repeating: -1, count: targetUnits + 1)
        minimumPlateCount[0] = 0

        if targetUnits > 0 {
            for loadUnits in 1...targetUnits {
                for plateIndex in sortedPlates.indices {
                    let units = plateUnits[plateIndex]
                    guard units <= loadUnits,
                          minimumPlateCount[loadUnits - units] != Int.max else { continue }

                    let count = minimumPlateCount[loadUnits - units] + 1
                    if count < minimumPlateCount[loadUnits] {
                        minimumPlateCount[loadUnits] = count
                        lastPlateIndex[loadUnits] = plateIndex
                    }
                }
            }
        }

        var loadedUnits = targetUnits
        while loadedUnits > 0 && minimumPlateCount[loadedUnits] == Int.max {
            loadedUnits -= 1
        }

        var plateCounts = Array(repeating: 0, count: sortedPlates.count)
        var remainingUnits = loadedUnits
        while remainingUnits > 0 {
            let plateIndex = lastPlateIndex[remainingUnits]
            guard plateIndex >= 0 else { break }
            plateCounts[plateIndex] += 1
            remainingUnits -= plateUnits[plateIndex]
        }

        let counts: [(plate: OlympicPlate, count: Int)] = sortedPlates.enumerated().compactMap {
            index, plate in
            let count = plateCounts[index]
            return count > 0 ? (plate: plate, count: count) : nil
        }
        let sequence = counts.flatMap { Array(repeating: $0.plate, count: $0.count) }
        let loadedPerSide = sequence.reduce(0.0) { $0 + $1.weight }
        let totalLoaded = barWeight + (loadedPerSide * 2.0)
        let remainder = max(0, targetWeight - totalLoaded)

        return PlateLoadingResult(
            targetWeight: targetWeight,
            barWeight: barWeight,
            isSupported: true,
            weightPerSide: loadedPerSide,
            platesPerSide: counts,
            loadedSequence: sequence,
            loadedTotal: totalLoaded,
            remainder: remainder
        )
    }
}
