# GymFlow Implementation Plan

## Milestone 0 — Repository inspection and planning

- [x] Inspect files, targets, settings, scheme, SDK, and source baseline.
- [x] Create `AGENTS.md`, `PROJECT_SPEC.md`, `PLANS.md`, `PROGRESS.md`, and `README.md`.
- [x] Build the unmodified project and record the result.

Acceptance: documentation exists, scheme `GymFlow` is identified, and baseline status is known.

## Milestone 1 — App shell and persistence

- [x] Establish app folders and SwiftData container.
- [x] Implement all core models and ordered accessors.
- [x] Seed first-launch exercises and sample plans once.
- [x] Add Today/Plans/History/Music tabs with useful states.
- [x] Build successfully.

Acceptance: app launches, tabs and sample plans appear, and data persists.

## Milestone 2 — Workout plan management

- [x] Build plan list create/duplicate/delete/reorder workflows.
- [x] Build safe plan editor with exercise library and custom exercises.
- [x] Validate plan/exercise/numeric values.
- [x] Add duplication and validation tests; build and test.

Acceptance: complete plans can be created, edited, duplicated, reordered, and deleted with persistent valid values.

## Milestone 3 — Active workout

- [x] Create and restore snapshot sessions from plans.
- [x] Build editable set logging, completion, warm-up, add/remove, and exercise navigation.
- [x] Save every change and support finish/cancel confirmations.
- [x] Add session/snapshot tests; build and test.

Acceptance: workout completes end-to-end, active state restores, and completed history appears.

## Milestone 4 — Rest timer

- [x] Implement persisted deadline-based timer and controls.
- [x] Auto-start on set completion with optional haptic/sound.
- [x] Recover on app foreground.
- [x] Add timer tests; build and test.

Acceptance: configured timers remain correct through backgrounding.

## Milestone 5 — History and progress

- [x] Build searchable history, read-only detail, and confirmed deletion.
- [x] Build volume summaries and exercise progress.
- [x] Verify historical snapshots; build and test.

Acceptance: history remains stable after plan edits and accurately summarizes completed work.

## Milestone 6 — Local music import and playback

- [x] Implement stable Application Support file storage/import/deletion.
- [x] Implement shared AVFoundation player and playlist engine.
- [x] Build library, Now Playing, mini-player, shuffle/repeat/seek controls.
- [x] Add storage and playlist tests; build and test.

Acceptance: imported local audio persists, plays, navigates, and deletes safely without crashes.

## Milestone 7 — Integration and polish

- [x] Integrate compact audio with workouts and completion summary.
- [x] Add settings and destructive data controls.
- [x] Review accessibility, Dark Mode, errors, and empty states.
- [x] Finish README; build and test.

Acceptance: the offline primary journey is coherent and no placeholder blocks it.

## Milestone 8 — Final audit

- [x] Audit TODO/FIXME/fatal errors/placeholders/force unwraps and dead code.
- [x] Review relationships, deletion, and restoration behavior.
- [x] Run all unit tests and final clean simulator build.
- [x] Record final results, manual steps, and limitations.

Acceptance: final build and tests succeed or environment-only failures are precisely documented.

## Continuous Workout and Music Upgrade

### Upgrade Milestone 1 — Repository audit

- [x] Inspect the current models, services, navigation, music, workout, timer, tests, and project capabilities.
- [x] Confirm scheme, SDK, deployment target, destinations, signing, and background-audio configuration.
- [x] Run and record the unchanged upgrade baseline build.

Acceptance: working first-release behavior and upgrade gaps are understood, and the baseline build succeeds.

### Upgrade Milestone 2 — Shared audio and focused workout integration

- [x] Preserve one application-level `AudioPlayerService` across tabs and workout presentation.
- [x] Keep compact previous/play-pause/next controls visible without covering workout inputs or timer controls.
- [x] Present full Now Playing as a dismissible sheet and provide a clear workout minimize action.
- [x] Restore the active exercise and current incomplete set.

Acceptance: workout, timer, and music controls remain usable together without losing state or navigation context.

### Upgrade Milestone 3 — Playlist data and management

- [x] Add migration-friendly `Playlist` and `PlaylistTrack` SwiftData entities with ordered many-to-many membership.
- [x] Add playlist creation, rename, duplicate, deletion, detail, add/remove tracks, and track reordering.
- [x] Add library search/sort and add-to-playlist actions.
- [x] Ensure deleting a playlist preserves files and deleting a library track removes memberships.

