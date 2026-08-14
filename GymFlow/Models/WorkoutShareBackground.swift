import SwiftUI

enum WorkoutShareBackground: String, CaseIterable, Identifiable {
    case obsidian
    case electricBlue
    case velocityRed
    case ultraviolet
    case graphite
    case solarFlare
    case midnightGrid
    case arctic
    case evergreen
    case blackGold

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .obsidian: "Obsidian"
        case .electricBlue: "Electric Blue"
        case .velocityRed: "Velocity Red"
        case .ultraviolet: "Ultraviolet"
        case .graphite: "Graphite"
        case .solarFlare: "Solar Flare"
        case .midnightGrid: "Midnight Grid"
        case .arctic: "Arctic"
        case .evergreen: "Evergreen"
        case .blackGold: "Black Gold"
        }
    }

    var foregroundColor: Color {
        self == .arctic ? Color(red: 0.04, green: 0.08, blue: 0.14) : .white
    }

    var secondaryForegroundColor: Color {
        self == .arctic
            ? Color(red: 0.17, green: 0.25, blue: 0.34)
            : Color.white.opacity(0.72)
    }

    var panelColor: Color {
        self == .arctic ? Color.white.opacity(0.62) : Color.black.opacity(0.23)
    }

    var separatorColor: Color {
        self == .arctic ? Color.black.opacity(0.12) : Color.white.opacity(0.16)
    }
}

struct WorkoutShareBackgroundSelection: Equatable {
    let available: [WorkoutShareBackground]
    private(set) var selected: WorkoutShareBackground

    init(
        available: [WorkoutShareBackground] = WorkoutShareBackground.allCases,
        initialIndex: Int
    ) {
        let safeAvailable = available.isEmpty ? [.obsidian] : available
        self.available = safeAvailable
        self.selected = safeAvailable[Self.normalized(initialIndex, count: safeAvailable.count)]
    }

    mutating func select(_ background: WorkoutShareBackground) {
        guard available.contains(background) else { return }
        selected = background
    }

    mutating func randomize(index: Int) {
        let alternatives = available.filter { $0 != selected }
        guard !alternatives.isEmpty else { return }
        selected = alternatives[Self.normalized(index, count: alternatives.count)]
    }

    private static func normalized(_ index: Int, count: Int) -> Int {
        let remainder = index % count
        return remainder >= 0 ? remainder : remainder + count
    }
}
