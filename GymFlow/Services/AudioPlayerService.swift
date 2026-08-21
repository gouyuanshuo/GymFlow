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
    private var alertDuckRestoreTask: Task<Void, Never>?
    private var lastSnapshotPersistedAt = Date.distantPast
    private var remoteCommandTargets: [(command: MPRemoteCommand, token: Any)] = []

    /// Volume the music ducks to while a rest-timer alert plays.
    private static let alertDuckVolume: Float = 0.22
    private static let alertDuckFadeDuration: TimeInterval = 0.10
    private static let alertRestoreFadeDuration: TimeInterval = 0.16
    /// How often the resume snapshot is written while a track plays. The progress timer ticks far
    /// more often than this; persisting every tick would encode and write to disk thousands of
    /// times per workout for a value that only needs coarse accuracy on resume.
    private static let snapshotPersistenceInterval: TimeInterval = 5

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

    /// Applies a new library ordering without disturbing playback.
    ///
    /// Reordering rows in the library is a presentation change, so it must not stop the current
    /// track, rename the queue, or reset shuffle. Only an unshuffled queue follows the new order;
    /// a shuffled queue keeps its own sequence.
    func updateLibraryOrder(_ tracks: [ImportedTrack]) {
        let ordered = uniqueTracks(tracks)
        let orderedIDs = Set(ordered.map(\.id))
        guard Set(sourceTracks.map(\.id)) == orderedIDs else { return }

        sourceTracks = ordered
        guard !shuffleEnabled else {
            persistSnapshot()
            return
        }
        playlist = ordered
        persistSnapshot()
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
        // Capture the pre-duck volume only once per duck cycle. A second alert arriving while the
        // previous restore fade is still running would otherwise record the interpolated mid-fade
        // level as the "original", permanently lowering the user's music.
        if volumeBeforeAlertDuck == nil {
            volumeBeforeAlertDuck = player.volume
        }
        alertDuckRestoreTask?.cancel()
        alertDuckRestoreTask = nil
        player.setVolume(Self.alertDuckVolume, fadeDuration: Self.alertDuckFadeDuration)
    }

    func endTemporaryAlertDuck() {
        guard let volume = volumeBeforeAlertDuck else { return }
        player?.setVolume(volume, fadeDuration: Self.alertRestoreFadeDuration)
        // Hold the captured volume until the fade actually lands, so an overlapping duck restores
        // to the true original rather than to a value sampled mid-fade.
        alertDuckRestoreTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.alertRestoreFadeDuration))
            guard !Task.isCancelled else { return }
            self?.volumeBeforeAlertDuck = nil
            self?.alertDuckRestoreTask = nil
        }
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
        persistSnapshotThrottled()
    }

    /// Writes the resume snapshot at most once per `snapshotPersistenceInterval`.
    ///
    /// Only `progress` changes between progress-timer ticks, and a resume position is useful at
    /// coarse accuracy, so the encode-and-write does not need to run on every tick. Discrete
    /// events (seek, pause, track change) still call `persistSnapshot()` directly.
    private func persistSnapshotThrottled() {
        let now = Date()
        guard now.timeIntervalSince(lastSnapshotPersistedAt) >= Self.snapshotPersistenceInterval else {
            return
        }
        lastSnapshotPersistedAt = now
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
        lastSnapshotPersistedAt = Date()
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
