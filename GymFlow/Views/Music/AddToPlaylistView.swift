import SwiftData
import SwiftUI

struct AddToPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Playlist.sortOrder) private var playlists: [Playlist]
    @Query private var memberships: [PlaylistTrack]
    let track: ImportedTrack
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if playlists.isEmpty {
                    ContentUnavailableView(
                        "No Playlists",
                        systemImage: "music.note.list",
                        description: Text("Create a playlist from the Playlists section first.")
                    )
                } else {
                    List(playlists) { playlist in
                        Button {
                            add(to: playlist)
                        } label: {
                            HStack {
                                Label(playlist.name, systemImage: "music.note.list")
                                Spacer()
                                if containsTrack(playlist) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .disabled(containsTrack(playlist))
                    }
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .errorAlert("Playlist Error", message: $errorMessage)
        }
    }

    private func containsTrack(_ playlist: Playlist) -> Bool {
        memberships.contains { $0.playlistID == playlist.id && $0.trackID == track.id }
    }

    private func add(to playlist: Playlist) {
        do {
            try PlaylistService.add(
                trackIDs: [track.id],
                to: playlist,
                memberships: memberships,
                context: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
