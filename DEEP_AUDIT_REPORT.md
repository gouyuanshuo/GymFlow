# GymFlow deep bug, regression, performance, memory, and concurrency audit

**Audit date:** 2026-10-06 (Australia/Sydney)

**Current source:** `main` at `beb2ee850422bcc7f7c9854f9895b8e912f6f2c5`
**Scope:** diagnosis and isolated test data only. No production source, user store, or branch was changed.

## Verdict and evidence scale

The most expensive operation actually measured was **share-summary construction**, followed by **Exercise Detail Personal Best computation**. In a standalone optimized macOS executable using the real GymFlow SwiftData models and services, an isolated in-memory store with 500 / 1,000 / 2,000 sessions (5,000 / 10,000 / 20,000 sets) took **246 / 504 / 1,046 ms** to construct the last session's share summary and **135 / 277 / 551 ms** to calculate one exercise's PB summary. These are service timings on this Mac with constructed in-memory objects, **not** iPhone tap-to-render or cold-disk timings. The nearly linear growth shows that history size matters despite the app's prior build and test results.

The current command environment cannot launch the app: the clean `GymFlow` build and both Xcode test targets exit 134 before compilation or test discovery; CoreSimulator exits 72. `devicectl` exits 134. Consequently, **no current-HEAD iPhone or simulator flow, SwiftUI Instruments trace, Memory Graph, Main Thread Checker, or Thread Sanitizer result is claimed**. The code-level mechanisms below are identified as such. One logic defect was reproduced with real model code in an isolated executable. All user-facing latencies and leak claims remain open until a runnable host is available.

Evidence labels used here:

- **Measured:** timed real service/model code with the isolated benchmark; one run per scale after recompilation.
- **Reproduced:** deterministic real-model mismatch in the benchmark.
- **Code-confirmed:** a direct call path, query, timer, or ordering visible in current source; runtime severity remains unmeasured.
- **Hypothesis:** plausible user symptom requiring device or simulator observation.

## 0. Recorded state and change lineage

Read before diagnostics: `AGENTS.md`, `PROJECT_SPEC.md`, `PLANS.md`, `PROGRESS.md`, `AUDIT_REPORT.md`, `README.md`, and both 2026-09-30 release-stabilization design/plan documents. At audit start, `git status --short --branch` showed `main...origin/main` and only the pre-existing untracked `Screenshot 2026-08-06 at 5.03.28 pm.png`. `git branch --show-current` was `main`; `git rev-parse HEAD` was `beb2ee8...`; `git worktree list` showed the root worktree only; `git stash list` was empty. The screenshot was not opened, moved, or changed. The audit adds only this report and `Diagnostics/DeepAuditBenchmark.swift`, plus a short milestone note in `PLANS.md` and `PROGRESS.md`.

`git log --oneline --decorate -30`, `git branch -a`, and `git diff --stat 847c672..HEAD` were inspected. Since the previous release-readiness audit at `847c672`, stabilization landed as `8050fb3` identity-safe sample reset, `602a440` contextual share heading, `56e631e` canonical e1RM, `203e3ea` backward set prefill, `86e0c14` explicit schema V1, and `6c60209` warm-up exclusion, followed by release metadata and publication documentation (`2dd2605`, `beb2ee8`). UI modernization had already merged before the previous audit; no later UI-modernization code change appears in this interval. The local `feature/google-drive-exercise-guides` is **unmerged**: `git merge-base main feature/google-drive-exercise-guides` returned `ffef63d...`, and `git rev-list --left-right --count main...feature/google-drive-exercise-guides` returned `32 11`. No Google Drive runtime source is in `main`; Drive cannot cause current-main performance or be exercised in its UI.

### Recent-fix regression assessment

