# GymFlow Engineering Guide

## Objective

GymFlow is a native, offline-first iPhone fitness application for planning workouts, recording sessions and rest periods, reviewing history, and playing audio imported from Files. It uses Apple frameworks only and has no accounts, network backend, analytics, advertising, or subscriptions.

## Architecture

- Use SwiftUI for UI, SwiftData for persistence, AVFoundation for local playback, and UniformTypeIdentifiers/FileImporter for imports.
- Organize production code under `App`, `Models`, `Views`, `ViewModels`, `Services`, `Components`, `Utilities`, and `Resources`.
- Follow lightweight MVVM: views render state and route user intent; services/view models own workflow and business logic.
- Keep persisted history snapshot-based so later plan edits never rewrite completed sessions.
- Inject deterministic collaborators (clock, file storage, playlist logic) where it improves testing.
- Keep the application fully useful offline and avoid third-party dependencies unless documented and essential.

## Build and test

Inspect destinations before selecting a named simulator:

```bash
xcrun simctl list devices available
```

Reliable compile-only simulator build:

```bash
xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -sdk iphonesimulator -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/GymFlowDerivedData CODE_SIGNING_ALLOWED=NO build
```

Unit tests (replace the destination with an installed device):

```bash
xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -destination 'platform=iOS Simulator,id=<DEVICE-UDID>' -derivedDataPath /tmp/GymFlowDerivedData CODE_SIGNING_ALLOWED=NO test
```

Run a build after every meaningful change and after each milestone. Continue fixing implementation compiler errors and test failures until the relevant command succeeds.

## Coding conventions

- Swift 5 language mode, four-space indentation, descriptive names, and small focused types.
- Avoid force unwraps and `fatalError` in normal runtime paths. Surface understandable errors to the UI.
- Validate names and numeric input at workflow boundaries.
- Use stable identifiers, relative stored filenames, semantic colors, Dynamic Type, SF Symbols, and accessible labels.
- Use ordered relationships through explicit `sortOrder` values and sorted accessors.
- Do not put production mock data in views; keep seeding in a dedicated service and test fixtures in test targets.

## Formatting and lint

Style is defined by `.swift-format`, read by Apple's `swift-format` (bundled with Xcode, so no
dependency is added). It encodes the conventions above: four-space indentation, a 100-column limit,
no force unwraps or force `try`, ordered imports, and triple-slash documentation comments.

Lint before opening a change:

```bash
xcrun swift-format lint --recursive --parallel GymFlow GymFlowActivityShared GymFlowLiveActivityExtension GymFlowTests
```

Semantic rules must stay at zero findings. The pretty printer's whitespace opinions differ from the
hand-laid-out SwiftUI bodies in this project; reflowing them with `swift-format format -i` is a
deliberate, separate commit rather than something to mix into a feature change.

## Performance conventions

- Push filters into the store. A `@Query` predicate — see `WorkoutSession.predicate(status:)` — beats
  fetching every session and filtering in the view, which faults in the whole relationship graph.
- Do not hold a `@Query` for data a single action needs. Fetch it with a `FetchDescriptor` at the
  moment of use, or the screen re-reads those tables on every redraw.
- Read a derived value once per `body` and pass it down. `orderedSets`, `orderedExerciseRecords`, and
  `totals` all rescan or re-sort on each access, and screens with a running timer redraw every second.
- Cache a scan over history in `@State`, refreshed by `task`/`onChange`, rather than recomputing it in
  `body` — a bound `TextEditor` re-runs `body` on every keystroke.

## Project hygiene

- Update `PLANS.md` checkboxes and `PROGRESS.md` after each milestone, important failure, or architectural decision.
- Record exact build/test commands and outcomes in `PROGRESS.md`.
- Never replace working behavior with a placeholder to make a build pass.
- Preserve working project configuration and user data unless a migration or configuration change is required and documented.
- Isolate optional features if they threaten core stability; document the limitation.
