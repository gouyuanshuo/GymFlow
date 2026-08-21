import SwiftData
import SwiftUI

struct PlaylistsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Playlist.sortOrder) private var playlists: [Playlist]
    @Query private var memberships: [PlaylistTrack]
    @Query private var plans: [WorkoutPlan]
    @State private var nameEditorPresented = false
    @State private var editingPlaylist: Playlist?
    @State private var nameDraft = ""
    @State private var pendingDeletion: Playlist?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if playlists.isEmpty {
                ContentUnavailableView {
                    Label("No Playlists", systemImage: "music.note.list")
                } description: {
                    Text("Create a playlist, then add any imported songs you want.")
                } actions: {
                    Button("Create Playlist", systemImage: "plus") { presentCreate() }
                        .buttonStyle(.borderedProminent)
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(playlists) { playlist in
                        NavigationLink {
                            PlaylistDetailView(playlist: playlist)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(playlist.name).font(.headline)
                                Text("\(trackCount(for: playlist)) songs")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) { pendingDeletion = playlist }
                        }
                        .contextMenu {
                            Button("Rename", systemImage: "pencil") { presentRename(playlist) }
                            Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(playlist) }
                            Button("Delete", systemImage: "trash", role: .destructive) { pendingDeletion = playlist }
                        }
                    }
                } header: {
                    HStack {
                        Text("Your Playlists")
                        Spacer()
                        Button("Create", systemImage: "plus") { presentCreate() }
                            .font(.caption.weight(.semibold))
                    }
                }
            }
        }
        .alert(editingPlaylist == nil ? "New Playlist" : "Rename Playlist", isPresented: $nameEditorPresented) {
            TextField("Playlist name", text: $nameDraft)
            Button("Save") { saveName() }
            Button("Cancel", role: .cancel) { clearNameEditor() }
        } message: {
            Text("Choose a short, recognizable name.")
        }
        .confirmationDialog(
            "Delete this playlist?",
            isPresented: $pendingDeletion.isPresent(),
            titleVisibility: .visible
        ) {
            Button("Delete Playlist", role: .destructive) { deletePending() }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("Imported audio files will remain in your music library.")
        }
        .errorAlert("Playlist Error", message: $errorMessage)
    }

    private func trackCount(for playlist: Playlist) -> Int {
        memberships.filter { $0.playlistID == playlist.id }.count
    }

    private func presentCreate() {
        editingPlaylist = nil
        nameDraft = ""
        nameEditorPresented = true
    }

    private func presentRename(_ playlist: Playlist) {
        editingPlaylist = playlist
        nameDraft = playlist.name
        nameEditorPresented = true
    }

    private func clearNameEditor() {
        editingPlaylist = nil
        nameDraft = ""
    }

    private func saveName() {
        do {
            if let editingPlaylist {
                try PlaylistService.rename(editingPlaylist, to: nameDraft, playlists: playlists, context: modelContext)
            } else {
                try PlaylistService.create(name: nameDraft, playlists: playlists, context: modelContext)
            }
            clearNameEditor()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func duplicate(_ playlist: Playlist) {
        do {
            try PlaylistService.duplicate(
                playlist,
                playlists: playlists,
                memberships: memberships,
                context: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deletePending() {
        guard let playlist = pendingDeletion else { return }
        do {
            try PlaylistService.delete(
                playlist,
                memberships: memberships,
                assignedPlans: plans,
                context: modelContext
            )
            pendingDeletion = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