| Change | Current audit result |
|---|---|
| `203e3ea` prefill | Correctness fix is present, but it calls a backward session scan **for each target set**. A missing exercise took 24 / 50 / 98 ms at 500 / 1,000 / 2,000 sessions on the host. This is a measurable scaling cost newly added to Start Workout; a device stall is unverified. |
| `8050fb3` sample reset | Definition identity is preserved in source. The reset still saves plan deletions before reseeding; if reseeding fails, plans remain deleted. This failure window also existed in the old Settings implementation, so it is an **unresolved pre-existing safety defect**, not a proven new regression. Do not reproduce against user data. |
| `602a440` share wording | Same-day/historical heading policy is present. Preview and export each capture their own `Date()`, so an open preview crossing local midnight could disagree with its export. This is an unobserved edge case. |
| `56e631e`, `6c60209` e1RM/working sets | Current source delegates e1RM to one policy and excludes warm-ups in progress; no new defect was established by this audit. Native execution remains blocked. |
| `86e0c14` schema V1 | No destructive fallback found. Existing disk fixture covers a small implicit store shape, not a future V1→V2 migration or a real user store. No regression was demonstrated. |

## 1. Fresh baseline verification

All commands ran in the repository on this HEAD. The **main `GymFlow` scheme** was used, never `GymFlowLiveActivityExtension` as a host app.

| Command | Fresh result |
|---|---|
| `xcrun simctl list devices available` | Exit **72**. CoreSimulatorService lookup refused connection, POSIX 61. No installed destination could be selected from this context. |
| `xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -sdk iphonesimulator -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/GymFlowDeepAuditDerivedData CODE_SIGNING_ALLOWED=NO clean build` | Exit **134 before compilation**. Xcode logged `DVTFilePathFSEvents: Failed to start fs event stream` and `confstr(DARWIN_USER_CACHE_DIR)` I/O error. This is neither a passing nor a failing app compile. |
| `xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/GymFlowDeepAuditUnitDerivedData -parallel-testing-enabled NO -only-testing:GymFlowTests CODE_SIGNING_ALLOWED=NO test` | Exit **134 before discovery**; 0 unit tests executed. The named destination was an attempted fallback, not a verified installed device. |
| Same command with `/tmp/GymFlowDeepAuditUIDerivedData` and `-only-testing:GymFlowUITests` | Exit **134 before discovery**; 0 UI tests executed. |
| `xcrun swift-format lint --recursive --parallel GymFlow GymFlowActivityShared GymFlowLiveActivityExtension GymFlowTests GymFlowUITests` | Exit **0** with the project's existing layout warnings; no semantic-rule error. |
| Direct `xcrun swiftc` iOS Simulator SDK Swift 5 `-typecheck -D DEBUG` of every `GymFlow` and shared Swift file | Exit **0**; warned that `AudioPlayerService: AVAudioPlayerDelegate` crosses main actor isolation and would be an error in Swift 6 mode. |
| Direct iOS Simulator SDK `-typecheck` of extension/shared files | Exit **0**. |
| Direct app/shared `-emit-module -enable-testing` followed by typecheck of all `GymFlowTests` and all `GymFlowUITests` sources | All **exit 0**; source compatibility only, no linking or execution. |
| Swift 5 `-strict-concurrency=complete` app/shared typecheck | Exit **0** with additional future Swift 6 warnings, including mutable static App Intent properties, non-Sendable `Binding` capture, key-path/SwiftData usage, and audio delegate isolation. It is not a Swift 6 build. |
| `xcrun devicectl list devices` | Exit **134**; no device run. |
| `xcrun xctrace list templates` | Exit **0**, including SwiftUI, Time Profiler, Allocations, Leaks, and Swift Concurrency templates. Recording requires a runnable app target, unavailable here. |
| `gh auth status`; `gh workflow list` | Exit **1**; the configured GitHub token is invalid and `api.github.com` could not be reached. The tracked `.github/workflows/ios-validation.yml` cannot be dispatched from this context. No standalone hosted/test shell script is tracked. |

The prior hosted run `36574065094` and earlier signed-device result in `PROGRESS.md` predate the stabilization code. They are historical evidence only. The currently blocked Xcode commands executed **0** current unit and UI cases.

## 2. Reproduction matrix

