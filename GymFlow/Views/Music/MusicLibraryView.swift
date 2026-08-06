import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MusicLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @Query(sort: \ImportedTrack.sortOrder) private var tracks: [ImportedTrack]
    @State private var importerPresented = false
    @State private var pendingDeletion: ImportedTrack?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if tracks.isEmpty {
                    ContentUnavailableView {
                        Label("No Imported Music", systemImage: "music.note.list")
                    } description: {
                        Text("Import unprotected MP3, M4A, AAC, WAV, AIFF, CAF, or FLAC audio from Files.")
                    } actions: {
                        Button("Import Audio", systemImage: "square.and.arrow.down") {
                            importerPresented = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section {
                            ForEach(tracks) { track in
                                Button { audioPlayer.play(track) } label: {
                                    TrackRow(track: track, isCurrent: audioPlayer.currentTrack?.id == track.id)
                                }
                                .buttonStyle(.plain)
                                .swipeActions {
                                    Button("Delete", role: .destructive) { pendingDeletion = track }
                                }
                            }
                            .onMove(perform: moveTracks)
                        } footer: {
                            Text("Only local, unprotected files are supported. Subscription music cannot be imported.")
                        }
                    }
                }
            }
            .navigationTitle("Music")
            .toolbar {
                if !tracks.isEmpty { EditButton() }
                Button("Import Audio", systemImage: "plus") { importerPresented = true }
                    .accessibilityLabel("Import local audio")
            }
            .fileImporter(
                isPresented: $importerPresented,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true,
                onCompletion: handleImport
            )
            .alert("Delete Imported Track?", isPresented: Binding(
                get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }
            )) {
                Button("Delete", role: .destructive) { deletePendingTrack() }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            } message: { Text("The copied audio file will also be deleted from GymFlow.") }
            .alert("Music Error", isPresented: Binding(
                get: { errorMessage != nil || audioPlayer.lastError != nil },
                set: {
                    if !$0 { errorMessage = nil; audioPlayer.lastError = nil }
                }
            )) { Button("OK", role: .cancel) { } } message: {
                Text(errorMessage ?? audioPlayer.lastError ?? "Unknown error")
            }
            .onAppear { audioPlayer.setPlaylist(tracks) }
            .onChange(of: tracks.map(\.id)) { _, _ in audioPlayer.setPlaylist(tracks) }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        var copiedFileNames: [String] = []
        var insertedTracks: [ImportedTrack] = []
        var activeStore: AudioFileStore?
        do {
            let urls = try result.get()
            let store = try AudioFileStore()
            activeStore = store
            var nextOrder = (tracks.map(\.sortOrder).max() ?? -1) + 1
            for url in urls {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                let imported = try store.importAudio(from: url)
                copiedFileNames.append(imported.storedFileName)
                let track = ImportedTrack(
                    title: imported.title,
                    artist: imported.artist,
                    storedFileName: imported.storedFileName,
                    originalFileName: imported.originalFileName,
                    fileExtension: imported.fileExtension,
                    duration: imported.duration,
                    sortOrder: nextOrder
                )
                insertedTracks.append(track)
                modelContext.insert(track)
                nextOrder += 1
            }
            try modelContext.save()
        } catch {
            insertedTracks.forEach(modelContext.delete)
            if let activeStore {
                copiedFileNames.forEach { try? activeStore.delete(storedFileName: $0) }
            }
            errorMessage = "The audio import did not finish. \(error.localizedDescription)"
        }
    }

    private func moveTracks(from source: IndexSet, to destination: Int) {
        var reordered = tracks
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, track) in reordered.enumerated() { track.sortOrder = index }
        do { try modelContext.save(); audioPlayer.setPlaylist(reordered) }
        catch { errorMessage = "The playlist order could not be saved. \(error.localizedDescription)" }
    }

    private func deletePendingTrack() {
        guard let track = pendingDeletion else { return }
        do {
            audioPlayer.stopIfPlaying(track)
            try AudioFileStore().delete(storedFileName: track.storedFileName)
            modelContext.delete(track)
            try modelContext.save()
            pendingDeletion = nil
        } catch {
            errorMessage = "The track could not be deleted. \(error.localizedDescription)"
        }
    }
}

private struct TrackRow: View {
    let track: ImportedTrack
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCurrent ? "speaker.wave.2.fill" : "music.note")
                .frame(width: 28)
                .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title).font(.headline).foregroundStyle(.primary)
                Text(track.artist.isEmpty ? track.originalFileName : track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if let duration = track.duration {
                Text(GymFlowFormatters.duration(duration)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 3)
    }
}

#Preview { GymFlowPreview { MusicLibraryView() } }
