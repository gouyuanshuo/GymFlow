import Foundation

enum RepeatMode: String, CaseIterable, Codable {
    case off
    case one
    case all

    var title: String {
        switch self {
        case .off: "Off"
        case .one: "One"
        case .all: "All"
        }
    }

    var systemImage: String { self == .one ? "repeat.1" : "repeat" }

    var next: RepeatMode {
        switch self {
        case .off: .one
        case .one: .all
        case .all: .off
        }
    }
}

enum PlaylistEngine {
    static func nextIndex(
        current: Int,
        count: Int,
        shuffle: Bool,
        repeatMode: RepeatMode,
        automatic: Bool,
        randomIndex: (Range<Int>) -> Int = { Int.random(in: $0) }
    ) -> Int? {
        guard count > 0, current >= 0, current < count else { return nil }
        if automatic && repeatMode == .one { return current }
        if shuffle, count > 1 {
            let candidate = randomIndex(0..<(count - 1))
            return candidate >= current ? candidate + 1 : candidate
        }
        let candidate = current + 1
        if candidate < count { return candidate }
        return repeatMode == .all || !automatic ? 0 : nil
    }

    static func previousIndex(current: Int, count: Int) -> Int? {
        guard count > 0, current >= 0, current < count else { return nil }
        return current == 0 ? count - 1 : current - 1
    }
}