`UNVERIFIED` means the physical flow could not run at this HEAD; it does **not** mean a pass. `BUG` below means a deterministic isolated logic reproduction, not a visual device test. The first thing to do on a runnable host is execute this matrix with a disposable store, record signposts and video, and keep the real user store untouched.

| Area | Flow(s) | Status on current HEAD | Reproduction or diagnostic target |
|---|---|---|---|
| App startup | Cold launch, warm launch, background return, screen-lock return | UNVERIFIED | Compare no history, 500, and 2,000 sessions; log first frame and root reconciliation. |
| Today | Initial load, scroll, start workout, resume workout | UNVERIFIED | Start a plan with five sets of a never-logged exercise; compare history sizes. Prefill service alone was measured at 24–98 ms across 500–2,000 sessions. |
| Plans | Open, existing plan, edit, add exercise, reorder, create | UNVERIFIED | Record editor body counts and save duration at 50 plans / 200 exercises. |
| Plans | Reset Sample Plans on disposable data | UNVERIFIED | Inject a save/seed failure after deletion save; verify whether original plans survive. Never run this on the user store. |
| Exercise Library | Initial load, search, filter, open, edit, archive/restore, long list | UNVERIFIED | At 200 definitions, in-memory fetch/search alone took ~3.2 / 0.2 ms; UI layout and persistence faults are unmeasured. |
| Exercise Detail | PBs, history, progress, recent sets | UNVERIFIED for UI; **BUG** in recent-list logic | Insert one completed session with duplicate entries for an identity: first incomplete, second complete. Isolated reproduction yields Detail recent `false`, Progress history `true`. |
| Active Workout | Start, exercise navigation, weight/reps pickers, complete set, rest, skip, add/remove set, background/lock resume | UNVERIFIED | Count `_printChanges()` and frames over 10 seconds idle, 10 seconds rest, and 10 seconds music plus rest; test save-failure recovery separately. |
| History | Initial load, scroll, open/return, large data | UNVERIFIED | Search an exercise name with 500/2,000 sessions; capture relationship faults and row render time. |
| Calendar | Open, previous/next, rapid months, date selection, multiple workouts/day | UNVERIFIED | Host month grouping took ~15–18 ms at 500–2,000 sessions, but SwiftUI transition/fault time is unmeasured. |
| Share | Preview, 20+ randomizations, render, sheet open, dismiss/reopen | UNVERIFIED | Measure history tap→preview and Share tap→sheet separately; randomization does **not** call full-resolution renderer. |
| Music | Tab load, scroll, playback, next/previous, shuffle, Now Playing, mini-player, background | UNVERIFIED | Profile 0.5-second publications while playing and paused; import several large files into disposable store. |
| Google Drive | Sign-in, listing, network playback, seek, next, background, reconnect, errors | UNVERIFIED / NOT REACHABLE | Branch is unmerged; no current-main Drive path exists. Do not attribute main-app slowness to it. |
| Settings | Load, change preferences, reset actions, backup/export | UNVERIFIED | No backup/export UI is present. Exercise destructive actions only with an isolated store. |

## 3. User-perceived latency and large-data experiment

`Diagnostics/DeepAuditBenchmark.swift` is a DEBUG-only standalone executable. It builds the real nine-model SwiftData schema with `ModelConfiguration(isStoredInMemoryOnly: true)`, fixed IDs/dates/values, 200 exercise definitions, 50 five-exercise plans, and 500/1,000/2,000 completed sessions with ten sets each. No production seeding or real database is used. It times actual `FetchDescriptor`, `ExercisePerformanceService`, `ExerciseProgressHistory`, `WorkoutHistoryGrouper`, `WorkoutService`, and `WorkoutShareSummaryBuilder` calls. It also checks the duplicate-entry Detail/Progress mismatch. Compile and run commands are in the execution ledger below.

Single optimized host runs, milliseconds rounded to one decimal:

