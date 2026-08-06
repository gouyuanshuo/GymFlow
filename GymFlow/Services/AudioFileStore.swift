import AVFoundation
import Foundation

enum AudioFileStoreError: LocalizedError {
    case applicationSupportUnavailable
    case sourceMissing
    case sourceUnreadable
    case unsupportedFormat(String)

    var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable: "GymFlow’s audio folder is unavailable."
        case .sourceMissing: "The selected audio file no longer exists."
        case .sourceUnreadable: "The selected audio file could not be read."
        case .unsupportedFormat(let value): "The .\(value) format is not supported for import."
        }
    }
}

struct ImportedAudioFile {
    let title: String
    let artist: String
    let storedFileName: String
    let originalFileName: String
    let fileExtension: String
    let duration: Double?
}

struct AudioFileStore {
    static let supportedExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac"]
    private let directoryURL: URL
    private let fileManager: FileManager

    init(directoryURL: URL? = nil, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            guard let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw AudioFileStoreError.applicationSupportUnavailable
            }
            self.directoryURL = support.appendingPathComponent("GymFlow/ImportedAudio", isDirectory: true)
        }
        try fileManager.createDirectory(at: self.directoryURL, withIntermediateDirectories: true)
    }

    func fileURL(for storedFileName: String) -> URL {
        directoryURL.appendingPathComponent(storedFileName, isDirectory: false)
    }

    func importAudio(from sourceURL: URL) throws -> ImportedAudioFile {
        guard fileManager.fileExists(atPath: sourceURL.path) else { throw AudioFileStoreError.sourceMissing }
        guard fileManager.isReadableFile(atPath: sourceURL.path) else { throw AudioFileStoreError.sourceUnreadable }

        let fileExtension = sourceURL.pathExtension.lowercased()
        guard Self.supportedExtensions.contains(fileExtension) else {
            throw AudioFileStoreError.unsupportedFormat(fileExtension.isEmpty ? "unknown" : fileExtension)
        }

        let storedName = Self.availableDestinationFileName(
            originalFileName: sourceURL.lastPathComponent,
            existingNames: Set((try? fileManager.contentsOfDirectory(atPath: directoryURL.path)) ?? [])
        )
        let destination = fileURL(for: storedName)
        try fileManager.copyItem(at: sourceURL, to: destination)

        let player = try? AVAudioPlayer(contentsOf: destination)
        let originalName = sourceURL.lastPathComponent
        let title = sourceURL.deletingPathExtension().lastPathComponent
        return ImportedAudioFile(
            title: title.isEmpty ? originalName : title,
            artist: "",
            storedFileName: storedName,
            originalFileName: originalName,
            fileExtension: fileExtension,
            duration: player?.duration
        )
    }

    func delete(storedFileName: String) throws {
        let url = fileURL(for: storedFileName)
        if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
    }

    static func availableDestinationFileName(originalFileName: String, existingNames: Set<String>) -> String {
        let source = URL(fileURLWithPath: originalFileName)
        let ext = source.pathExtension
        let rawStem = source.deletingPathExtension().lastPathComponent
        let sanitized = rawStem
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let stem = sanitized.isEmpty ? "Track" : sanitized
        let suffix = ext.isEmpty ? "" : ".\(ext.lowercased())"
        var candidate = "\(stem)\(suffix)"
        var counter = 2
        while existingNames.contains(candidate) {
            candidate = "\(stem)-\(counter)\(suffix)"
            counter += 1
        }
        return candidate
    }
}
