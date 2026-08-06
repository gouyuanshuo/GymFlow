import SwiftData
import SwiftUI

struct PlaylistTrackPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ImportedTrack.title) private var tracks: [ImportedTrack]
    @Query private var memberships: [PlaylistTrack]
    let playlist: Playlist
    @State private var selection: Set<UUID> = []
    @State private var searchText = ""
    @State private var errorMessage: String?

    private var existingTrackIDs: Set<UUID> {
        Set(memberships.filter { $0.playlistID == playlist.id }.map(\.trackID))
    }

    private var availableTracks: [ImportedTrack] {
        tracks.filter { track in
            !existingTrackIDs.contains(track.id)
                && (searchText.isEmpty
                    || track.title.localizedCaseInsensitiveContains(searchText)
                    || track.artist.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if availableTracks.isEmpty {
                    ContentUnavailableView(
                        existingTrackIDs.count == tracks.count ? "All Tracks Added" : "No Matches",
                        systemImage: "music.note",
                        description: Text(existingTrackIDs.count == tracks.count
                            ? "Every imported track is already in this playlist."
                            : "Try another search.")
                    )
                } else {
                    List(availableTracks) { track in
                        Button {
                            if selection.contains(track.id) {
                                selection.remove(track.id)
                            } else {
                                selection.insert(track.id)
                            }
                        } label: {
                            HStack {
                                TrackRow(track: track, isCurrent: false)
                                Image(systemName: selection.contains(track.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selection.contains(track.id) ? Color.accentColor : Color.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Add Songs")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search imported music")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addSelected() }
                        .fontWeight(.semibold)
                        .disabled(selection.isEmpty)
                }
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
    }

    private func addSelected() {
        do {
            let orderedIDs = tracks.filter { selection.contains($0.id) }.map(\.id)
            try PlaylistService.add(
                trackIDs: orderedIDs,
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