| Isolated operation | 500 sessions / 5k sets | 1,000 / 10k | 2,000 / 20k | Interpretation |
|---|---:|---:|---:|---|
| Library fetch (200 definitions) | 3.2 | 3.3 | 3.3 | Small in this warmed in-memory case; no UI conclusion. |
| Library name search | 0.2 | 0.3 | 0.3 | Search computation is small for 200 definitions. |
| Plan fetch/open (50 plans; five rows in first) | 1.2 | 1.3 | 1.3 | No long-plan or SwiftUI editor cost included. |
| Completed history fetch | 6.9 | 13.6 | 27.6 | Result count scales with entire history; row relationship faults/layout excluded. |
| One exercise PB summary and PR events | **135.2** | **277.0** | **551.1** | Main-actor Exercise Detail work is plausibly perceptible; actual screen latency unmeasured. |
| One exercise progress set scan | 4.8 | 10.1 | 19.8 | This excludes chart mark layout/rendering. |
| One month overview | 15.4 | 16.4 | 17.5 | Month contained roughly 28–31 sessions; still scans all sessions. This fixture does not show a large calendar stall. |
| Workout prefill, matching recent data | 1.8 | 2.9 | 3.8 | Early matching stops the scan. |
| Workout prefill, absent exercise, five target sets | **24.0** | **50.5** | **98.2** | Confirms recent per-set backward-scan cost when no prior result exists. |
| Last workout share-summary construction | **246.3** | **504.3** | **1,046.4** | Measured service cost before any high-resolution image rendering or sheet presentation. |

`/usr/bin/time -l` reported a **70.3 / 120.6 / 231.1 MB maximum resident set size** for the complete standalone 500 / 1,000 / 2,000 fixture processes. This includes the benchmark runtime, in-memory store, all constructed models, and timed operations. It is **not** app baseline/peak/post-dismiss memory, and it does not prove a leak. The host emitted `CoreData: error: unable to check registration for posting store changed notification` but the executable exited 0 for all scales.

No milliseconds are available for cold launch, first render, tab switching, navigation, sheet/picker opening, workout completion transition, History screen, Calendar screen, Share Preview screen, share image rendering, Music Library screen, local playback start, or Google Drive playback. Those actions need the SwiftUI/App Launch/Time Profiler instruments on an accessible simulator or device. The benchmark strongly narrows the first interactive traces to **share opening, workout completion, and Exercise Detail**; it does not prove the main thread was blocked for the measured durations on an iPhone.

### Complexity and SwiftData query inventory

| File and function/view | Current behavior | Scale risk and better query strategy to evaluate |
|---|---|---|
| `ContentView.swift:8-9,103-115` | Root holds every `ImportedTrack` and **every** `WorkoutSession`; foreground reconciliation filters them to active in memory. | Every launch/foreground can load all session headers. Fetch only active sessions when reconciling; keep track synchronization scoped to actual library changes. |
| `TodayView.swift:7-11,39-60,91-98` | Unbounded sessions query feeds active selection, last completion, duration estimate, and start-workout prefill. | History growth affects first Today render and Start. Fetch active and recent per-plan sessions separately or use bounded/predicate queries. |
| `WorkoutService.swift:28-94` | Sorts completed history once, then scans each session's sorted exercise/set relationships for **each planned set** until a match. | Worst case roughly target sets × historical sessions × relationship sorting/faulting; recent correctness fix enlarged this work. Build per-exercise/per-set latest-value index once or use narrowed completed history, after measuring on device. |
| `ExerciseDetailView.swift:7-18,25-53` | Holds all sessions plus completed sessions, all plans, scans usage/recent records, computes a full PB summary inside `body`. | Two unbounded session result arrays/fetch paths; relationship scans and PR-event derivation can repeat on state invalidation. This does not imply duplicate model instances in one SwiftData context. Query a narrow usage check and history for this exercise, cache derived summary on data change. |
| `ExercisePerformanceService.swift:168-250,302-347` | Filters/sorts all completed sessions, traverses exercise records and working sets, then calculates events and bests. | Host PB timing grows ~linearly with total sets even for one exercise because filtering is in memory. The model currently has no direct indexed exercise-record query path; denormalized read model or targeted query needs a measured design, not an immediate schema rewrite. |
| `ExerciseProgressView.swift:7-62` | Queries every completed session and rebuilds matching history, chart points, and best weight per body. | O(all sessions and relationships) on chart/selection invalidation; cap/downsample chart points and scope data access after tracing. |
| `HistoryView.swift:8-35,109-126` | Store filters completed status, but query remains unbounded. Exercise-name search traverses every session's exercise relationship on each keystroke; rows compute totals from all sets. | Store-level search/index or cached searchable metadata would avoid all-relationship faults. Measure search and scrolling before choosing schema changes. |
| `WorkoutCalendarView.swift:28-49`; `WorkoutHistoryGrouper.swift:44-108` | Receives all completed sessions; each month navigation filters all sessions, sorts the month, then totals monthly sets. | O(all sessions + month set work) per navigation, despite comments implying only-month scope. Date-range completed-session fetch would bound work. |
| `WorkoutCompletionView.swift:9-14,99-120`; `WorkoutHistoryDetailView.swift:79-93` | Completion holds all completed sessions and derives PRs; History Share fetches all completed sessions synchronously on tap; both build a share summary with history-derived PBs. | The measured 246–1,046 ms summary cost can precede preview even without rendering. Fetch/derive only what one share needs, cache completion PR computation, and profile relationship faults. |
| `PlanEditorView.swift:50-59,113-157` | Resolves each planned name by linear search across all definitions during draft redraw; saving replaces planned rows even for small edits. | O(plan rows × definitions) render path and unnecessary writes/new planned-row IDs. Moderate at 50 plans/200 definitions; verify with longer plans. |
| `MusicLibraryView.swift:7-9`; `PlaylistDetailView.swift:7-25,53` | Unbounded membership query exists on Music tab for deletion; playlist detail scans the track library for each membership. | Avoid live whole-membership query for a one-off delete, and index tracks by ID for playlist display. |

