import SwiftUI

struct PlaybackQueueView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var audioPlayer: AudioPlayerService

    var body: some View {
        NavigationStack {
            List {
                if let queueName = audioPlayer.queueName {
                    Section {
                        LabeledContent("Playing from", value: queueName)
                    }
                }
                Section("Up Next") {
                    ForEach(audioPlayer.playlist) { track in
                        Button {
                            audioPlayer.play(track)
                            dismiss()
                        } label: {
                            TrackRow(track: track, isCurrent: audioPlayer.currentTrack?.id == track.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if audioPlayer.shuffleEnabled {
                        Button("Reshuffle", systemImage: "shuffle") { audioPlayer.reshuffle() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}
