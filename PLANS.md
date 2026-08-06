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