Every `@Query` and `FetchDescriptor` in `GymFlow` was enumerated with `rg`; Settings' whole-table fetches are action-only and appropriate for explicitly destructive actions. The current completed-status predicate in History/Progress/Completion/ActiveWorkout is a useful store-level filter, but it does not bound the number of completed rows. The benchmark is warm/in-memory, so it likely understates cold SQLite fault and SwiftUI layout costs. It cannot isolate SQLite time from model traversal; Time Profiler and Data Persistence traces are needed for that attribution.

## 4. SwiftUI invalidation and timers

**Code-confirmed publication paths:** `RestTimerService.swift:20-22,222-239` samples the deadline every 0.25 seconds and assigns `@Published remainingSeconds` even when the rounded integer is unchanged. `ActiveWorkoutView.swift:22,44-95` owns/observes that whole object, and its body repeatedly reads sorted SwiftData relationships. `RestTimerRingCard` also observes the timer. This can invalidate the parent up to four times per second during rest; actual body invocation count depends on SwiftUI coalescing and was not measured. The elapsed-workout `TimelineView` at `WorkoutExerciseHeader.swift:71-79` is correctly scoped to the header. The rest timer is deadline-based and its own timer is invalidated on pause, cancel, completion, reschedule, and deinit; there is no evidence of an incrementing clock drifting in background.

`AudioPlayerService.swift:322-341` uses a 0.5-second main RunLoop timer. Every tick assigns `progress`, `duration`, and `isPlaying`, refreshes Now Playing metadata, and may write a snapshot. `pausePlayback` (`:400-404`) and natural queue end (`:283-296`) do **not** invalidate that timer; interruption/route pause use the same path. This causes continued wakeups/publications even at a fixed position. `ContentView.swift:7,26,80-85` observes the entire audio service although root mini-player visibility only needs current-track state; `ActiveWorkoutView.swift:9,234-242` does likewise. Root/active views can therefore be invalidated by music progress, including alongside the rest timer. `ContentView` also rebuilds `tracks.map(\.id)` for its `.onChange` input during root body evaluation. The exact number of body evaluations and child redraws requires temporary `Self._printChanges()` in `ContentView`, `ActiveWorkoutView`, `HistoryView`, and the music views during a runnable session. No diagnostic logging was left in production.

