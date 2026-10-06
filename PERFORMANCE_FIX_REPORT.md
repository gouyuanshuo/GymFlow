# Controlled correctness and performance fix pass

**Date:** 2026-10-06

**Source baseline:** `main` at `beb2ee850422bcc7f7c9854f9895b8e912f6f2c5`. The controlled fixes, tests, and diagnostics are in the commit containing this report. No branch was merged. Google Drive remains unmerged. No schema migration, user-store reset, or user-file deletion was performed.

The measured results below are **macOS host service timings** using the real source and an isolated, in-memory SwiftData container. They are not iPhone launch, frame, sheet, or rendering timings. Each table cell is one comparable run at that fixture size, so small differences may be noise. The fixture has 200 exercise definitions, 50 plans, and ten completed sets per session.

## Correctness Fixes

| Defect | Root cause and fix | Regression evidence |
| --- | --- | --- |
| Exercise Detail omitted a workout with an incomplete first matching `ExerciseRecord` and a completed later matching record. | Detail selected only the first matching record. It now calls `ExerciseProgressHistory.recentCompletedSessions`, which uses the existing canonical `completedSets`/`ExerciseIdentity` matching across all records. | **Executed:** standalone benchmark's duplicate-entry assertion failed against the old API and passes after the change. **Typechecked test source:** `ExerciseProgressHistoryTests` covers duplicate entries, renamed stable IDs, normalized legacy names, and incomplete-only sessions. Native test execution is pending. |
| Reset Sample Plans could leave user plans deleted after seeding failed. | The old path saved deletion before reseeding. The replacement plans and built-in reconciliation are prepared first, then deletion and insertion are saved together. On failure the reset mutations roll back. Unrelated pending context edits are saved before this reset transaction so rollback does not discard them. Defaults advance only after success. Existing definition UUIDs and workout history remain intact. | **Executed:** `DataSafetyRegression` reproduced preparation/save failures against the old path, then passed preparation failure, save failure, pending-edit preservation, and successful reset identity/history checks against the new path. **Typechecked test source:** `DataSafetyTests`. |
| Failed finish/cancel lost the active rest deadline and notification. | Rest cancellation happened before the session save. `WorkoutFinalizationService` saves the status/completion change first, restores those fields if save fails, and cancels rest only after success. | **Executed:** disposable fault-injection checks for failed and successful finish/cancel passed; failed paths kept the deadline, persisted timer state, and notification. **Typechecked test source:** `DataSafetyTests`. |

All disposable SwiftData checks use isolated containers and defaults. The host emitted a nonfatal CoreData store-change notification-registration message; the checks exited 0. The main app's tests have not executed in this environment.

## Performance Before / After

| Operation | 500 before | 500 after | 1,000 before | 1,000 after | 2,000 before | 2,000 after | Improvement at 2,000 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Exercise Detail PB | 138.93 ms | 9.07 ms | 276.72 ms | 17.39 ms | 547.33 ms | 33.40 ms | about 94% |
| Workout prefill, matching plan | 1.81 ms | 1.45 ms | 2.76 ms | 2.32 ms | 3.87 ms | 3.45 ms | about 11%; too small to establish beyond run variance |
| Absent-exercise prefill, five sets | 24.87 ms | 5.54 ms | 49.31 ms | 11.13 ms | 99.39 ms | 21.65 ms | about 78% |
| Share summary | 242.86 ms | 13.53 ms | 511.23 ms | 27.36 ms | 1,034.44 ms | 54.21 ms | about 95% |

The PB row measures the same Exercise Detail result, but its work boundary changed: **before** timed `summary` over an already fetched all-history array; **after** times a store candidate fetch **plus** that summary. This makes the after figure conservative for that operation. The unfiltered service still needs roughly 517 ms at 2,000 sessions; the gain depends on Exercise Detail using the bounded query. The query admits matching stable IDs and all ID-less legacy candidates, then the unchanged `ExerciseIdentity` matcher performs normalized-name filtering. An executed query check includes renamed and legacy history while excluding an unrelated same-name ID. Exercise Detail now uses this candidate set for PB, recent history, and its history-use guard. Plans are still checked separately before deletion.