Acceptance: tracks can belong to multiple playlists without copying files, and all playlist CRUD persists.

### Upgrade Milestone 4 — Playback queue behavior

- [x] Implement deterministic sequential playback and a stable shuffled queue.
- [x] Support repeat off, one, and all against the maintained queue.
- [x] Persist queue context, current track, progress, shuffle, and repeat settings where practical.
- [x] Add focused queue, shuffle, repeat, and restoration tests.

Acceptance: displayed playlist order and maintained shuffle/repeat behavior match the specification.

### Upgrade Milestone 5 — Background audio and system media controls

- [x] Handle audio interruptions and route changes without corrupting playback state.
- [x] Publish track, artist, duration, elapsed time, playback rate, and fallback artwork to Now Playing.
- [x] Handle play, pause, toggle, previous, next, and seek through `MPRemoteCommandCenter`.
- [x] Verify the app retains only the audio background mode.

Acceptance: app and system controls drive the same player, with physical-device-only checks documented honestly.

### Upgrade Milestone 6 — Workout and timer restoration

- [x] Persist active session identity, current exercise, current set, and workout playback context.
- [x] Reconcile deadline-based rest timer state after foregrounding and relaunch.
- [x] Preserve immediate set edits and active-session resume/cancel behavior.

Acceptance: an interrupted workout resumes at the correct exercise/set and the timer reflects elapsed wall time.

### Upgrade Milestone 7 — Workout-plan playlist assignment

- [x] Add optional playlist assignment to workout-plan editing.
- [x] Add an off-by-default automatic assigned-playlist setting.
- [x] Load the assigned playlist at workout start without losing the ability to change queues.

Acceptance: assigned playlists are ready at workout start and only auto-play when the user opts in.

### Upgrade Milestone 8 — Live Activity and Dynamic Island

- [x] Isolate ActivityKit attributes and lifecycle coordination from core workout code.
- [x] Add a Widget Extension only if project generation, signing, and build verification are safe.
- [x] Show current exercise/set, progress, elapsed workout time, and deadline-based rest status.
- [x] End the activity on workout finish/cancel and document real-device limitations.

Acceptance: optional system-surface work does not destabilize the main app; manual steps are exact if required.

### Upgrade Milestone 9 — Final integration and audit

- [x] Run unit, UI, clean simulator, and available device build checks.
- [x] Audit TODO/FIXME/fatal errors/placeholders/force unwraps and deletion/restoration paths.
- [x] Update product documentation, capability instructions, verification results, and known limitations.

Acceptance: all feasible P0 work and stable P1 work build and test successfully, with device-only verification clearly separated.

## Root Layout and Live Activity Lifecycle Fix

### Bug-fix Milestone 1 — Audit and baseline

- [x] Read project guidance and inspect the root `TabView`, every mini-player placement, ActivityKit manager, extension UI, persistence, SDK support, and device availability.
- [x] Record the mini-player and stale-activity root causes.
- [x] Run the unchanged `GymFlow` main-scheme baseline build.

Acceptance: both failures are reproduced in code, the iOS 26 accessory API is confirmed, and baseline compilation succeeds.

### Bug-fix Milestone 2 — Native mini-player hierarchy

- [x] Use the native iOS 26 tab accessory with an adaptive pre-iOS-26 fallback.
- [x] Reserve layout space without offsets or hard-coded tab-bar padding.
- [x] Prevent simultaneous global/workout mini-players and keep independent transport controls.
- [x] Add focused visibility/shared-player checks and build the main scheme.

Acceptance: the mini-player is compact and appears above the tab bar while tabs and workout controls remain accessible.

### Bug-fix Milestone 3 — Defensive Live Activity lifecycle

- [x] Centralize start, update, end, discovery, duplicate cleanup, persistence, and diagnostics in `LiveActivityManager`.
- [x] Reconcile ActivityKit against the persisted active session on launch and foreground.
- [x] Invalidate inconsistent/expired sessions and end orphaned activities.
- [x] Add an eight-hour maximum lifetime and meaningful timer/training/stale presentation.
- [x] Add deterministic reconciliation and display-state tests.

Acceptance: normal finish/cancel ends immediately, valid background workouts survive, stale activities are honest, and relaunch cleans orphaned state.

### Bug-fix Milestone 4 — Final and physical verification

