import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MusicLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @Query(sort: \ImportedTrack.sortOrder) private var tracks: [ImportedTrack]
    @Query private var memberships: [PlaylistTrack]
    @State private var importerPresented = false
    @State private var pendingDeletion: ImportedTrack?
    @State private var pendingAddToPlaylist: ImportedTrack?
    @State private var errorMessage: String?
    @State private var selectedSection: MusicSection = .library
    @State private var searchText = ""
    @AppStorage("musicLibrarySort") private var sortRawValue = MusicLibrarySort.libraryOrder.rawValue

    private var sortOrder: MusicLibrarySort {
        MusicLibrarySort(rawValue: sortRawValue) ?? .libraryOrder
    }

    private var visibleTracks: [ImportedTrack] {
        let filtered = tracks.filter { track in
            searchText.isEmpty
                || track.title.localizedCaseInsensitiveContains(searchText)
                || track.artist.localizedCaseInsensitiveContains(searchText)
                || track.originalFileName.localizedCaseInsensitiveContains(searchText)
        }
        switch sortOrder {
        case .libraryOrder: return filtered.sorted { $0.sortOrder < $1.sortOrder }
        case .title: return filtered.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .artist: return filtered.sorted {
            let lhs = $0.artist.isEmpty ? $0.title : $0.artist
            let rhs = $1.artist.isEmpty ? $1.title : $1.artist
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        case .recentlyImported: return filtered.sorted { $0.createdAt > $1.createdAt }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Music Section", selection: $selectedSection) {
                    ForEach(MusicSection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 10)

                if selectedSection == .library {
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
                                    ForEach(visibleTracks) { track in
                                        let isCurrent = audioPlayer.currentTrack?.id == track.id
                                        Button {
                                            audioPlayer.setQueue(
                                                tracks.sorted { $0.sortOrder < $1.sortOrder },
                                                name: "Music Library",
                                                startAt: track.id,
                                                autoplay: true
                                            )
                                        } label: {
                                            TrackRow(track: track, isCurrent: isCurrent)
                                        }
                                        .buttonStyle(.plain)
                                        .swipeActions(edge: .leading) {
                                            Button("Add to Playlist", systemImage: "text.badge.plus") {
                                                pendingAddToPlaylist = track
                                            }
                                            .tint(.accentColor)
                                        }
                                        .swipeActions {
                                            Button("Delete", role: .destructive) { pendingDeletion = track }
                                        }
                                        .contextMenu {
                                            Button("Add to Playlist", systemImage: "text.badge.plus") {
                                                pendingAddToPlaylist = track
                                            }
                                            Button("Delete", systemImage: "trash", role: .destructive) {
                                                pendingDeletion = track
                                            }
                                        }
                                    }
                                    .onMove(perform: moveTracks)
                                    .moveDisabled(sortOrder != .libraryOrder)
                                } header: {
                                    HStack {
                                        Text("Music Library")
                                        Spacer()
                                        Menu("Sort Music", systemImage: "arrow.up.arrow.down") {
                                            ForEach(MusicLibrarySort.allCases) { option in
                                                Button {
                                                    sortRawValue = option.rawValue
                                                } label: {
                                                    if option == sortOrder {
                                                        Label(option.title, systemImage: "checkmark")
                                                    } else {
                                                        Text(option.title)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                } footer: {
                                    Text("Only local, unprotected files are supported. Subscription music cannot be imported.")
                                }
                            }
                        }
                    }
                } else {
                    PlaylistsView()
                }
            }
            .navigationTitle("Music")
            .toolbar {
                if selectedSection == .library {
                    if !tracks.isEmpty && sortOrder == .libraryOrder { EditButton() }
                    Button("Import Audio", systemImage: "plus") { importerPresented = true }
                        .accessibilityLabel("Import local audio")
                }
            }
            .searchable(text: $searchText, prompt: selectedSection == .library ? "Search songs" : "Search is available in playlists")
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
            } message: { Text("The copied audio file and all of its playlist memberships will be deleted from GymFlow.") }
            .alert("Music Error", isPresented: Binding(
                get: { errorMessage != nil || audioPlayer.lastError != nil },
                set: {
                    if !$0 { errorMessage = nil; audioPlayer.lastError = nil }
                }
            )) { Button("OK", role: .cancel) { } } message: {
                Text(errorMessage ?? audioPlayer.lastError ?? "Unknown error")
            }
            .sheet(item: $pendingAddToPlaylist) { track in
                AddToPlaylistView(track: track)
            }
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
            memberships.filter { $0.trackID == track.id }.forEach(modelContext.delete)
            try AudioFileStore().delete(storedFileName: track.storedFileName)
            modelContext.delete(track)
            try modelContext.save()
            pendingDeletion = nil
        } catch {
            errorMessage = "The track could not be deleted. \(error.localizedDescription)"
        }
    }
}

private enum MusicSection: String, CaseIterable, Identifiable {
    case library
    case playlists

    var id: String { rawValue }
    var title: String { self == .library ? "Library" : "Playlists" }
}

private enum MusicLibrarySort: String, CaseIterable, Identifiable {
    case libraryOrder
    case title
    case artist
    case recentlyImported

    var id: String { rawValue }
    var title: String {
        switch self {
        case .libraryOrder: "Playlist Order"
        case .title: "Title"
        case .artist: "Artist"
        case .recentlyImported: "Import Date"
        }
    }
}

#Preview { GymFlowPreview { MusicLibraryView() } }
