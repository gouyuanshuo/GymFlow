import AVFoundation
import Foundation
import MediaPlayer
import SwiftData
import Testing
@testable import GymFlow

@MainActor
struct GymFlowTests {
    @Test("Workout volume only includes completed sets")
    func workoutVolumeCalculation() {
        let completed = WorkoutSetRecord(setNumber: 1, weight: 60, repetitions: 8, isCompleted: true)
        let incomplete = WorkoutSetRecord(setNumber: 2, weight: 100, repetitions: 10)
        let secondCompleted = WorkoutSetRecord(setNumber: 3, weight: 20, repetitions: 12, isCompleted: true)
        let record = ExerciseRecord(exerciseNameSnapshot: "Bench", sets: [completed, incomplete, secondCompleted])
        let session = WorkoutSession(planNameSnapshot: "Test", status: .completed, exerciseRecords: [record])

        #expect(session.trainingVolume == 720)
        #expect(session.totalRepetitions == 20)
        #expect(session.completedSetCount == 2)
    }

    @Test("Plan duplication creates an independent deep copy")
    func planDuplication() {
        let exercise = PlannedExercise(
            exerciseNameSnapshot: "Squat",
            targetSets: 4,
            targetRepetitions: 8,
            targetWeight: 80,
            restSeconds: 180
        )
        let playlistID = UUID()
        let original = WorkoutPlan(
            name: "Legs",
            notes: "Original",
            assignedPlaylistID: playlistID,
            exercises: [exercise]
        )
        let copy = WorkoutService.duplicate(plan: original, now: Date(timeIntervalSince1970: 100))

        #expect(copy.id != original.id)
        #expect(copy.name == "Legs Copy")
        #expect(copy.exercises.count == 1)
        #expect(copy.exercises[0].id != exercise.id)
        #expect(copy.exercises[0].targetWeight == 80)
        #expect(copy.assignedPlaylistID == playlistID)

        copy.exercises[0].targetWeight = 100
        #expect(original.exercises[0].targetWeight == 80)
    }

    @Test("A workout session is created from ordered plan targets")
    func workoutSessionCreation() {
        let later = PlannedExercise(
            exerciseNameSnapshot: "Row",
            targetSets: 2,
            targetRepetitions: 12,
            targetWeight: 30,
            restSeconds: 75,
            sortOrder: 1
        )
        let first = PlannedExercise(
            exerciseNameSnapshot: "Pulldown",
            targetSets: 3,
            targetRepetitions: 10,
            targetWeight: 55,
            restSeconds: 120,
            sortOrder: 0
        )
        let plan = WorkoutPlan(name: "Back", exercises: [later, first])
        let start = Date(timeIntervalSince1970: 1_000)

        let playlist = Playlist(name: "Back Day")
        let session = WorkoutService.makeSession(from: plan, playlist: playlist, now: start)

        #expect(session.workoutPlanID == plan.id)
        #expect(session.planNameSnapshot == "Back")
        #expect(session.status == .active)
        #expect(session.startedAt == start)
        #expect(session.currentExerciseIndex == 0)
        #expect(session.currentSetNumber == 1)
        #expect(session.playlistID == playlist.id)
        #expect(session.playlistNameSnapshot == "Back Day")
        #expect(session.orderedExerciseRecords.map(\.exerciseNameSnapshot) == ["Pulldown", "Row"])
        #expect(session.orderedExerciseRecords[0].sets.count == 3)
        #expect(session.orderedExerciseRecords[0].orderedSets[0].weight == 55)
        #expect(session.orderedExerciseRecords[0].orderedSets[0].repetitions == 10)
    }