- [x] Run the complete test suite, clean simulator build, and signed arm64 device build using the main scheme.
- [ ] Install and launch the signed build on the physical iPhone once the paired device reconnects.
- [ ] Verify tab interaction, music continuity, workout controls, normal activity finish/cancel, backgrounding, and force-quit behavior on the iPhone.
- [x] Inspect available simulator logs and update `PROGRESS.md` and `README.md` with exact results and iOS limitations.

Acceptance: both fixes build and test, physical observations are recorded, and unavoidable force-quit behavior is documented honestly.

## Plans, Now Playing, and Duration-estimate UX Quality Fix

### UX Milestone 1 — Audit and baseline

- [x] Read project guidance and inspect plan editor presentation, root/workout mini-player presentation, shared audio state, session persistence, Today estimates, and existing tests.
- [x] Record the plan first-tap and Now Playing auto-dismiss root causes.
- [x] Run the unchanged main-scheme simulator build and inspect simulator/physical-device availability.

Acceptance: the state races and previous duration heuristic are identified, and the baseline build succeeds.

### UX Milestone 2 — Deterministic plan selection

- [x] Replace split optional-plan/Boolean presentation state with one item-driven editor presentation.
- [x] Keep existing-plan selection and explicit plan creation as separate intents.
- [x] Verify selection does not insert or duplicate a SwiftData plan.

Acceptance: an existing plan opens on the first tap and only the create control can open a new-plan editor.

### UX Milestone 3 — Stable Now Playing presentation

- [x] Move Now Playing presentation ownership from the transient mini-player/accessory view to stable root and workout hosts.
- [x] Keep presentation independent from current track, play/pause, progress, queue, shuffle, and repeat updates.
- [x] Hide the mini-player while full Now Playing is presented and preserve explicit Done/swipe dismissal.

Acceptance: Now Playing stays open until explicit dismissal and continues using the shared audio service.

### UX Milestone 4 — History-based workout estimates

- [x] Add a testable estimator with strict workout-plan UUID matching and static fallback.
- [x] Filter active, planned, cancelled, invalid-timestamp, missing-plan, and clearly corrupted sessions.
- [x] Use one sample directly, two-sample arithmetic mean, and the median of the latest five for three or more samples.
- [x] Integrate the reactive estimate into Today and add focused unit coverage.

Acceptance: recent valid history drives Today without allowing unrelated plans or outliers to distort the estimate.

### UX Milestone 5 — Final and physical verification

- [x] Run the new Plans UI test, complete main-scheme tests, and final clean simulator/device builds.
- [x] Install and launch the signed build on the connected physical iPhone.
- [x] Verify first-tap Plans, sustained Now Playing interactions, and reactive historical estimates on device where test data permits.
- [x] Record exact results and remaining device/data limitations.

Acceptance: automated regressions pass, physical observations are honest, and the repository is buildable.

## Active Workout Exercise Screen Redesign

### Redesign Milestone 1 — Audit and baseline

- [x] Read project guidance and inspect the active workout, set logging, previous performance, rest timer, mini-player, exercise navigation, persistence, and Live Activity paths.
- [x] Record the cramped table, truncated labels, oversized inputs, dominant set actions, and crowded lower-controls hierarchy.
- [x] Run the unchanged main-scheme simulator build.

Acceptance: existing workout behavior is mapped before presentation changes begin, and the baseline compiles.

### Redesign Milestone 2 — Exercise hierarchy and set cards

- [x] Replace the rigid four-column table with responsive, self-contained set cards.
- [x] Add a clear exercise header, compact horizontally scrolling previous-performance reference, lighter numeric inputs, a full Warm-up chip, and a 44-point circular completion control.
- [x] Make Add Set secondary and move individual removal into each set's actions menu while preserving a minimum of one set.

Acceptance: set number, Weight, Reps, Warm-up, and completion remain legible and tappable without narrow fixed columns.

### Redesign Milestone 3 — Timer, player, navigation, and accessibility

- [x] Place all variable workout content in one scroll view and reserve the bottom safe area for the shared mini-player and exercise navigation.
- [x] Compact the rest timer and adapt its controls, the workout header, and exercise navigation for accessibility Dynamic Type.
- [x] Add accessibility labels, state values, stable UI-test identifiers, and focused card/add/remove/timer/navigation UI coverage.

Acceptance: six or more sets remain reachable, the footer does not overlap content or the Home indicator, and controls retain 44-point targets.

### Redesign Milestone 4 — Responsive and physical verification

