import SwiftData
import SwiftUI

struct PlaylistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @Query(sort: \ImportedTrack.sortOrder) private var tracks: [ImportedTrack]
    @Query private var memberships: [PlaylistTrack]
    let playlist: Playlist
    @State private var trackPickerPresented = false
    @State private var renamePresented = false
    @State private var nameDraft = ""
    @State private var errorMessage: String?

    private var orderedMemberships: [PlaylistTrack] {
        PlaylistService.orderedMemberships(for: playlist.id, memberships: memberships)
    }

    private var orderedTracks: [ImportedTrack] {
        PlaylistService.orderedTracks(for: playlist.id, memberships: memberships, tracks: tracks)
    }

    private var totalDuration: TimeInterval {
        orderedTracks.compactMap(\.duration).reduce(0, +)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Button("Play", systemImage: "play.fill") { play(shuffled: false) }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    Button("Shuffle", systemImage: "shuffle") { play(shuffled: true) }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
                .disabled(orderedTracks.isEmpty)
            } footer: {
                Text(summary)
            }

            Section("Songs") {
                if orderedMemberships.isEmpty {
                    ContentUnavailableView(
                        "No Songs",
                        systemImage: "music.note",
                        description: Text("Add imported songs to this playlist.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(orderedMemberships) { membership in
                        if let track = tracks.first(where: { $0.id == membership.trackID }) {
                            Button {
                                play(track: track)
                            } label: {
                                TrackRow(track: track, isCurrent: audioPlayer.currentTrack?.id == track.id)
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button("Remove", role: .destructive) { remove(membership) }
                            }
                        }
                    }
                    .onMove(perform: move)
                }
            }
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !orderedMemberships.isEmpty { EditButton() }
                Button("Add Songs", systemImage: "plus") { trackPickerPresented = true }
                Menu("Playlist options", systemImage: "ellipsis.circle") {
                    Button("Rename", systemImage: "pencil") {
                        nameDraft = playlist.name
                        renamePresented = true
                    }
                }
            }
        }
        .sheet(isPresented: $trackPickerPresented) {
            PlaylistTrackPickerView(playlist: playlist)
        }
        .alert("Rename Playlist", isPresented: $renamePresented) {
            TextField("Playlist name", text: $nameDraft)
            Button("Save") { rename() }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Playlist Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private var summary: String {
        let count = orderedTracks.count
        guard totalDuration > 0 else { return "\(count) \(count == 1 ? "song" : "songs")" }
        return "\(count) \(count == 1 ? "song" : "songs") • \(GymFlowFormatters.duration(totalDuration))"
    }

    private func play(shuffled: Bool) {
        guard !orderedTracks.isEmpty else { return }
        audioPlayer.setQueue(
            orderedTracks,
            name: playlist.name,
            playlistID: playlist.id,
            shuffled: shuffled,
            autoplay: true
        )
    }

    private func play(track: ImportedTrack) {
        audioPlayer.setQueue(
            orderedTracks,
            name: playlist.name,
            playlistID: playlist.id,
            shuffled: false,
            startAt: track.id,
            autoplay: true
        )
    }

    private func move(from source: IndexSet, to destination: Int) {
        do {
            try PlaylistService.reorder(
                playlist: playlist,
                memberships: memberships,
                from: source,
                to: destination,
                context: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ membership: PlaylistTrack) {
        do {
            try PlaylistService.remove(membership, from: playlist, context: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rename() {
        do {
            let descriptor = FetchDescriptor<Playlist>(sortBy: [SortDescriptor(\.sortOrder)])
            let playlists = try modelContext.fetch(descriptor)
            try PlaylistService.rename(playlist, to: nameDraft, playlists: playlists, context: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