Other rendering risks: `ExerciseProgressView` builds all chart points per body and `StrengthProgressionChart` draws multiple marks per point without a history cap; `WorkoutValuePickerSheet` builds 1,001 weight choices on state changes; `HistoryView` search faults relationships per keystroke; `TodayView` recomputes a history-derived duration estimate in body. There was no source evidence of per-body `UUID()` recreation in these expensive lists, excessive `AnyView`, repeated full-resolution share rendering on randomization, or an app-wide one-second elapsed timer. `Date.now` in Today text does not by itself create a ticking publisher.

### Time-sensitive concurrency and lifecycle

- `RestTimerNotificationScheduler.swift:39-77` launches an untracked `Task` to remove and add a pending notification. A rapid start→skip/pause or +30 sequence can let an older add finish after a cancel/new schedule. This is a **race hypothesis from ordering**, not a device-confirmed duplicate alert; the fake scheduler tests do not exercise `UNUserNotificationCenter` timing.
- `LiveActivityManager.swift:114-129` chains ordinary updates, but `updateImmediately` (`:190-209`) bypasses that chain and `end` (`:212-224`) starts unawaited end tasks without draining prior updates. A stale update/end order is possible under rapid set/rest actions; verify on a locked physical device.
- `ActiveWorkoutView.swift:393-421` cancels rest before persisting finish/cancel. On a thrown save, it restores session status/date but cannot restore the rest deadline/notification. This is a code-confirmed failure path; trigger only via a fault-injected test container.
- `AudioPlayerService.swift:8,244` has a fresh Swift 5 compiler warning: main-actor `AVAudioPlayerDelegate` conformance crosses a nonisolated protocol requirement. Treat as a Swift 6 migration/data-race risk; no current race was observed.
- The audio service registers NotificationCenter observers and remote-command targets once in initialization and removes them in deinit (`AudioPlayerService.swift:58-66,425-527`). No source proof of duplicate registration was found. A target-based timer can retain a service until invalidation, but the production service is intentionally app-lived; this is mainly a preview/test lifecycle risk.

## 5. Share, music, Drive, and memory

### Share

There are **two distinct operations**. Opening Share from History runs `WorkoutHistoryDetailView.swift:79-93`: it fetches all completed sessions synchronously, then `WorkoutShareSummaryBuilder.build` traverses history for a PB. The isolated service cost was 246–1,046 ms across the tested scales; the fetch, navigation, and frame cost are additional and unmeasured. Sharing from completion also has an unbounded completed-session query and full-history PR computation. This is the first main-thread hitch to trace on an iPhone.

Once Preview is open, `WorkoutSharePreviewView.swift:31-37,112-118` shows a SwiftUI card at at most 300 points wide and changes only its background selection during randomization. Backgrounds are programmatic gradients/shapes/Canvas. **Randomize does not repeatedly create a 1179 × 2556 image**; the prior conceptual concern is not present in current code. On Share, `WorkoutSharePreviewView.swift:120-139` enters `Task { @MainActor in ... }`, yields, then synchronously calls `WorkoutShareRenderer.render` (`:4-31`), which allocates `ImageRenderer` and reads `uiImage` at 393 × 852 points × 3 = **1179 × 2556 = 3,013,524 pixels**. A raw four-byte RGBA buffer is about **12,054,096 bytes (11.5 MiB)** before renderer/intermediate/UIImage overhead. `Task.yield()` permits the spinner to appear but does not move rendering off the main actor. Rendering duration, frame hitch, and peak memory are unmeasured. The generated `UIImage` is kept in `@State` while the share sheet is presented and explicitly cleared when that sheet dismisses; no retained-image leak was established by source review.

### Music and Google Drive

