import AVFoundation
import Combine
import Foundation
import MediaPlayer
import UIKit

@MainActor
final class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var playlist: [ImportedTrack] = []
    @Published private(set) var currentTrack: ImportedTrack?
    @Published private(set) var queueName: String?
    @Published private(set) var queuePlaylistID: UUID?
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var shuffleEnabled: Bool
    @Published private(set) var repeatMode: RepeatMode
    @Published var lastError: String?

    private var sourceTracks: [ImportedTrack] = []
    private var libraryByID: [UUID: ImportedTrack] = [:]
    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    private let fileStore: AudioFileStore?
    private let defaults: UserDefaults
    private let persistenceKey = "audioPlayer.playbackSnapshot"
    private var wasPlayingBeforeInterruption = false
    private var volumeBeforeAlertDuck: Float?
    private var remoteCommandTargets: [(command: MPRemoteCommand, token: Any)] = []

    override convenience init() {
        self.init(defaults: .standard)
    }

    init(defaults: UserDefaults, fileStore: AudioFileStore? = nil) {
        self.defaults = defaults
        self.fileStore = fileStore ?? (try? AudioFileStore())
        if let data = defaults.data(forKey: persistenceKey),
           let snapshot = try? JSONDecoder().decode(PlaybackSnapshot.self, from: data) {
            shuffleEnabled = snapshot.shuffleEnabled
            repeatMode = snapshot.repeatMode
        } else {
            shuffleEnabled = false
            repeatMode = .off
        }
        super.init()
        configureAudioSession()
        observeAudioSession()
        configureRemoteCommands()
    }

    deinit {
        progressTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        remoteCommandTargets.forEach { $0.command.removeTarget($0.token) }
    }

    func synchronizeLibrary(_ tracks: [ImportedTrack]) {
        libraryByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })

        if sourceTracks.isEmpty, playlist.isEmpty {
            restoreSnapshotIfAvailable()
            return
        }

        sourceTracks = sourceTracks.compactMap { libraryByID[$0.id] }
        playlist = playlist.compactMap { libraryByID[$0.id] }
        if let currentTrack, libraryByID[currentTrack.id] == nil {
            stop()
        }
        persistSnapshot()
    }

    func setQueue(
        _ tracks: [ImportedTrack],
        name: String? = nil,
        playlistID: UUID? = nil,
        shuffled: Bool = false,
        startAt trackID: UUID? = nil,
        autoplay: Bool = false
    ) {
        sourceTracks = uniqueTracks(tracks)
        queueName = name
        queuePlaylistID = playlistID
        shuffleEnabled = shuffled

        let sourceIDs = sourceTracks.map(\.id)
        let queueIDs = PlaylistEngine.makeQueue(
            sourceTrackIDs: sourceIDs,
            shuffle: shuffled,
            currentTrackID: trackID
        )
        let sourceByID = Dictionary(uniqueKeysWithValues: sourceTracks.map { ($0.id, $0) })
        playlist = queueIDs.compactMap { sourceByID[$0] }

        guard let selected = trackID.flatMap({ sourceByID[$0] }) ?? playlist.first else {
            stop()
            persistSnapshot()
            return
        }
        load(selected, autoplay: autoplay, startingAt: 0)
    }

    func setPlaylist(_ tracks: [ImportedTrack]) {
        setQueue(tracks, name: "Music Library", shuffled: false)
    }

    func play(_ track: ImportedTrack) {
        if !playlist.contains(where: { $0.id == track.id }) {
            setQueue([track], name: nil, startAt: track.id, autoplay: true)
        } else {
            load(track, autoplay: true, startingAt: 0)
        }
    }

    func togglePlayPause() {
        guard let player else {
            if let first = playlist.first { load(first, autoplay: true, startingAt: 0) }
            return
        }
        if player.isPlaying {
            pausePlayback()
        } else {
            resumePlayback()
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
        load(playlist[index], autoplay: true, startingAt: 0)
    }

    func seek(to value: TimeInterval) {
        guard let player else { return }
        player.currentTime = min(max(0, value), player.duration)
        progress = player.currentTime
        updateNowPlayingInfo()
        persistSnapshot()
    }

    func toggleShuffle() {
        shuffleEnabled.toggle()
        rebuildQueueForShuffle()
    }

    func reshuffle() {
        guard shuffleEnabled else { return }
        rebuildQueueForShuffle()
    }

    func cycleRepeatMode() {
        repeatMode = repeatMode.next
        updateNowPlayingInfo()
        persistSnapshot()
    }

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
        progressTimer = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        persistSnapshot()
    }

    func clearQueue() {
        stop()
        sourceTracks = []
        playlist = []
        queueName = nil
        queuePlaylistID = nil
        defaults.removeObject(forKey: persistenceKey)
    }

    func beginTemporaryAlertDuck() {
        guard let player, player.isPlaying else { return }
        if volumeBeforeAlertDuck == nil {
            volumeBeforeAlertDuck = player.volume
        }
        player.setVolume(0.22, fadeDuration: 0.10)
    }

    func endTemporaryAlertDuck() {
        guard let volume = volumeBeforeAlertDuck else { return }
        player?.setVolume(volume, fadeDuration: 0.16)
        volumeBeforeAlertDuck = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        advance(automatic: true)
    }

    private func load(_ track: ImportedTrack, autoplay: Bool, startingAt: TimeInterval) {
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
            newPlayer.currentTime = min(max(0, startingAt), newPlayer.duration)
            player = newPlayer
            currentTrack = track
            duration = newPlayer.duration
            progress = newPlayer.currentTime
            if autoplay {
                try AVAudioSession.sharedInstance().setActive(true)
                newPlayer.play()
                startProgressTimer()
                lastError = nil
            } else {
                progressTimer?.invalidate()
            }
            isPlaying = autoplay && newPlayer.isPlaying
            updateNowPlayingInfo()
            persistSnapshot()
        } catch {
            lastError = "\(track.title) could not be played. \(error.localizedDescription)"
        }
    }

    private func advance(automatic: Bool) {
        guard let currentTrack,
              let current = playlist.firstIndex(where: { $0.id == currentTrack.id }),
              let index = PlaylistEngine.nextIndex(
                current: current,
                count: playlist.count,
                repeatMode: repeatMode,
                automatic: automatic
              ) else {
            isPlaying = false
            progress = duration
            updateNowPlayingInfo()
            persistSnapshot()
            return
        }
        load(playlist[index], autoplay: true, startingAt: 0)
    }

    private func rebuildQueueForShuffle() {
        guard !sourceTracks.isEmpty else {
            persistSnapshot()
            return
        }
        let sourceByID = Dictionary(uniqueKeysWithValues: sourceTracks.map { ($0.id, $0) })
        let ids = PlaylistEngine.makeQueue(
            sourceTrackIDs: sourceTracks.map(\.id),
            shuffle: shuffleEnabled,
            currentTrackID: currentTrack?.id
        )
        playlist = ids.compactMap { sourceByID[$0] }
        persistSnapshot()
    }

    private func uniqueTracks(_ tracks: [ImportedTrack]) -> [ImportedTrack] {
        let ids = PlaylistEngine.stableUniqueIDs(tracks.map(\.id))
        let tracksByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        return ids.compactMap { tracksByID[$0] }
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
        updateNowPlayingInfo()
        persistSnapshot()
    }

    private func restoreSnapshotIfAvailable() {
        guard let data = defaults.data(forKey: persistenceKey),
              let snapshot = try? JSONDecoder().decode(PlaybackSnapshot.self, from: data) else { return }
        shuffleEnabled = snapshot.shuffleEnabled
        repeatMode = snapshot.repeatMode
        queueName = snapshot.queueName
        queuePlaylistID = snapshot.playlistID
        sourceTracks = snapshot.sourceTrackIDs.compactMap { libraryByID[$0] }
        playlist = snapshot.queueTrackIDs.compactMap { libraryByID[$0] }
        if let currentID = snapshot.currentTrackID, let track = libraryByID[currentID] {
            load(track, autoplay: false, startingAt: snapshot.currentTime)
        } else {
            persistSnapshot()
        }
    }

    private func persistSnapshot() {
        let snapshot = PlaybackSnapshot(
            sourceTrackIDs: sourceTracks.map(\.id),
            queueTrackIDs: playlist.map(\.id),
            currentTrackID: currentTrack?.id,
            currentTime: progress,
            queueName: queueName,
            playlistID: queuePlaylistID,
            shuffleEnabled: shuffleEnabled,
            repeatMode: repeatMode
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: persistenceKey)
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
        } catch {
            lastError = "Audio playback could not be prepared. \(error.localizedDescription)"
        }
    }

    private func pausePlayback() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
        persistSnapshot()
    }

    private func resumePlayback() {
        guard let player else {
            if let first = playlist.first { load(first, autoplay: true, startingAt: 0) }
            return
        }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            player.play()
            isPlaying = player.isPlaying
            lastError = nil
            startProgressTimer()
            updateNowPlayingInfo()
            persistSnapshot()
        } catch {
            lastError = "Audio playback could not resume. \(error.localizedDescription)"
        }
    }

    private func observeAudioSession() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        center.addObserver(
            self,
            selector: #selector(audioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: session
        )
        center.addObserver(
            self,
            selector: #selector(audioRouteChanged(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: session
        )
        center.addObserver(
            self,
            selector: #selector(audioMediaServicesReset(_:)),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: session
        )
    }

    @objc nonisolated private func audioSessionInterruption(_ notification: Notification) {
        guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else { return }
        let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        Task { @MainActor [weak self] in
            self?.processInterruption(typeValue: typeValue, optionsValue: optionsValue)
        }
    }

    private func processInterruption(typeValue: UInt, optionsValue: UInt) {
        guard let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying || player?.isPlaying == true
            player?.pause()
            isPlaying = false
            updateNowPlayingInfo()
            persistSnapshot()
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if wasPlayingBeforeInterruption && options.contains(.shouldResume) {
                resumePlayback()
            }
            wasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    @objc nonisolated private func audioRouteChanged(_ notification: Notification) {
        guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt else { return }
        Task { @MainActor [weak self] in
            guard AVAudioSession.RouteChangeReason(rawValue: reasonValue) == .oldDeviceUnavailable else { return }
            self?.pausePlayback()
        }
    }

    @objc nonisolated private func audioMediaServicesReset(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let track = currentTrack
            let time = progress
            let shouldResume = isPlaying
            configureAudioSession()
            if let track { load(track, autoplay: shouldResume, startingAt: time) }
        }
    }

    private func configureRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.isEnabled = true
        commands.pauseCommand.isEnabled = true
        commands.togglePlayPauseCommand.isEnabled = true
        commands.previousTrackCommand.isEnabled = true
        commands.nextTrackCommand.isEnabled = true
        commands.changePlaybackPositionCommand.isEnabled = true

        addRemoteTarget(to: commands.playCommand) { $0.resumePlayback() }
        addRemoteTarget(to: commands.pauseCommand) { $0.pausePlayback() }
        addRemoteTarget(to: commands.togglePlayPauseCommand) { $0.togglePlayPause() }
        addRemoteTarget(to: commands.previousTrackCommand) { $0.previous() }
        addRemoteTarget(to: commands.nextTrackCommand) { $0.next() }

        let positionToken = commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor in self?.seek(to: position) }
            return .success
        }
        remoteCommandTargets.append((commands.changePlaybackPositionCommand, positionToken))
    }

    private func addRemoteTarget(to command: MPRemoteCommand, action: @escaping @MainActor (AudioPlayerService) -> Void) {
        let token = command.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                action(self)
            }
            return .success
        }
        remoteCommandTargets.append((command, token))
    }

    private func updateNowPlayingInfo() {
        guard let currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        let info = Self.makeNowPlayingInfo(
            track: currentTrack,
            queueName: queueName,
            duration: duration,
            progress: progress,
            isPlaying: isPlaying
        )
        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = info
        center.playbackState = isPlaying ? .playing : .paused
    }

    static func makeNowPlayingInfo(
        track: ImportedTrack,
        queueName: String?,
        duration: TimeInterval,
        progress: TimeInterval,
        isPlaying: Bool
    ) -> [String: Any] {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist.isEmpty ? "GymFlow" : track.artist,
            MPMediaItemPropertyAlbumTitle: track.album ?? queueName ?? "GymFlow",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        let image = track.artworkData.flatMap(UIImage.init(data:))
            ?? UIImage(systemName: "figure.strengthtraining.traditional")
        if let image {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        return info
    }
}
