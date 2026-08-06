# GymFlow

GymFlow is a private, offline-first iPhone workout companion. It combines workout planning and set-by-set logging with a resilient rest timer, immutable workout history, exercise progress, and playback of audio files imported from Files.

## Features

- Ordered workout plans using built-in or custom exercises
- Target sets, repetitions, weight, rest, and exercise notes
- Restorable active workouts with immediate set persistence
- Deadline-based rest timer with pause, resume, skip, restart, and +30 seconds
- Completed-session summaries, volume, history, and exercise progress
- Local audio import, app-owned file storage, playlist controls, shuffle, and repeat
- Persistent shared mini-player and Now Playing screen
- Offline settings and destructive-data controls

No user accounts, cloud service, analytics, ads, subscriptions, AI, or network backend are used.

## Architecture

GymFlow is a SwiftUI application using SwiftData for persistence. Lightweight view models/workflow services own domain behavior, `RestTimerService` uses deadline math, `AudioPlayerService` owns one AVFoundation player across navigation, and `AudioFileStore` owns stable local file copies. Historical sessions keep name/value snapshots so plan changes cannot rewrite history.

## Project structure

```text
GymFlow/
  App/          Application root and shared state
  Models/       SwiftData entities and domain value types
  Views/        Feature screens
  ViewModels/   Screen/workflow state
  Services/     Seeding, workout, timer, audio, and file services
  Components/   Reusable SwiftUI controls
  Utilities/    Validation, formatting, and calculations
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

- Background playback is configured through the playback audio session and `UIBackgroundModes`; lock-screen/Control Center metadata and remote commands are not part of this release.
- Audio is intentionally limited to unprotected local files supported by AVFoundation. Artist metadata is not extracted in this release, so GymFlow displays a clear fallback when it is unavailable.
- Exercise progress prioritizes accurate lists and aggregates; charts and personal-record detection are not included.
- The primary layout is portrait iPhone; iPad-specific layout is outside first-release scope.
- Timer completion feedback uses an in-app system sound/haptic and is not a scheduled local notification while the app is terminated.

No manual background-audio capability step is required by the current project configuration. Running on a physical iPhone still requires selecting a valid development team/signing identity in Xcode.

## Roadmap

See `PLANS.md` for completed milestone status and `PROGRESS.md` for exact build/test results. The recommended next release task is lock-screen/Control Center media integration, followed by richer progress charts, without introducing a backend.
