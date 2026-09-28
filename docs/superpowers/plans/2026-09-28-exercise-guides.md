# Exercise Guides Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship three silent, offline animated form guides for Barbell Bench Press, Barbell Squat, and Romanian Deadlift in Exercise Detail and Active Workout.

**Architecture:** A keyed guide catalog provides titles, resource names, cues and accessibility descriptions. A seed-version upgrade attaches optional stable keys to built-in definitions without changing workout snapshots. Deterministic vector source exports compact bundled MP4s; one AVKit sheet plays them independently of workout audio and timers.

**Tech Stack:** Swift 5, iOS 17+, SwiftUI, SwiftData, AVFoundation/AVKit, CoreGraphics and AVAssetWriter for the macOS export script, Swift Testing; no network or third-party dependency.

**Spec:** `docs/superpowers/specs/2026-09-28-exercise-guides-design.md`

## Global Constraints

- Exactly three initial guides: Barbell Bench Press, Barbell Squat, Romanian Deadlift.
- Each bundled clip is a small, silent MP4 showing start, controlled movement and return; words are SwiftUI text, never burned into pixels.
- Guide playback never pauses music or modifies the rest timer; Reduce Motion starts on a paused representative frame.
- The `ExerciseDefinition` key is optional and stable across later renames; custom and unrelated exercises remain unchanged, and legacy nil-ID workout snapshots are not guessed by name.
- Run a simulator build after each task; run relevant tests, semantic lint and a visual review before claiming completion. Record exact results in `PROGRESS.md`.

**Shared verification commands:** Build: `xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -sdk iphonesimulator -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/GymFlowDerivedData CODE_SIGNING_ALLOWED=NO build`. Full unit suite: `xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -destination 'platform=iOS Simulator,id=BE3E1DA1-5745-42DA-88B2-D3CAFF380FFF' -derivedDataPath /tmp/GymFlowDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:GymFlowTests test`. Lint: `xcrun swift-format lint --recursive --parallel GymFlow GymFlowActivityShared GymFlowLiveActivityExtension GymFlowTests`.

## Review Focus

- A custom exercise sharing a guide exercise's name must not acquire a guide; Task 1 tests this.
- A built-in renamed after key attachment must retain its guide; Task 1 tests this.
- An already-renamed legacy built-in or nil-ID session must not be guessed into a guide; Tasks 1 and 3 test this.
- Missing or unreadable MP4 must leave cues visible and show an error; Task 3 tests this.
- Reduce Motion must start paused and only play after a tap; Task 3 tests this.

## File Map

- `GymFlow/Models/ExerciseDefinition.swift`: optional `guideKey` persisted on the definition only.
- `GymFlow/Models/ExerciseGuide.swift`: catalog keyed by stable strings with titles, clip names, technique cues and accessibility descriptions.
- `GymFlow/Services/SampleDataSeeder.swift`: idempotent version-2 attachment to the three matching non-custom built-ins.
- `GymFlow/Services/ExerciseGuideResolver.swift`: fetch one definition by `exerciseID` on workout guide request; no history-wide `@Query`.
- `scripts/GenerateExerciseGuides.swift`: deterministic vector poses and MP4 export command for all three clips.
- `GymFlow/Resources/Guides/*.mp4`: bundled, silent final media; no runtime generator or video service.
- `GymFlow/Views/Exercises/ExerciseGuidePlayerView.swift`, `ExerciseDetailView.swift`, `GymFlow/Views/Workout/ActiveWorkoutView.swift`: shared accessible sheet, testable missing-resource/reduced-motion state and entry points.
- `GymFlowTests/ExerciseGuideTests.swift`, `GymFlowUITests/GymFlowUITests.swift`: catalog, seeding, resource, resolver and presentation tests.
- `README.md`, `PROJECT_SPEC.md`, `PLANS.md`, `PROGRESS.md`: scope, export command, build/test and manual-review record.

---

### Task 1: Stable Catalog and Seed Upgrade

**Files:** Create `ExerciseGuide.swift`, `ExerciseGuideResolver.swift`, `GymFlowTests/ExerciseGuideTests.swift`; modify `ExerciseDefinition.swift`, `SampleDataSeeder.swift`.

**Interfaces:** `ExerciseGuide.all: [ExerciseGuide]`, `ExerciseGuide.forKey(_ key: String?) -> ExerciseGuide?`, `ExerciseGuide.key(forBuiltInName: String) -> String?`, `ExerciseGuide.resourceURL(in bundle: Bundle) -> URL?`, `ExerciseGuide.cues: [String]`, `ExerciseGuideResolver.guide(for exerciseID: UUID?, context: ModelContext) throws -> ExerciseGuide?`; model property `guideKey: String?`. Keys are `bench-press`, `barbell-squat`, `romanian-deadlift`; seed version becomes `2`.

