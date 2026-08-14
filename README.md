# GymFlow

GymFlow is a private, offline-first iPhone workout companion. It combines workout planning and set-by-set logging with a resilient rest timer, immutable workout history, exercise progress, and playback of audio files imported from Files.

## Features

- Ordered workout plans using built-in or custom exercises
- Searchable, filterable exercise library with editable metadata/defaults, duplicate prevention, archive/restore, and safe custom-exercise deletion
- Target sets, repetitions, weight, rest, and exercise notes
- Focused, one-exercise-at-a-time workouts with immediate set persistence and previous-value prefill
- Deadline-based rest timer with pause, resume, skip, restart, +30 seconds, and coordinated local notifications
- Completed-session summaries, volume, history, and exercise progress
- Polished offline workout-result sharing from completion or History, with ten selectable backgrounds and sharp 4:5 image export through the native iOS share sheet
- Monthly training calendar with accessible workout-day indicators, local start-date grouping, multiple workouts per day, month navigation, and monthly totals
- Local audio import and app-owned file storage, including FLAC where AVFoundation supports the file
- Named many-to-many playlists with ordered tracks, stable shuffle queues, and repeat off/one/all
- Optional workout-plan playlist assignment and off-by-default automatic playback
- Persistent shared mini-player, full Now Playing, background audio, Control Center/Lock Screen metadata, remote commands, and interruption handling
- Interactive active-workout Live Activity and Dynamic Island controls for completing the current set, adding 30 seconds, and skipping rest
- Strong rest-complete feedback with a repeated short tone, strong haptic, and temporary GymFlow-music ducking
- Offline settings and destructive-data controls

No user accounts, cloud service, analytics, ads, subscriptions, AI, or network backend are used.

## Architecture

GymFlow is a SwiftUI application using SwiftData for persistence. Lightweight view models/workflow services own domain behavior, `ExerciseLibraryService` validates reusable definitions and synchronizes current plan-name fallbacks, and `WorkoutHistoryGrouper` performs one in-memory completed-session grouping per calendar render. Workout sharing builds an immutable, non-persisted summary from the completed-session snapshot and renders a dedicated 360 × 450 point SwiftUI card at 3× scale; no screen capture, schema change, or network is involved. `WorkoutActionService` applies idempotent set completion from both the app and Live Activity, `RestTimerService` uses deadline math, `AudioPlayerService` owns one AVFoundation player across navigation and system controls, and `AudioFileStore` owns stable local file copies. On iOS 26 the compact player uses the native tab-bar accessory; iOS 17–25 use a reserving safe-area inset. `LiveActivityManager` isolates ActivityKit lifecycle work, reconciles activities against the persisted workout on launch/foreground, and removes duplicates or orphans. Interactive controls use iOS 17 `LiveActivityIntent`, run in GymFlow's process without foregrounding its UI, and explicitly use the least restrictive `.alwaysAllowed` App Intent policy. WidgetKit still requires device authentication before third-party buttons or toggles execute on a genuinely locked Live Activity. The existing SwiftData store stays authoritative and no App Group is needed. Historical sessions keep name/value/playlist snapshots so plan or definition changes cannot rewrite history.

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

- Workout sharing passes the complete 76-test domain/render suite plus completion-and-History UI automation in Simulator, including Dark Mode and accessibility-extra-large Dynamic Type. The actual 1080 × 1350 export was inspected and the native share sheet exposed Save to Files. A signed iPhone build succeeds, but the paired iPhone 14 Pro Max was offline during final installation, so physical share-sheet destination/save inspection remains pending rather than claimed.
- Exercise Library and Calendar business logic passes 63/63 tests on the connected iPhone 14 Pro Max, and the signed app clean-builds, installs over the existing data store, and launches. The focused UI path passes in Simulator Dark Mode at standard and accessibility-extra-large text sizes. Xcode's physical UI runner timed out enabling automation mode before its first assertion, so hands-on iPhone gestures for create/edit/archive/restore, plan selection, and calendar day inspection remain a human acceptance pass rather than a claimed observation.
- First-tap plan selection, sustained in-app Now Playing controls, and history-backed Today estimates were verified on a signed iPhone 14 Pro Max build running iOS 26.6. The full Now Playing check used existing local audio and covered ten seconds of progress plus pause/resume, previous/next, shuffle, repeat, and explicit dismissal.
- The signed app and embedded interactive Live Activity extension build and install on the paired iPhone 14 Pro Max. The original 45 focused tests passed on that device; the explicit locked-action metadata regression brings the current Simulator suite to 46/46. A human must still tap the actual Lock Screen/Dynamic Island controls and judge cue/haptic intensity because XCTest cannot automate a locked system surface or evaluate sound/haptic strength.
- iOS does not deliver a guaranteed callback after a user force-quits an app. GymFlow therefore keeps a valid active workout through ordinary backgrounding, ends its activity immediately during normal finish/cancel, reconciles orphaned activities on launch/foreground, and uses an eight-hour validity/stale horizon. After force-quit, exact removal timing is controlled by iOS; an unrefreshed activity changes to an explicit “Workout status unavailable” state instead of remaining an unexplained `0:00`.
- Audio import supports unprotected local MP3, M4A, AAC, WAV, AIFF, CAF, and FLAC files playable by AVFoundation. Artist, album, and artwork metadata are not extracted during import in this release, so GymFlow uses clear text and artwork fallbacks.
- Exercise progress prioritizes accurate lists and aggregates; charts and personal-record detection are not included.
- The primary layout is portrait iPhone; iPad-specific layout is outside first-release scope.
- Local-notification delivery is subject to the user's notification authorization, Focus, Silent Mode, and system notification settings. On a genuinely locked iPhone, Apple requires authentication before third-party WidgetKit or Live Activity buttons execute, even when their App Intent policy is `.alwaysAllowed`. System Now Playing controls are privileged media controls and do not establish an exception third-party workout actions can use. GymFlow does not and cannot override this security boundary or system output volume.

No manual capability step is required by the checked-in project: the app has only the audio background mode, `NSSupportsLiveActivities` is enabled, and `GymFlowLiveActivityExtension` is embedded. For a physical iPhone, open **Signing & Capabilities** for both `GymFlow` and `GymFlowLiveActivityExtension`, select the same valid development team, pair/trust the iPhone, and run the `GymFlow` scheme. If Xcode reports that the audio mode is missing after regenerating settings, add **Background Modes** to the app target and check only **Audio, AirPlay, and Picture in Picture**.

## Roadmap

See `PLANS.md` for completed milestone status and `PROGRESS.md` for exact build/test results. The recommended next task is the remaining hands-on physical-iPhone sharing/Exercise Library/Calendar gesture pass plus the existing Lock Screen/Dynamic Island human checks, followed by optional Story-format or user-photo share backgrounds without introducing a backend.