Share summary reads target-session totals/highlights locally, then asks the canonical `ExercisePerformanceService` for PR events. Its history index now derives set metrics only for identities present in the shared workout and traverses prior sessions once for those identities. The existing working-set eligibility, Epley estimate, weight/volume/repetition comparisons, and event logic remain the only calculation rules. A deterministic executed check passed stable-ID rename, legacy fallback, unrelated same-name ID exclusion, best weight/reps/volume/e1RM, and current-workout PR type/highlight expectations.

Prefill still chooses the newest usable completed set for each set number. It now scans history **once per planned exercise**, filling all target numbers during that pass, rather than scanning every session once per target set. Executed assertions passed older-valid fallback, multiple sets, renamed stable ID, legacy fallback, and no-history target values. Typechecked tests also cover duplicate records within one workout, warm-ups, invalid values, and incomplete records.

The benchmark output still exposes another cost: its intentionally unbounded `exercise progress scan` reached 484.29 ms at 2,000 sessions when the PB path no longer warmed every relationship first. That separate Progress path was outside this controlled pass and remains a scaling risk. The table does not claim a whole-screen or iPhone improvement.

## Timer Changes

- **Rest:** the service still samples its deadline about every 0.25 seconds. It now publishes `remainingSeconds` only when the displayed whole second changes. A real-source probe measured **3 publications for 3 same-second refreshes before**, **0 after**, and exactly one when the visible second changed. Pause, +30, resume, persisted reload, and skip assertions passed. Deadline and notification scheduling semantics were kept.
- **Audio:** the 0.5-second progress timer now stops on pause, stop, queue end, and interruption; resume and natural next-track loading start it when playback is running. Each tick assigns progress, duration, and `isPlaying` only when changed, and refreshes Now Playing metadata only when one of those values changed. A paused position no longer has an active progress timer. The new paused/end-of-track publication test is **typechecked source only** because native tests could not execute; Lock Screen controls, shuffle, and transition behavior require a device run. The audio session still sets category `.playback` without `.allowAirPlay`.
- **Observation:** `ContentView` no longer observes playback progress. Narrow child views own library synchronization and the global mini-player; `ActiveWorkoutView` leaves audio observation to its mini-player and a tiny rest-alert installer. Its workout body still updates for the visible rest countdown. `MusicLibraryView` still broadly observes audio state; no safe smaller boundary was established in this pass. SwiftUI body invalidation was not measured with Instruments here.

## Import Changes

The file importer now puts destination directory enumeration, security-scoped source access, file copying, and `AVAudioPlayer` duration probing in a detached task. The source URL remains security-scoped through its copy, and files are processed in selection order. One directory listing and an in-memory name set replace a listing for each file. `ImportedTrack` insertion and `ModelContext.save()` stay on the main actor. The Import button rejects overlapping import callbacks; a failed batch removes only copies made by that batch and reports the error. Re-selecting the same source later still creates a uniquely named copy, preserving existing behavior.

**Executed:** a synthetic host case with 40 small files and 2,000 existing names measured a 258.8 ms baseline median and 120.9 ms post-change median in the focused import benchmark; a fresh post-change run measured 124.1 ms. The executed import regression passed ordered names, collision handling, no overwrite, and failed-batch cleanup. Large-file and multi-file UI responsiveness on a physical iPhone is unverified.

## Data Safety Changes

Sample reset stages new plans and reconciliation, saves the reset once, and rolls back staged changes on failure. It neither deletes retained workout sessions nor replaces matching `ExerciseDefinition` identities. A successful finish/cancel persists the session first, then ends rest; a failed save preserves the active rest deadline and its scheduled notification. These paths were checked only with disposable contexts and injected failures, never against the user's store.

## Build / Test Result

### Executed tests and benchmarks

The DEBUG-only `Diagnostics/DeepAuditBenchmark.swift` was compiled against the real model/service/utility sources using:

