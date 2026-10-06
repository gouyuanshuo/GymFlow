import Foundation

@main
enum AudioImportBenchmark {
    static func main() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "GymFlow-AudioImport-Benchmark-\(UUID().uuidString)", isDirectory: true
        )
        defer { try? fileManager.removeItem(at: root) }
        let sources = root.appendingPathComponent("Sources", isDirectory: true)
        let destination = root.appendingPathComponent("Imported", isDirectory: true)
        try fileManager.createDirectory(at: sources, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        let payload = Data(repeating: 0x52, count: 64 * 1024)
        let sourceURLs = try (0..<40).map { index -> URL in
            let source = sources.appendingPathComponent("Track \(index % 10).mp3")
            if !fileManager.fileExists(atPath: source.path) { try payload.write(to: source) }
            return source
        }
        for index in 0..<2_000 {
            let existing = destination.appendingPathComponent("Existing \(index).mp3")
            fileManager.createFile(atPath: existing.path, contents: Data())
        }

        let store = try AudioFileStore(directoryURL: destination)
        let start = ProcessInfo.processInfo.systemUptime
        #if BATCH
            let imported = try store.importAudioBatch(from: sourceURLs)
        #else
            let imported = try sourceURLs.map { try store.importAudio(from: $0) }
        #endif
        let elapsed = (ProcessInfo.processInfo.systemUptime - start) * 1_000
        precondition(imported.count == sourceURLs.count)
        precondition(Set(imported.map(\.storedFileName)).count == sourceURLs.count)
        print(
            String(
                format: "audio import: %.1f ms, %d files, 2000 existing names",
                elapsed, imported.count
            ))
    }
}
