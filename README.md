# GymFlow

GymFlow is a private, offline-first iPhone workout companion. It combines workout planning and set-by-set logging with a resilient rest timer, immutable workout history, exercise progress, and playback of audio files imported from Files.

## Features

- Ordered workout plans using built-in or custom exercises
- Target sets, repetitions, weight, rest, and exercise notes
- Focused, one-exercise-at-a-time workouts with immediate set persistence and previous-value prefill
- Deadline-based rest timer with pause, resume, skip, restart, and +30 seconds
- Completed-session summaries, volume, history, and exercise progress
- Local audio import and app-owned file storage, including FLAC where AVFoundation supports the file
- Named many-to-many playlists with ordered tracks, stable shuffle queues, and repeat off/one/all
- Optional workout-plan playlist assignment and off-by-default automatic playback
- Persistent shared mini-player, full Now Playing, background audio, Control Center/Lock Screen metadata, remote commands, and interruption handling
- Active-workout Live Activity and Dynamic Island presentation on supported iPhones
- Offline settings and destructive-data controls

No user accounts, cloud service, analytics, ads, subscriptions, AI, or network backend are used.

## Architecture

GymFlow is a SwiftUI application using SwiftData for persistence. Lightweight view models/workflow services own domain behavior, `RestTimerService` uses deadline math, `AudioPlayerService` owns one AVFoundation player across navigation and system controls, and `AudioFileStore` owns stable local file copies. On iOS 26 the compact player uses the native tab-bar accessory; iOS 17–25 use a reserving safe-area inset. `LiveActivityManager` isolates ActivityKit lifecycle work, reconciles activities against the persisted workout on launch/foreground, and removes duplicates or orphans. Historical sessions keep name/value/playlist snapshots so plan changes cannot rewrite history.

## Project structure

```text
GymFlow/
  Models/       SwiftData entities and domain value types
  Views/        Feature screens
  ViewModels/   Screen/workflow state
  Services/     Seeding, workout, timer, audio, and file services
  Components/   Reusable SwiftUI controls
  Utilities/    Validation, formatting, and calculations
GymFlowActivityShared/          Shared ActivityKit attributes
GymFlowLiveActivityExtension/   Lock Screen and Dynamic Island widget UI
GymFlowTests/   Deterministic unit tests
GymFlowUITests/ Critical-path UI smoke tests
```

The Xcode project uses file-system synchronized groups, so new Swift files under these folders are discovered automatically.

## Open and run

1. Open `GymFlow.xcodeproj` in Xcode 26.6 or newer.
2. Select the `GymFlow` scheme.
3. Choose an installed iPhone simulator or a signed iPhone.
4. Build and run. The deployment target is iOS 17.0.

Compile from Terminal:

```bash
xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -sdk iphonesimulator -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/GymFlowDerivedData CODE_SIGNING_ALLOWED=NO build
```

## Tests

List available destinations, then choose a simulator UDID:

```bash
xcrun simctl list devices available
xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -destination 'platform=iOS Simulator,id=<DEVICE-UDID>' -derivedDataPath /tmp/GymFlowDerivedData CODE_SIGNING_ALLOWED=NO test
```

## Current limitations

- Background audio, Now Playing metadata, remote commands, and the embedded Live Activity extension compile and install in Simulator, but Lock Screen, Bluetooth, call interruption, and Dynamic Island behavior still require acceptance testing on a paired physical iPhone.
- iOS does not deliver a guaranteed callback after a user force-quits an app. GymFlow therefore keeps a valid active workout through ordinary backgrounding, ends its activity immediately during normal finish/cancel, reconciles orphaned activities on launch/foreground, and uses an eight-hour validity/stale horizon. After force-quit, exact removal timing is controlled by iOS; an unrefreshed activity changes to an explicit “Workout status unavailable” state instead of remaining an unexplained `0:00`.
- Audio import supports unprotected local MP3, M4A, AAC, WAV, AIFF, CAF, and FLAC files playable by AVFoundation. Artist, album, and artwork metadata are not extracted during import in this release, so GymFlow uses clear text and artwork fallbacks.
- Exercise progress prioritizes accurate lists and aggregates; charts and personal-record detection are not included.
- The primary layout is portrait iPhone; iPad-specific layout is outside first-release scope.
- Timer completion feedback uses an in-app system sound/haptic and is not a scheduled local notification while the app is terminated.

No manual capability step is required by the checked-in project: the app has only the audio background mode, `NSSupportsLiveActivities` is enabled, and `GymFlowLiveActivityExtension` is embedded. For a physical iPhone, open **Signing & Capabilities** for both `GymFlow` and `GymFlowLiveActivityExtension`, select the same valid development team, pair/trust the iPhone, and run the `GymFlow` scheme. If Xcode reports that the audio mode is missing after regenerating settings, add **Background Modes** to the app target and check only **Audio, AirPlay, and Picture in Picture**.

## Roadmap

See `PLANS.md` for completed milestone status and `PROGRESS.md` for exact build/test results. The recommended next task is a physical-iPhone acceptance pass for background audio, interruptions, remote controls, and Live Activities, followed by richer metadata extraction or progress charts without introducing a backend.
