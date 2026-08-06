import Foundation
import SwiftData

@Model
final class ImportedTrack {
    @Attribute(.unique) var id: UUID
    var title: String
    var artist: String
    var album: String?
    @Attribute(.externalStorage) var artworkData: Data?
    var storedFileName: String
    var originalFileName: String
    var fileExtension: String
    var duration: Double?
    var createdAt: Date
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        title: String,
        artist: String = "",
        album: String? = nil,
        artworkData: Data? = nil,
        storedFileName: String,
        originalFileName: String,
        fileExtension: String,
        duration: Double? = nil,
        createdAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkData = artworkData
        self.storedFileName = storedFileName
        self.originalFileName = originalFileName
        self.fileExtension = fileExtension
        self.duration = duration
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}