- [ ] **Step 1: Write failing tests.** `catalogHasThreeGuides`: `#expect(Set(ExerciseGuide.all.map(\.key)) == ["bench-press", "barbell-squat", "romanian-deadlift"])` and each cue list is nonempty. `seedUpgradeAttachesOnlyBuiltIns`: `#expect(bench.guideKey == "bench-press")`, likewise for squat/RDL, while a same-name custom definition in a separate store keeps `guideKey == nil`. `seedIsIdempotentAndRenameStable`: count unchanged after two seeds, and changing a keyed built-in's name preserves its key. `legacyNilIDAndAlreadyRenamedAreNotGuessed`: resolver returns `nil` for `nil` ID and an unkeyed, already-renamed legacy record.
- [ ] **Step 2: Run** `xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -destination 'platform=iOS Simulator,id=BE3E1DA1-5745-42DA-88B2-D3CAFF380FFF' -derivedDataPath /tmp/GymFlowDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:GymFlowTests/ExerciseGuideTests test`. **Expected:** fail on missing catalog/model key.
- [ ] **Step 3: Implement** the catalog and optional model field. In seed version 2, attach keys only to exact normalized built-in names with `isCustom == false`; retain an existing key; fetch by UUID in the resolver, never by historical name.
- [ ] **Step 4: Re-run the exact Task 1 test command.** **Expected:** four tests pass.
- [ ] **Step 5: Run** the generic simulator build from `AGENTS.md`. **Expected:** `BUILD SUCCEEDED`; commit Task 1 files.

### Task 2: Deterministic Silent Video Assets

**Files:** Create `scripts/GenerateExerciseGuides.swift`, three `GymFlow/Resources/Guides/*.mp4`; extend `ExerciseGuideTests.swift`.

**Interfaces:** Run `swift scripts/GenerateExerciseGuides.swift` from repo root to overwrite only the three named MP4 resources. Catalog resource names are `bench-press`, `barbell-squat`, `romanian-deadlift`; export 640×360 H.264 at 24 fps, approximately four seconds each, without an audio track.

- [ ] **Step 1: Write failing async resource tests.** For every catalog entry, `#expect(guide.resourceURL(in: .main) != nil)`; for the required URL, `#expect(try await asset.loadTracks(withMediaType: .video).count == 1)`, `#expect(try await asset.loadTracks(withMediaType: .audio).isEmpty)`, and `let duration = (try await asset.load(.duration)).seconds; #expect((3...6).contains(duration))`.
- [ ] **Step 2: Run the Task 1 test command.** **Expected:** resource assertions fail because clips are absent.
- [ ] **Step 3: Implement** a repeatable CoreGraphics/AVAssetWriter export script with a clear side view, simple person/bar/bench geometry and smooth start–movement–return poses for each lift. Keep all technique copy in the catalog, not the video. Export the three clips.
- [ ] **Step 4: Re-run the Task 1 test command.** **Expected:** media resource assertions pass. Generate or extract representative frames into `/tmp` and inspect each start, midpoint and return pose; adjust source if the movements are unclear.
- [ ] **Step 5: Run** the generic simulator build from `AGENTS.md`. **Expected:** `BUILD SUCCEEDED` and only the three named MP4s are bundled; commit script, clips and tests.

### Task 3: One Accessible Guide Sheet, Two Entry Points

**Files:** Create `ExerciseGuidePlayerView.swift`; modify `ExerciseDetailView.swift`, `ActiveWorkoutView.swift`, `GymFlowUITests.swift`, `README.md`, `PROJECT_SPEC.md`, `PLANS.md`, `PROGRESS.md`; extend `ExerciseGuideTests.swift`.

**Interfaces:** `ExerciseGuidePlayerView(guide: ExerciseGuide, bundle: Bundle = .main)` owns and releases its `AVPlayer`; `ExerciseGuidePlayerState(guide: ExerciseGuide, resourceURL: URL?)` exposes `cues: [String]` and `errorMessage: String?`; `ExerciseGuidePlaybackPolicy.startsPlaying(reduceMotion: Bool) -> Bool`. Active Workout caches guide availability after exercise selection via one-ID fetch and re-resolves by current `exerciseID` when the action is tapped. Text cues remain outside the player and visible on media failure.

- [ ] **Step 1: Write failing tests.** `#expect(!ExerciseGuidePlaybackPolicy.startsPlaying(reduceMotion: true))` and `#expect(ExerciseGuidePlaybackPolicy.startsPlaying(reduceMotion: false))`; for an empty bundle, `#expect(guide.resourceURL(in: emptyBundle) == nil)`, then `let state = ExerciseGuidePlayerState(guide: guide, resourceURL: nil); #expect(state.cues == guide.cues); #expect(state.errorMessage != nil)`; resolver returns `nil` for an unknown UUID. UI test `testExerciseGuideEntryPoints` finds **Watch Form Guide** in Exercise Detail and Active Workout for keyed built-ins, not an unrelated/custom exercise.
- [ ] **Step 2: Run** the Task 1 test command, then `xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -destination 'platform=iOS Simulator,id=BE3E1DA1-5745-42DA-88B2-D3CAFF380FFF' -derivedDataPath /tmp/GymFlowDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:GymFlowUITests/GymFlowUITests/testExerciseGuideEntryPoints test`. **Expected:** fail on missing sheet/entry points.
- [ ] **Step 3: Implement** the silent inline AVKit player, explicit play/pause/replay, looping only while presented, paused Reduce Motion start, accessible labels and large-text-friendly cue list. Add the detail action; in Active Workout fetch one definition on tap, then present the same sheet without touching `AudioPlayerService` or `RestTimerService`.
- [ ] **Step 4: Run** complete `GymFlowTests` and relevant `GymFlowUITests`. **Expected:** `TEST SUCCEEDED`; manually inspect normal/large text, music continuity and rest timer on simulator, then record iPhone checks separately if no signed device is available.
- [ ] **Step 5: Run** semantic lint, generic simulator build and `git diff --check`. **Expected:** zero semantic findings, `BUILD SUCCEEDED`, no whitespace errors; update docs and commit Task 3 files.