- [x] Verify compact, standard, and Dynamic Island simulator widths, including Dark Mode and accessibility-extra-large Dynamic Type.
- [x] Run the GymFlow unit suite and a final clean simulator build.
- [x] Install, launch, and exercise the redesigned workout on the connected iPhone with previous performance and imported music.
- [x] Record exact results and remaining limitations in `PROGRESS.md`.

Acceptance: the redesign builds, tested interaction paths pass, and the physical iPhone shows no truncation or footer overlap.

## Interactive Live Activity and Rest Alert Upgrade

### Interaction Milestone 1 — Audit and baseline

- [x] Read project guidance and inspect Live Activity, SwiftData workout state, timer persistence, notifications, audio session, settings, and device availability.
- [x] Confirm the installed SDK's native interactive Live Activity mechanism and iOS 17 minimum.
- [x] Run the unchanged main-scheme simulator build and focused unit baseline.

Acceptance: the existing state boundaries and platform mechanism are known before mutation paths change.

### Interaction Milestone 2 — Shared complete-set action

- [x] Add one idempotent `WorkoutActionService` used by the active workout and Live Activity intent.
- [x] Add `CompleteCurrentSetIntent` as a native `LiveActivityIntent` without foregrounding GymFlow.
- [x] Persist through the app's existing SwiftData container and reject stale or duplicate set identifiers.
- [x] Update Lock Screen and expanded Dynamic Island content with Complete Set, +30 seconds, and Skip controls.

Acceptance: every surface produces the same set state, starts the same persisted rest timer, and never advances on a duplicate request.

### Interaction Milestone 3 — Noticeable and reliable rest completion

- [x] Add a repeated one-second two-tone cue, strong haptic sequence, and temporary GymFlow-music ducking with restoration.
- [x] Keep the audio session on `.playback` without category-option changes.
- [x] Schedule one stable time-sensitive local notification per workout and cancel/reschedule it for timer changes.
- [x] Suppress foreground notification presentation in favor of the in-app multimodal cue.
- [x] Keep independent Sound and Haptic settings under Rest Timer Alert.

Acceptance: foreground and background paths are coordinated, music is not stopped, and an expired Live Activity reads Rest Complete/Ready instead of `0:00`.

### Interaction Milestone 4 — Verification and documentation

- [x] Add focused completion, idempotency, final-set, stale-ID, timer-action, notification, and alert-state tests.
- [x] Build the main app and standalone Widget Extension successfully.
- [x] Run the complete focused unit suite on Simulator and a signed physical iPhone.
- [x] Install and cold-launch the signed app with its embedded extension on the connected iPhone.
- [ ] Perform the human Lock Screen button, Dynamic Island button, audible cue, haptic, and locked-background acceptance gestures; command-line XCTest cannot unlock/authenticate or judge audible/haptic intensity, and the physical UI runner timed out enabling automation mode.

Acceptance: automated and package verification pass, with human-only system-surface observations recorded honestly rather than inferred.

### Interaction Milestone 5 — Locked-device authentication correction

- [x] Explicitly declare the least restrictive `.alwaysAllowed` intent policy for Complete Set, +30 seconds, and Skip.
- [x] Add a regression test for authentication and foreground-launch metadata.
- [x] Clean-build and sign the main app plus embedded Live Activity Extension.
- [x] Verify extracted App Intents metadata in both bundles and install the corrected build on the physical iPhone.
- [x] Record the physical-iPhone finding that WidgetKit still requires device authentication before third-party controls run on a genuinely locked Live Activity.
- [x] Preserve the native control and avoid unsupported media-command remapping or other system-control workarounds.

Acceptance: GymFlow adds no stricter App Intent authentication of its own, and the unavoidable WidgetKit locked-device security boundary is documented accurately.

## Exercise Library and Workout Calendar

### Library/Calendar Milestone 1 — Schema audit and compatibility

- [x] Read project guidance and inspect exercise definitions, planned exercise snapshots, completed-session snapshots, seeding, navigation, and tests.
- [x] Run the unchanged main-scheme simulator build.
- [x] Add migration-friendly exercise metadata while preserving existing field names, identifiers, relationships, delete rules, and snapshots.
- [x] Add idempotent built-in exercise upgrades and exact normalized-name linking for legacy planned exercises.
- [x] Build the model milestone successfully.

Acceptance: the existing SwiftData store remains eligible for lightweight migration, legacy plans keep fallback names, and completed history is never rewritten.