    @Test("New sessions prefill the latest completed set and retain target fallbacks")
    func workoutSessionPreviousValuePrefill() {
        let exerciseID = UUID()
        let planned = PlannedExercise(
            exerciseID: exerciseID,
            exerciseNameSnapshot: "Bench Press",
            targetSets: 2,
            targetRepetitions: 8,
            targetWeight: 60
        )
        let plan = WorkoutPlan(name: "Chest", exercises: [planned])
        let previousRecord = ExerciseRecord(
            exerciseID: exerciseID,
            exerciseNameSnapshot: "Bench Press",
            sets: [
                WorkoutSetRecord(
                    setNumber: 1,
                    weight: 72.5,
                    repetitions: 6,
                    isCompleted: true
                ),
                WorkoutSetRecord(setNumber: 2, weight: 70, repetitions: 7)
            ]
        )
        let previous = WorkoutSession(
            planNameSnapshot: "Chest",
            startedAt: Date(timeIntervalSince1970: 500),
            status: .completed,
            exerciseRecords: [previousRecord]
        )

        let session = WorkoutService.makeSession(from: plan, previousSessions: [previous])
        let sets = session.orderedExerciseRecords[0].orderedSets
        #expect(sets[0].weight == 72.5)
        #expect(sets[0].repetitions == 6)
        #expect(sets[1].weight == 60)
        #expect(sets[1].repetitions == 8)
    }

    @Test("Historical snapshots survive plan changes")
    func historySnapshotsRemainValid() {
        let planned = PlannedExercise(exerciseNameSnapshot: "Bench Press", targetWeight: 60)
        let plan = WorkoutPlan(name: "Chest", exercises: [planned])
        let session = WorkoutService.makeSession(from: plan)

        plan.name = "Renamed Plan"
        planned.exerciseNameSnapshot = "Renamed Exercise"
        planned.targetWeight = 90

        #expect(session.planNameSnapshot == "Chest")
        #expect(session.orderedExerciseRecords[0].exerciseNameSnapshot == "Bench Press")
        #expect(session.orderedExerciseRecords[0].orderedSets[0].weight == 60)
    }

    @Test("Rest timer remaining time uses a deadline and rounds up")
    func restTimerRemainingTime() {
        let now = Date(timeIntervalSince1970: 1_000)
        #expect(RestTimerService.remaining(until: now.addingTimeInterval(30), now: now) == 30)
        #expect(RestTimerService.remaining(until: now.addingTimeInterval(0.2), now: now) == 1)
        #expect(RestTimerService.remaining(until: now.addingTimeInterval(-5), now: now) == 0)
    }

    @Test("Rest timer restores paused state and uses elapsed wall time")
    func restTimerPersistenceAndRecovery() {
        let suiteName = "GymFlowTests.RestTimer.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated UserDefaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let start = Date(timeIntervalSince1970: 1_000)
        let running = RestTimerService(defaults: defaults, keyPrefix: "testTimer")
        running.start(duration: 120, now: start)
        running.refresh(now: start.addingTimeInterval(40))
        #expect(running.remainingSeconds == 80)

        running.pause(now: start.addingTimeInterval(40))
        let restored = RestTimerService(defaults: defaults, keyPrefix: "testTimer")
        #expect(restored.isPaused)
        #expect(restored.remainingSeconds == 80)

        restored.resume(now: start.addingTimeInterval(100))
        restored.refresh(now: start.addingTimeInterval(130))
        #expect(restored.remainingSeconds == 50)
    }

    @Test("Rest timer migrates an interrupted workout from the legacy storage key")
    func restTimerStorageMigration() {
        let suiteName = "GymFlowTests.RestTimerMigration.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated UserDefaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let start = Date(timeIntervalSince1970: 1_000)
        let legacy = RestTimerService(defaults: defaults, keyPrefix: "restTimer")
        legacy.start(duration: 90, now: start)
        legacy.pause(now: start.addingTimeInterval(20))

        let restored = RestTimerService(
            defaults: defaults,
            keyPrefix: "restTimer.session-id",
            migrationKeyPrefix: "restTimer"
        )
        #expect(restored.isPaused)
        #expect(restored.remainingSeconds == 70)
        #expect(defaults.object(forKey: "restTimer.pausedRemaining") == nil)
        #expect(defaults.integer(forKey: "restTimer.session-id.pausedRemaining") == 70)
    }

