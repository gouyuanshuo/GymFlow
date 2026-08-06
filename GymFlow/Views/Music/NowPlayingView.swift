import SwiftUI

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var audioPlayer: AudioPlayerService

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()
                Image(systemName: "music.note")
                    .font(.system(size: 70))
                    .frame(width: 220, height: 220)
                    .foregroundStyle(.tint)
                    .background(.tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(spacing: 6) {
                    Text(audioPlayer.currentTrack?.title ?? "Nothing Playing")
                        .font(.title2.bold()).multilineTextAlignment(.center)
                    Text(audioPlayer.currentTrack?.artist.isEmpty == false
                        ? audioPlayer.currentTrack?.artist ?? ""
                        : "Imported audio")
                    .foregroundStyle(.secondary)
                }

                VStack(spacing: 6) {
                    Slider(value: Binding(
                        get: { audioPlayer.progress },
                        set: { audioPlayer.seek(to: $0) }
                    ), in: 0...max(1, audioPlayer.duration))
                    .accessibilityLabel("Playback position")
                    HStack {
                        Text(GymFlowFormatters.duration(audioPlayer.progress))
                        Spacer()
                        Text(GymFlowFormatters.duration(audioPlayer.duration))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 40) {
                    Button("Previous", systemImage: "backward.fill") { audioPlayer.previous() }
                    Button(audioPlayer.isPlaying ? "Pause" : "Play", systemImage: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill") {
                        audioPlayer.togglePlayPause()
                    }
                    .font(.system(size: 56))
                    Button("Next", systemImage: "forward.fill") { audioPlayer.next() }
                }
                .labelStyle(.iconOnly)
                .font(.title)

                HStack(spacing: 64) {
                    Button("Shuffle", systemImage: "shuffle") { audioPlayer.shuffleEnabled.toggle() }
                        .foregroundStyle(audioPlayer.shuffleEnabled ? Color.accentColor : Color.secondary)
                    Button("Repeat \(audioPlayer.repeatMode.title)", systemImage: audioPlayer.repeatMode.systemImage) {
                        audioPlayer.cycleRepeatMode()
                    }
                    .foregroundStyle(audioPlayer.repeatMode == .off ? Color.secondary : Color.accentColor)
                }
                .labelStyle(.iconOnly)
                .font(.title2)
                Spacer()
            }
            .padding(.horizontal, 28)
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
