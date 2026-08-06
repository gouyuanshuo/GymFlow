import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @State private var nowPlayingPresented = false

    var body: some View {
        if let track = audioPlayer.currentTrack {
            HStack(spacing: 12) {
                Button { nowPlayingPresented = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "music.note")
                            .frame(width: 34, height: 34)
                            .background(.tint.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text(track.artist.isEmpty ? "Imported audio" : track.artist)
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Button("Previous", systemImage: "backward.fill") { audioPlayer.previous() }
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .frame(width: 34, height: 44)
                Button(audioPlayer.isPlaying ? "Pause" : "Play", systemImage: audioPlayer.isPlaying ? "pause.fill" : "play.fill") {
                    audioPlayer.togglePlayPause()
                }
                .labelStyle(.iconOnly)
                .font(.title3)
                .frame(width: 34, height: 44)
                Button("Next", systemImage: "forward.fill") { audioPlayer.next() }
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .frame(width: 34, height: 44)
            }
            .padding(.horizontal)
            .frame(height: 58)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
            .sheet(isPresented: $nowPlayingPresented) { NowPlayingView() }
            .accessibilityElement(children: .contain)
        }
    }
}