`MusicLibraryView.swift:177-204` handles FileImporter results in a synchronous loop. `AudioFileStore.swift:51-76` enumerates existing filenames, copies each full file, then opens it with `AVAudioPlayer` for duration. This work is called from a UI callback without a background handoff; importing large/multiple files is a credible main-thread stall, **not yet timed**. The directory enumeration is repeated per file. `MusicLibraryView` observes the whole audio service and does in-body filtering/sorting; its unbounded `PlaylistTrack` query is only needed for deletion. `PlaylistDetailView` does linear library lookup per membership. The 0.5-second playback timer needlessly continues on pause/end, and `makeNowPlayingInfo` can decode `artworkData` each tick if populated. Current import leaves artwork empty, so do not attribute present-day memory growth to large album art without a seeded-artwork test.

The OSStatus -50 fix **remains in source**: `AudioPlayerService.swift:392-395` calls `setCategory(.playback, mode: .default)` with no invalid `.allowAirPlay` option. Playback and background audio still require physical verification. `main` has no Google Drive sign-in, listing, network player, buffer, or reconnect path. The divergent branch cannot contribute to current-main CPU/memory behavior; branch performance and network error handling remain entirely unverified here.

### Memory and resource ownership

No app baseline, peak, post-dismiss memory, memory graph, Allocations, or Leaks trace was obtainable. In particular, the requested repeated Active Workout, Detail, Share randomization/export, Now Playing, track switch, History, and Drive-browse memory cycles were **not run**; the Drive cycle is also unavailable in `main`. The standalone fixture's process peak RSS values are recorded above solely as scale context. A rising host fixture RSS across 5k–20k sets is expected and does not imply an app leak.

Source review identifies watchpoints, not confirmed leaks: the unbounded root/Today/Detail/History queries keep large result collections live; playback timer publication can continue after pause; share export has a full-size transient bitmap; the Now Playing builder can recreate artwork; async notification/Live Activity tasks may outlive the initiating view action. Rest timer closure is weak and its timer is torn down; share sheet clears the exported image; observer/remote-command registration has paired removal. No source-confirmed retain cycle was established. A physical/simulator memory run should record baseline → peak → 30-second post-dismiss for each requested cycle, including 20+ randomizations and repeated exports, with an explicit leak threshold chosen before judging growth.

## 6. Correctness and data-integrity findings

| Priority | Finding and evidence | Reproduction / limit |
|---|---|---|
| **P1** | **Exercise Detail can omit a real recent workout.** `ExerciseDetailView.swift:33-43` takes only the first matching `ExerciseRecord` in a session and requires that record to have a completed set. `ExerciseProgressHistory.swift:5-19` aggregates all matching records. | Isolated real-model check constructed duplicate entries for one exercise, first incomplete/second complete. The Detail expression returned false while Progress returned true at all three benchmark scales. UI presentation itself was unavailable. |
| **P1, conditional** | **Sample reset is not atomic.** `SampleDataSeeder.swift:108-119` deletes every plan, saves, then reseeds; a second-phase failure leaves the deletion committed. Old Settings reset had the same save-then-seed window, so this is not established as a new regression. | Needs fault injection in a disposable context, then verify plans remain or are recovered. No destructive action was run. |
| **P2, conditional** | **Finish/cancel save failure loses active rest.** `ActiveWorkoutView.swift:393-421` cancels timer before `modelContext.save`; error rollback restores session flags, not timer state. | Inject save failure during rest in a test container. No runtime failure observed. |
| **P2, conditional** | **Audio deletion can split files and records.** `SettingsView.swift:140-149` and `MusicLibraryView.swift:231-243` delete files before saving SwiftData row deletion; a file or save failure can leave rows pointing to removed files. | Fault-inject file deletion/save; use copies in a temporary directory. No user files touched. |
| **P2, hypothesis** | **Rest notification add/cancel and Live Activity update/end can reorder.** See the async paths in section 4. | Rapid start/+30/skip and finish on locked device, inspect pending requests/activity state. No system-level reproduction yet. |
| **P3, hypothesis** | Preview/export contextual heading may differ if the sheet remains open across local midnight because each card construction captures its own `Date()` (`WorkoutShareCardView.swift:14-24`). | Inject a fixed clock at the boundary in a future isolated test; not observed. |

The current migration fixture confirms only that one small implicit-schema store can reopen through current V1 types. It does not validate a historical binary, a scrubbed real user store, future migration, or large-store migration time. No SwiftData model/migration code was changed in this audit.

