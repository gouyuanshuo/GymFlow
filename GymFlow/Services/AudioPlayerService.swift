import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var playlist: [ImportedTrack] = []
    @Published private(set) var currentTrack: ImportedTrack?
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var shuffleEnabled = false
    @Published var repeatMode: RepeatMode = .off
    @Published var lastError: String?

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    private let fileStore: AudioFileStore?

    override init() {
        fileStore = try? AudioFileStore()
        super.init()
        configureAudioSession()
    }

    deinit { progressTimer?.invalidate() }

    func setPlaylist(_ tracks: [ImportedTrack]) {
        playlist = tracks.sorted { $0.sortOrder < $1.sortOrder }
        if let currentTrack, !playlist.contains(where: { $0.id == currentTrack.id }) {
            stop()
        }
    }

    func play(_ track: ImportedTrack) {
        guard let fileStore else {
            lastError = AudioFileStoreError.applicationSupportUnavailable.localizedDescription
            return
        }
        let url = fileStore.fileURL(for: track.storedFileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            lastError = "The audio file for \(track.title) is missing."
            return
        }
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            player = newPlayer
            currentTrack = track
            duration = newPlayer.duration
            progress = 0
            newPlayer.play()
            isPlaying = true
            startProgressTimer()
        } catch {
            lastError = "\(track.title) could not be played. \(error.localizedDescription)"
        }
    }

    func togglePlayPause() {
        guard let player else {
            if let first = playlist.first { play(first) }
            return
        }
        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
            startProgressTimer()
        }
    }

    func next() { advance(automatic: false) }

    func previous() {
        guard let currentTrack,
              let current = playlist.firstIndex(where: { $0.id == currentTrack.id }) else { return }
        if progress > 3 {
            seek(to: 0)
            return
        }
        guard let index = PlaylistEngine.previousIndex(current: current, count: playlist.count) else { return }
        play(playlist[index])
    }

    func seek(to value: TimeInterval) {
        guard let player else { return }
        player.currentTime = min(max(0, value), player.duration)
        progress = player.currentTime
    }

    func cycleRepeatMode() { repeatMode = repeatMode.next }

    func stopIfPlaying(_ track: ImportedTrack) {
        if currentTrack?.id == track.id { stop() }
    }

    func stop() {
        player?.stop()
        player = nil
        currentTrack = nil
        isPlaying = false
        progress = 0
        duration = 0
        progressTimer?.invalidate()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        advance(automatic: true)
    }

    private func advance(automatic: Bool) {
        guard let currentTrack,
              let current = playlist.firstIndex(where: { $0.id == currentTrack.id }),
              let index = PlaylistEngine.nextIndex(
                current: current,
                count: playlist.count,
                shuffle: shuffleEnabled,
                repeatMode: repeatMode,
                automatic: automatic
              ) else {
            isPlaying = false
            progress = duration
            return
        }
        play(playlist[index])
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        let timer = Timer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(updateProgress),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer
    }

    @objc private func updateProgress() {
        guard let player else { return }
        progress = player.currentTime
        duration = player.duration
        isPlaying = player.isPlaying
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            lastError = "Audio playback could not be prepared. \(error.localizedDescription)"
        }
    }
}
