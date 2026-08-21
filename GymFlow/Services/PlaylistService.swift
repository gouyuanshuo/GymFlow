import Foundation
import SwiftData
import SwiftUI

enum PlaylistError: LocalizedError, Equatable {
    case emptyName
    case duplicateName

    var errorDescription: String? {
        switch self {
        case .emptyName: "Playlist name cannot be empty."
        case .duplicateName: "A playlist with this name already exists."
        }
    }
}

@MainActor
enum PlaylistService {
    static func validatedName(
        _ name: String,
        excluding playlistID: UUID? = nil,
        playlists: [Playlist]
    ) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PlaylistError.emptyName }
        guard !playlists.contains(where: {
            $0.id != playlistID && $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }) else { throw PlaylistError.duplicateName }
        return trimmed
    }

    @discardableResult
    static func create(
        name: String,
        playlists: [Playlist],
        context: ModelContext,
        now: Date = Date()
    ) throws -> Playlist {
        let validated = try validatedName(name, playlists: playlists)
        let playlist = Playlist(
            name: validated,
            createdAt: now,
            updatedAt: now,
            sortOrder: (playlists.map(\.sortOrder).max() ?? -1) + 1
        )
        context.insert(playlist)
        try context.save()
        return playlist
    }

    static func rename(
        _ playlist: Playlist,
        to name: String,
        playlists: [Playlist],
        context: ModelContext,
        now: Date = Date()
    ) throws {
        playlist.name = try validatedName(name, excluding: playlist.id, playlists: playlists)
        playlist.updatedAt = now
        try context.save()
    }

    @discardableResult
    static func duplicate(
        _ playlist: Playlist,
        playlists: [Playlist],
        memberships: [PlaylistTrack],
        context: ModelContext,
        now: Date = Date()
    ) throws -> Playlist {
        var candidate = "\(playlist.name) Copy"
        var suffix = 2
        while playlists.contains(where: {
            $0.name.localizedCaseInsensitiveCompare(candidate) == .orderedSame
        }) {
            candidate = "\(playlist.name) Copy \(suffix)"
            suffix += 1
        }
        let copy = try create(name: candidate, playlists: playlists, context: context, now: now)
        for entry in orderedMemberships(for: playlist.id, memberships: memberships) {
            context.insert(PlaylistTrack(
                playlistID: copy.id,
                trackID: entry.trackID,
                sortOrder: entry.sortOrder,
                addedAt: now
            ))
        }
        try context.save()
        return copy
    }

    static func delete(
        _ playlist: Playlist,
        memberships: [PlaylistTrack],
        assignedPlans: [WorkoutPlan] = [],
        context: ModelContext
    ) throws {
        assignedPlans.filter { $0.assignedPlaylistID == playlist.id }.forEach {
            $0.assignedPlaylistID = nil
            $0.updatedAt = Date()
        }
        memberships.filter { $0.playlistID == playlist.id }.forEach(context.delete)
        context.delete(playlist)
        try context.save()
    }

    static func add(
        trackIDs: [UUID],
        to playlist: Playlist,
        memberships: [PlaylistTrack],
        context: ModelContext,
        now: Date = Date()
    ) throws {
        let current = memberships.filter { $0.playlistID == playlist.id }
        let existing = Set(current.map(\.trackID))
        var nextOrder = (current.map(\.sortOrder).max() ?? -1) + 1
        for trackID in trackIDs where !existing.contains(trackID) {
            context.insert(PlaylistTrack(
                playlistID: playlist.id,
                trackID: trackID,
                sortOrder: nextOrder,
                addedAt: now
            ))
            nextOrder += 1
        }
        playlist.updatedAt = now
        try context.save()
    }

    static func remove(
        _ membership: PlaylistTrack,
        from playlist: Playlist,
        context: ModelContext,
        now: Date = Date()
    ) throws {
        context.delete(membership)
        playlist.updatedAt = now
        try context.save()
    }

    static func reorder(
        playlist: Playlist,
        memberships: [PlaylistTrack],
        from source: IndexSet,
        to destination: Int,
        context: ModelContext,
        now: Date = Date()
    ) throws {
        var ordered = orderedMemberships(for: playlist.id, memberships: memberships)
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, membership) in ordered.enumerated() { membership.sortOrder = index }
        playlist.updatedAt = now
        try context.save()
    }

    /// A playlist's entries in playback order, ties broken by when the track was added.
    static func orderedMemberships(
        for playlistID: UUID,
        memberships: [PlaylistTrack]
    ) -> [PlaylistTrack] {
        memberships.filter { $0.playlistID == playlistID }.sorted {
            $0.sortOrder == $1.sortOrder ? $0.addedAt < $1.addedAt : $0.sortOrder < $1.sortOrder
        }
    }

    /// A playlist's tracks in playback order, skipping entries whose track no longer exists.
    static func orderedTracks(
        for playlistID: UUID,
        memberships: [PlaylistTrack],
        tracks: [ImportedTrack]
    ) -> [ImportedTrack] {
        let tracksByID = Dictionary(tracks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return orderedMemberships(for: playlistID, memberships: memberships)
            .compactMap { tracksByID[$0.trackID] }
    }
}