## 7. Fix and verification order

No production fix was made. Recommended order is based on **measured cost, user exposure, and data risk**, not on whether a test happens to exist:

1. **Trace Share open and workout completion at 500+ sessions on a runnable iPhone/simulator.** Add temporary signposts around completed-session fetch, PB event derivation, summary construction, and first Preview frame. The host benchmark already shows the biggest scaling cost. Then design a narrowed/cached history read without changing snapshots or schema blindly.
2. **Trace Exercise Detail first frame and state changes.** Use Time Profiler, Data Persistence, and temporary `_printChanges()` to split SwiftData faults from PB/event CPU. Fix the deterministic duplicate-record recent-list bug with a focused failing test in the same bounded workstream.
3. **Measure and reduce timer-driven invalidation.** Count root/ActiveWorkout/Music body updates while idle, music playing, music paused, rest only, and both active. Check that unchanged rounded seconds and paused playback do not publish continuously after correction. Confirm Live Activity/Lock Screen behavior on device.
4. **Profile worst-case Start Workout prefill.** Reproduce five or more never-logged sets with 500/2,000 sessions. The 203e3ea correctness change makes this a recent, measurable scaling regression candidate; preserve the older-valid-set behavior while optimizing.
5. **Secure data-error paths before destructive user actions.** Fault-inject sample reset, workout finish/cancel, and audio deletion using disposable stores/files. Make each operation's failure state reviewable and recoverable; never test by deleting the user's store.
6. **Profile multi-file import, History search, Calendar navigation, and chart interaction at scale.** The source contains unbounded queries/relationship traversals, but the isolated month grouping was only ~15–18 ms, so avoid assuming Calendar is the leading stall.
7. **Run memory and concurrency gates on a functioning host.** Record Allocations/Leaks/Memory Graph across the requested repeated cycles; run Main Thread Checker and Thread Sanitizer on suitable simulator targets. Validate rapid notification/Live Activity ordering on a physical device. Only then assign leak and race severity.

## Execution ledger and reproducibility

The benchmark was compiled against **real current source** with:

```bash
xcrun swiftc -O -D DEBUG -swift-version 5 -o /tmp/GymFlowDeepAuditBenchmark \
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

/usr/bin/time -l /tmp/GymFlowDeepAuditBenchmark 500
/usr/bin/time -l /tmp/GymFlowDeepAuditBenchmark 1000
/usr/bin/time -l /tmp/GymFlowDeepAuditBenchmark 2000
```

Compilation and all three runs exited **0** after the final deterministic fixture change. `xcrun swift-format lint --strict Diagnostics/DeepAuditBenchmark.swift` exited **0** after formatting this new diagnostic file. The first strict-lint attempt before formatting exited 1 on layout only; no production file was formatted. `git diff --check` exited **0** after the tracked documentation edits. The current Xcode build/tests remained blocked as detailed in section 1. No previous passing test was treated as proof of current HEAD.

Direct source compatibility checks used these exact commands (all exited 0):

```bash
rg --files -0 GymFlow GymFlowActivityShared -g '*.swift' |
  xargs -0 xcrun swiftc -target arm64-apple-ios17.0-simulator \
  -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.5.sdk \
  -swift-version 5 -typecheck -D DEBUG

rg --files -0 GymFlowLiveActivityExtension GymFlowActivityShared -g '*.swift' |
  xargs -0 xcrun swiftc -target arm64-apple-ios17.0-simulator \
  -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.5.sdk \
  -swift-version 5 -typecheck
```

The complete app/shared source was also emitted as a testable `GymFlow` module under `/tmp/GymFlowDeepAuditModule`, after which every current `GymFlowTests` and `GymFlowUITests` Swift file typechecked against the iOS Simulator SDK and XCTest/Testing framework/macro paths. These commands do not link or execute the test bundles. All temporary binaries/modules remain under `/tmp`; the repository diagnostic is source-only and guarded by `#if DEBUG`. No merge, push, commit, production refactor, feature, data reset, or destructive migration was performed.
