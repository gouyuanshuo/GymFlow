import SwiftUI
import UIKit

struct TrackRow: View {
    let track: ImportedTrack
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(track.artist.isEmpty ? track.originalFileName : track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if let duration = track.duration {
                Text(GymFlowFormatters.duration(duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var artwork: some View {
        if let data = track.artworkData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
        } else {
            Image(systemName: isCurrent ? "speaker.wave.2.fill" : "music.note")
                .frame(width: 36, height: 36)
                .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                .background(.fill.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
        }
    }
}