    @Test("Audio destinations do not overwrite existing imports")
    func audioFileDestinationNaming() {
        let existing: Set<String> = ["Workout Mix.mp3", "Workout Mix-2.mp3"]
        let name = AudioFileStore.availableDestinationFileName(
            originalFileName: "Workout Mix.MP3",
            existingNames: existing
        )
        #expect(name == "Workout Mix-3.mp3")
        #expect(AudioFileStore.availableDestinationFileName(
            originalFileName: "New Song.m4a",
            existingNames: existing
        ) == "New Song.m4a")
    }

    @Test("Playlist CRUD preserves shared imported tracks and ordering")
    func playlistManagement() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ImportedTrack.self, Playlist.self, PlaylistTrack.self,
            WorkoutPlan.self, PlannedExercise.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let first = ImportedTrack(
            title: "First",
            storedFileName: "first.mp3",
            originalFileName: "first.mp3",
            fileExtension: "mp3"
        )
        let second = ImportedTrack(
            title: "Second",
            storedFileName: "second.mp3",
            originalFileName: "second.mp3",
            fileExtension: "mp3"
        )
        context.insert(first)
        context.insert(second)

        let playlist = try PlaylistService.create(name: "Training", playlists: [], context: context)
        let assignedPlan = WorkoutPlan(name: "Assigned", assignedPlaylistID: playlist.id)
        context.insert(assignedPlan)
        try PlaylistService.add(
            trackIDs: [second.id, first.id],
            to: playlist,
            memberships: [],
            context: context
        )
        let memberships = try context.fetch(FetchDescriptor<PlaylistTrack>())
        #expect(PlaylistService.orderedTracks(
            for: playlist.id,
            memberships: memberships,
            tracks: [first, second]
        ).map(\.title) == ["Second", "First"])

        let copy = try PlaylistService.duplicate(
            playlist,
            playlists: [playlist],
            memberships: memberships,
            context: context
        )
        let membershipsAfterCopy = try context.fetch(FetchDescriptor<PlaylistTrack>())
        #expect(copy.name == "Training Copy")
        #expect(membershipsAfterCopy.filter { $0.playlistID == copy.id }.count == 2)

        try PlaylistService.delete(
            playlist,
            memberships: membershipsAfterCopy,
            assignedPlans: [assignedPlan],
            context: context
        )
        #expect(try context.fetchCount(FetchDescriptor<ImportedTrack>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<Playlist>()) == 1)
        #expect(assignedPlan.assignedPlaylistID == nil)
    }

    @Test("Playlist names are validated")
    func playlistValidation() throws {
        #expect(throws: PlaylistError.emptyName) {
            try PlaylistService.validatedName("  ", playlists: [])
        }
        let existing = Playlist(name: "Cardio")
        #expect(throws: PlaylistError.duplicateName) {
            try PlaylistService.validatedName("cardio", playlists: [existing])
        }
    }

    @Test("FLAC is accepted as a supported local audio format")
    func flacImportSupport() {
        #expect(AudioFileStore.supportedExtensions.contains("flac"))
        #expect(AudioFileStore.availableDestinationFileName(
            originalFileName: "Workout Mix.FLAC",
            existingNames: []
        ) == "Workout Mix.flac")
    }

    @Test("A FLAC file can be copied and decoded")
    func flacFileImportAndDecode() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GymFlow-FLAC-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("Test Track.FLAC")
        try writeSilentFLAC(to: source)

        let destination = root.appendingPathComponent("Imported", isDirectory: true)
        let store = try AudioFileStore(directoryURL: destination)
        let imported = try store.importAudio(from: source)

        #expect(imported.fileExtension == "flac")
        #expect(imported.storedFileName == "Test Track.flac")
        #expect(imported.duration != nil)
        #expect(FileManager.default.fileExists(atPath: store.fileURL(for: imported.storedFileName).path))
    }

    @Test("Audio service creates complete Now Playing metadata")
    func nowPlayingMetadata() {
        let track = ImportedTrack(
            title: "Control Center",
            artist: "GymFlow Tests",
            album: "Integration",
            storedFileName: "control-center.flac",
            originalFileName: "Control Center.flac",
            fileExtension: "flac",
            duration: 180
        )
        let info = AudioPlayerService.makeNowPlayingInfo(
            track: track,
            queueName: "Test Queue",
            duration: 180,
            progress: 42,
            isPlaying: true
        )
        #expect(info[MPMediaItemPropertyTitle] as? String == "Control Center")
        #expect(info[MPMediaItemPropertyArtist] as? String == "GymFlow Tests")
        #expect(info[MPMediaItemPropertyAlbumTitle] as? String == "Integration")
        #expect(info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval == 42)
        #expect(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 1)
        #expect(info[MPMediaItemPropertyArtwork] is MPMediaItemArtwork)
    }

    @Test("Live Activity state is compact and round-trips")
    func liveActivityPayload() throws {
        let state = WorkoutActivityAttributes.ContentState(
            exerciseName: "Barbell Bench Press",
            currentSet: 3,
            totalSets: 4,
            completedExercises: 1,
            totalExercises: 5,
            workoutStartDate: Date(timeIntervalSince1970: 1_000),
            restEndDate: Date(timeIntervalSince1970: 1_180),
            pausedRestSeconds: 0,
            restComplete: false
        )
        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(
            WorkoutActivityAttributes.ContentState.self,
            from: data
        )
        #expect(restored == state)
        #expect(data.count < 4_096)
    }

    private func writeSilentFLAC(to url: URL) throws {
        let sampleRate = 44_100.0
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatFLAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_410) else {
            throw CocoaError(.fileWriteUnknown)
        }
        buffer.frameLength = 4_410
        try file.write(from: buffer)
    }

    @Test("Playlist navigation handles boundaries and repeat")
    func playlistNextAndPrevious() {
        #expect(PlaylistEngine.nextIndex(
            current: 0, count: 3, repeatMode: .off, automatic: true
        ) == 1)
        #expect(PlaylistEngine.nextIndex(
            current: 2, count: 3, repeatMode: .off, automatic: true
        ) == nil)
        #expect(PlaylistEngine.nextIndex(
            current: 2, count: 3, repeatMode: .all, automatic: true
        ) == 0)
        #expect(PlaylistEngine.previousIndex(current: 0, count: 3) == 2)
        #expect(PlaylistEngine.previousIndex(current: 2, count: 3) == 1)
    }

    @Test("Playlist repeat-one and deterministic shuffle are testable")
    func shuffleAndRepeatLogic() {
        #expect(PlaylistEngine.nextIndex(
            current: 1, count: 4, repeatMode: .one, automatic: true
        ) == 1)
        let ids = (0..<4).map { _ in UUID() }
        let shuffled = PlaylistEngine.makeQueue(
            sourceTrackIDs: ids,
            shuffle: true,
            currentTrackID: ids[1],
            shuffler: { $0.reversed() }
        )
        #expect(shuffled == [ids[1], ids[3], ids[2], ids[0]])
        #expect(Set(shuffled).count == ids.count)
        #expect(RepeatMode.off.next == .one)
        #expect(RepeatMode.one.next == .all)
        #expect(RepeatMode.all.next == .off)
    }

    @Test("Playback snapshot preserves queue context")
    func playbackSnapshotPersistence() throws {
        let ids = [UUID(), UUID(), UUID()]
        let snapshot = PlaybackSnapshot(
            sourceTrackIDs: ids,
            queueTrackIDs: [ids[1], ids[2], ids[0]],
            currentTrackID: ids[2],
            currentTime: 42.5,
            queueName: "Workout",
            playlistID: UUID(),
            shuffleEnabled: true,
            repeatMode: .all
        )
        let encoded = try JSONEncoder().encode(snapshot)
        let restored = try JSONDecoder().decode(PlaybackSnapshot.self, from: encoded)
        #expect(restored == snapshot)
    }

    @Test("Validation rejects invalid plan and target values")
    func validationRules() {
        #expect(throws: ValidationError.emptyPlanName) {
            try InputValidator.validatePlanName("  \n")
        }
        #expect(throws: ValidationError.emptyExerciseName) {
            try InputValidator.validateExerciseName("")
        }
        #expect(throws: ValidationError.invalidSetCount) {
            try InputValidator.validate(sets: 0, repetitions: 10, weight: 10, restSeconds: 60)
        }
        #expect(throws: ValidationError.negativeRepetitions) {
            try InputValidator.validate(sets: 1, repetitions: -1, weight: 10, restSeconds: 60)
        }
        #expect(throws: ValidationError.negativeWeight) {
            try InputValidator.validate(sets: 1, repetitions: 1, weight: -0.1, restSeconds: 60)
        }
        #expect(throws: ValidationError.negativeRestTime) {
            try InputValidator.validate(sets: 1, repetitions: 1, weight: 0, restSeconds: -1)
        }
    }
}
