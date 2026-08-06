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