### Library/Calendar Milestone 2 — Exercise Library

- [x] Add Settings navigation, searchable/filterable/sortable available and archived lists, and clear empty states.
- [x] Add exercise details, recent performance, custom creation, editing, defaults, duplicate validation, archive/restore, and safe deletion.
- [x] Build the library milestone; focused tests remain part of final verification.

Acceptance: exercises are independently manageable and persist without duplicate insertion.

### Library/Calendar Milestone 3 — Plan integration and history compatibility

- [x] Replace plan exercise selection with the available library search/filter flow and in-flow custom creation.
- [x] Seed planned values from exercise defaults while preserving plan-specific overrides and order.
- [x] Keep current plan names synchronized by exercise identifier while completed session snapshots remain immutable.
- [x] Build plan integration and history compatibility; focused tests remain part of final verification.

Acceptance: renamed/archived definitions work in plans, missing definitions fall back to snapshots, and history remains unchanged.

### Library/Calendar Milestone 4 — Workout Calendar

- [x] Add a History List/Calendar switch, native monthly grid, previous/next/today navigation, indicators, and monthly summary.
- [x] Group completed sessions in memory by `Calendar.current.startOfDay(for: startedAt)` and exclude every non-completed status.
- [x] Add accessible day details with empty, single-workout, and multiple-workout states.
- [x] Build the calendar milestone; focused tests remain part of final verification.

Acceptance: completed workouts appear on their local start date, including cross-midnight sessions, with no per-cell database queries.

### Library/Calendar Milestone 5 — Final verification

- [x] Add focused exercise-library and calendar unit coverage.
- [x] Run the complete unit suite and final clean simulator build.
- [x] Build, install, launch, and run the domain suite on the connected physical iPhone; record the physical UI-runner limitation honestly.
- [x] Audit accessibility, Dark Mode, Dynamic Type, migration safety, and existing-feature regressions.

Acceptance: the main scheme builds, relevant tests pass, and physical results or honest device limitations are recorded.

## Workout Result Sharing

### Sharing Milestone 1 — Architecture audit and baseline

- [x] Inspect completed-session snapshots, exercise/set records, completion/history routes, existing metrics/formatters, assets, previews, and sharing APIs.
- [x] Confirm sharing can remain entirely local with no SwiftData schema or networking change.
- [x] Run the unchanged main-scheme simulator build.

Acceptance: the snapshot boundary, presentation entry points, rendering target, and baseline status are known before implementation.

### Sharing Milestone 2 — Stable share summary

- [x] Add an immutable `WorkoutShareSummary` built only from a completed `WorkoutSession` snapshot.
- [x] Keep duration/count/repetition/volume semantics consistent with the existing completion/history screens.
- [x] Add deterministic top-exercise selection, compact formatters, validation, and focused tests.
- [x] Build and test the summary milestone.

Acceptance: plan edits cannot alter an old share summary, private notes are absent, and empty/non-completed sessions fail clearly.

### Sharing Milestone 3 — Card and background system

- [x] Add one original premium 4:5 GymFlow card with controlled typography and concise hierarchy.
- [x] Add ten offline programmatic backgrounds with contrast metadata, manual selection, and non-repeating randomization.
- [x] Verify short/long titles, few/many exercises, large numbers, and stable selection.
- [x] Build the card milestone.

Acceptance: the dedicated card remains readable and visually balanced without relying on visible app screenshots or online assets.

### Sharing Milestone 4 — Rendering and native sharing

- [x] Render the dedicated card with `ImageRenderer` at 1080 × 1350 pixels.
- [x] Add a native `UIActivityViewController` share sheet with useful image metadata and user-friendly errors.
- [x] Add completion and history `Share Workout` entry points and a dedicated preview screen.
- [x] Build and test rendering dimensions plus integration.

Acceptance: both new and old completed sessions produce a sharp local image and open the system share destination picker.

### Sharing Milestone 5 — Final and physical verification

- [x] Run focused/full tests and a final clean simulator build.
- [x] Verify Dark Mode, Dynamic Type, accessibility, card previews, and exported pixel dimensions.
- [x] Build/install/launch on the paired iPhone where reachable and attempt completion/history share-sheet flows; the signed build succeeded, but the currently offline device prevented install/launch.
- [x] Update project documentation with exact results and honest human-only limitations.

Acceptance: GymFlow stays buildable, existing regressions pass, and physical sharing results are observed or precisely bounded.
