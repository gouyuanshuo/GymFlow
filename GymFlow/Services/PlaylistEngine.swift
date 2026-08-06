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

struct PlaybackSnapshot: Codable, Equatable {
    var sourceTrackIDs: [UUID]
    var queueTrackIDs: [UUID]
    var currentTrackID: UUID?
    var currentTime: TimeInterval
    var queueName: String?
    var playlistID: UUID?
    var shuffleEnabled: Bool
    var repeatMode: RepeatMode
}

enum PlaylistEngine {
    static func stableUniqueIDs(_ ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return ids.filter { seen.insert($0).inserted }
    }

    static func makeQueue(
        sourceTrackIDs: [UUID],
        shuffle: Bool,
        currentTrackID: UUID? = nil,
        shuffler: ([UUID]) -> [UUID] = { $0.shuffled() }
    ) -> [UUID] {
        let unique = stableUniqueIDs(sourceTrackIDs)
        guard shuffle else { return unique }
        guard let currentTrackID, unique.contains(currentTrackID) else { return shuffler(unique) }
        return [currentTrackID] + shuffler(unique.filter { $0 != currentTrackID })
    }

    static func nextIndex(current: Int, count: Int, repeatMode: RepeatMode, automatic: Bool) -> Int? {
        guard count > 0, current >= 0, current < count else { return nil }
        if automatic && repeatMode == .one { return current }
        let candidate = current + 1
        if candidate < count { return candidate }
        return repeatMode == .all ? 0 : nil
    }

    static func previousIndex(current: Int, count: Int) -> Int? {
        guard count > 0, current >= 0, current < count else { return nil }
        return current == 0 ? count - 1 : current - 1
    }
}
