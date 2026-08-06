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

## Project hygiene

- Update `PLANS.md` checkboxes and `PROGRESS.md` after each milestone, important failure, or architectural decision.
- Record exact build/test commands and outcomes in `PROGRESS.md`.
- Never replace working behavior with a placeholder to make a build pass.
- Preserve working project configuration and user data unless a migration or configuration change is required and documented.
- Isolate optional features if they threaten core stability; document the limitation.