```bash
xcrun swiftc -O -D DEBUG -swift-version 5 -o /tmp/GymFlowFixFinalBenchmark \
  Diagnostics/DeepAuditBenchmark.swift \
  GymFlow/Models/ExerciseDefinition.swift GymFlow/Models/WorkoutPlan.swift \
  GymFlow/Models/PlannedExercise.swift GymFlow/Models/WorkoutSession.swift \
  GymFlow/Models/ExerciseRecord.swift GymFlow/Models/WorkoutSetRecord.swift \
  GymFlow/Models/WorkoutSessionStatus.swift GymFlow/Models/ImportedTrack.swift \
  GymFlow/Models/PlaylistModels.swift GymFlow/Models/ExerciseIdentity.swift \
  GymFlow/Models/WorkoutShareSummary.swift GymFlow/Services/ExerciseLibraryService.swift \
  GymFlow/Services/ExercisePerformanceService.swift GymFlow/Services/WorkoutService.swift \
  GymFlow/Utilities/Validation.swift GymFlow/Utilities/Formatters.swift \
  GymFlow/Utilities/ExerciseProgressHistory.swift GymFlow/Utilities/WorkoutHistoryGrouper.swift
/tmp/GymFlowFixFinalBenchmark 500
/tmp/GymFlowFixFinalBenchmark 1000
/tmp/GymFlowFixFinalBenchmark 2000
```

Compile and all three executions exited **0**; the table reports their exact named operations. The pre-change executable used the same real-source list, fixture, and scales (`/tmp/GymFlowFixBaselineBenchmark`, all exit 0). `DataSafetyRegression`, `AudioImportRegression`, and `RestTimerPublicationProbe --assert-optimized` each executed and exited **0**. The audio import benchmark compiled and ran with `xcrun swiftc -O -D BATCH -swift-version 5 GymFlow/Services/AudioFileStore.swift Diagnostics/AudioImportBenchmark.swift -o /tmp/GymFlowFixAudioImportBenchmark` followed by `/tmp/GymFlowFixAudioImportBenchmark` (both exit 0).

Exact final focused executable commands (each compile and run exited **0**):

```bash
xcrun swiftc -D DEBUG -swift-version 5 -o /tmp/GymFlowFixDataSafetyRegression \
  Diagnostics/DataSafetyRegression.swift GymFlow/Services/SampleDataSeeder.swift \
  GymFlow/Services/WorkoutFinalizationService.swift GymFlow/Services/RestTimerService.swift \
  GymFlow/Services/RestTimerStorage.swift GymFlow/Services/RestTimerNotificationScheduler.swift \
  GymFlow/Services/ExerciseLibraryService.swift GymFlow/Models/WorkoutPlan.swift \
  GymFlow/Models/PlannedExercise.swift GymFlow/Models/ExerciseDefinition.swift \
  GymFlow/Models/WorkoutSession.swift GymFlow/Models/ExerciseRecord.swift \
  GymFlow/Models/WorkoutSetRecord.swift GymFlow/Models/WorkoutSessionStatus.swift \
  GymFlow/Models/ExerciseIdentity.swift GymFlow/Utilities/Validation.swift
/tmp/GymFlowFixDataSafetyRegression
xcrun swiftc -D DEBUG -swift-version 5 -o /tmp/GymFlowFixRestPublicationProbe \
  Diagnostics/RestTimerPublicationProbe.swift GymFlow/Services/RestTimerService.swift \
  GymFlow/Services/RestTimerStorage.swift GymFlow/Services/RestTimerNotificationScheduler.swift
/tmp/GymFlowFixRestPublicationProbe --assert-optimized
xcrun swiftc -swift-version 5 -o /tmp/GymFlowFixAudioImportRegression \
  Diagnostics/AudioImportRegression.swift GymFlow/Services/AudioFileStore.swift
/tmp/GymFlowFixAudioImportRegression
```

### Typechecked test source and static checks

