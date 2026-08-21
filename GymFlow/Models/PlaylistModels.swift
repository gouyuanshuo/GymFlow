import Foundation
import SwiftData

@Model
final class Playlist {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
    }
}

@Model
final class PlaylistTrack {
    @Attribute(.unique) var id: UUID
    var playlistID: UUID
    var trackID: UUID
    var sortOrder: Int
    var addedAt: Date

    init(
        id: UUID = UUID(),
        playlistID: UUID,
        trackID: UUID,
        sortOrder: Int = 0,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.playlistID = playlistID
        self.trackID = trackID
        self.sortOrder = sortOrder
        self.addedAt = addedAt
    }
}
