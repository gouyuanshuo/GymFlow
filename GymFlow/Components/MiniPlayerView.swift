import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @State private var nowPlayingPresented = false

    var body: some View {
        if let track = audioPlayer.currentTrack {
            HStack(spacing: 8) {
                Button { nowPlayingPresented = true } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "music.note")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 38, height: 38)
                            .background(.tint.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text(track.artist.isEmpty ? "Imported audio" : track.artist)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .accessibilityLabel("Open Now Playing for \(track.title)")

                Button("Previous", systemImage: "backward.fill") { audioPlayer.previous() }
                    .labelStyle(.iconOnly)
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                Button(audioPlayer.isPlaying ? "Pause" : "Play", systemImage: audioPlayer.isPlaying ? "pause.fill" : "play.fill") {
                    audioPlayer.togglePlayPause()
                }
                .labelStyle(.iconOnly)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                Button("Next", systemImage: "forward.fill") { audioPlayer.next() }
                    .labelStyle(.iconOnly)
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minHeight: 56)
            .background(.thinMaterial)
            .overlay(alignment: .top) { Divider() }
            .sheet(isPresented: $nowPlayingPresented) { NowPlayingView() }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("music-mini-player")
        }
    }
}