The complete app/shared source emitted a testable iOS Simulator Swift module, then **every** `GymFlowTests/*.swift` source typechecked against it; the extension/shared and `GymFlowUITests/*.swift` sources also typechecked (all exit **0**). This does **not** mean those tests executed. The app Swift 5 strict-concurrency typecheck exited **0** with future Swift 6 warnings, including the existing `AVAudioPlayerDelegate` actor-isolation warning and predicate macro key-path warnings. `xcrun swift-format lint --recursive --parallel GymFlow GymFlowActivityShared GymFlowLiveActivityExtension GymFlowTests GymFlowUITests Diagnostics` exited **0** with layout warnings and no semantic failure. Strict lint on the new benchmark/query/prefill/data-safety files exited **0**; `git diff --check` exited **0**.

The exact module and test-source checks were:

```bash
rg --files -0 GymFlow GymFlowActivityShared -g '*.swift' | xargs -0 xcrun swiftc -target arm64-apple-ios17.0-simulator -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.5.sdk -swift-version 5 -D DEBUG -enable-testing -emit-module -module-name GymFlow -emit-module-path /tmp/GymFlowFixModule/GymFlow.swiftmodule
xcrun swiftc -target arm64-apple-ios17.0-simulator -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.5.sdk -swift-version 5 -typecheck -module-name GymFlowTests -I /tmp/GymFlowFixModule -I /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/usr/lib -F /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks -plugin-path /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing GymFlowTests/*.swift
rg --files -0 GymFlowLiveActivityExtension GymFlowActivityShared -g '*.swift' | xargs -0 xcrun swiftc -target arm64-apple-ios17.0-simulator -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.5.sdk -swift-version 5 -typecheck
xcrun swiftc -target arm64-apple-ios17.0-simulator -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.5.sdk -swift-version 5 -typecheck -module-name GymFlowUITests -I /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/usr/lib -F /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks GymFlowUITests/*.swift
```

### Native build/test gate

```bash
xcrun simctl list devices available
xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -sdk iphonesimulator -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/GymFlowFixFinalDerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -destination 'platform=iOS Simulator,id=21B83D30-D504-4457-8F13-DFAA4A933BE3' -derivedDataPath /tmp/GymFlowFixFinalDerivedData CODE_SIGNING_ALLOWED=NO test
```

`simctl` exited **72** because CoreSimulatorService refused the connection. Both `xcodebuild` commands exited **134 before project compilation/test discovery**, reporting FSEvents startup failure and a `DARWIN_USER_CACHE_DIR` I/O error. The `GymFlow` main scheme was used; the Live Activity extension was not used as a host app. **No current native app, unit, or UI test passed or failed because none executed.**

## Remaining Unverified Risks and Physical-Device Checklist

The next acceptance pass should use a real iPhone with representative history and imported music, record screen timings and main-thread traces, and keep the existing data intact:

1. Open Exercise Detail for an exercise with long history; verify PB/recent values and capture first-open latency.
2. Open Share Preview for a completed workout; capture presentation latency and verify current totals/PR.
3. Press Share, render the 1179 × 2556 image, open/dismiss the sheet, and record latency and memory. This pass did not change high-resolution rendering.
4. Start a workout with no history; verify target weights/reps and start latency.
5. Start a workout with long history, including an older valid set behind a newer incomplete set; verify every prefill and start latency.
6. Run rest countdown through pause, resume, +30, skip, background, and screen lock; check displayed seconds and notification timing.
7. Run rest and music together; confirm alert sound/haptic, duck/restore, mini-player, and no visible workout stutter.
8. Pause and resume music repeatedly; check progress, queue continuity, and no idle timer wakeups.
9. Import several large files from Files; verify responsive UI, order, collision names, security-scope access, and visible errors.
10. Finish and cancel workouts during active rest; verify saved session, cleared rest notification, and appropriate Live Activity end. A real persistence failure remains impractical to induce on user data.
11. Lock the screen during playback; verify Now Playing elapsed time, play/pause, next/previous, shuffle/playlist continuity, and the absence of OSStatus -50.
12. Exercise Live Activity controls and lock/resume during a workout; verify rest deadline, set completion, +30/skip, and final dismissal.

Also profile `ExerciseProgressView` with a long history and observe `MusicLibraryView` during progress ticks. No claim is made here about frame rate, memory retention, physical-device audio import latency, SwiftUI invalidation counts, background delivery, or iPhone performance.
