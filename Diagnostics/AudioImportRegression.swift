import Foundation

@main
enum AudioImportRegression {
    static func main() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "GymFlow-AudioImport-Regression-\(UUID().uuidString)", isDirectory: true
        )
        defer { try? fileManager.removeItem(at: root) }
        let sources = root.appendingPathComponent("Sources", isDirectory: true)
        let destination = root.appendingPathComponent("Imported", isDirectory: true)
        try fileManager.createDirectory(at: sources, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        let source = sources.appendingPathComponent("Song.MP3")
        let missing = sources.appendingPathComponent("Missing.mp3")
        let existing = destination.appendingPathComponent("Song.mp3")
        try Data([0, 1, 2]).write(to: source)
        try Data([3, 4, 5]).write(to: existing)

        let store = try AudioFileStore(directoryURL: destination)
        let imported = try store.importAudioBatch(from: [source, source])
        precondition(imported.map(\.storedFileName) == ["Song-2.mp3", "Song-3.mp3"])
        precondition(imported.map(\.originalFileName) == ["Song.MP3", "Song.MP3"])
        let preservedBeforeFailure = try Data(contentsOf: existing)
        precondition(preservedBeforeFailure == Data([3, 4, 5]))

        do {
            _ = try store.importAudioBatch(from: [source, missing])
            preconditionFailure("The missing source should fail the batch")
        } catch AudioFileStoreError.sourceMissing {
            precondition(!fileManager.fileExists(atPath: store.fileURL(for: "Song-4.mp3").path))
            let preservedAfterFailure = try Data(contentsOf: existing)
            precondition(preservedAfterFailure == Data([3, 4, 5]))
        }
        print("PASS: ordered names, no overwrite, and failed-batch cleanup")
    }
}
