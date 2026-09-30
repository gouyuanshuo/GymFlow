# Release Stabilization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this
> plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix only the five confirmed release-readiness defects on `main`, prove each correction
with regression tests, and leave a non-destructive explicit SwiftData V1 migration boundary before
Google Drive integration begins.

**Architecture:** Keep the existing offline SwiftUI/SwiftData design. Move sample reset into the
seeder as an idempotent domain operation, route every e1RM consumer through
`ExercisePerformanceService`, scan historical prefill per set instead of stopping at the newest
record, derive share wording from the workout date, and register the unchanged persisted models as
explicit schema V1 with an empty migration plan. No historical row is rewritten and no store is
deleted on error.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, Swift Testing, XCTest, Xcode/iOS Simulator.

**Spec:** `docs/superpowers/specs/2026-09-30-release-stabilization-design.md`

## Global constraints

- Remain on `main`; do not merge `feature/google-drive-exercise-guides` or copy Drive code.
- Preserve the existing uncommitted audit documentation and unrelated screenshot.
- Do not add product features or redesign screens.
- Never delete workout history or use a destructive migration fallback.
- Add a failing regression test before each production change and observe the expected failure.
- Build the `GymFlow` main app scheme, never the Live Activity extension as an application.
- Record exact executed commands/results in `PROGRESS.md`; update `PLANS.md` and
  `AUDIT_REPORT.md` only after verification.

---

### Task 1: Establish the execution baseline

**Files:**
- Read only: `GymFlow.xcodeproj/project.pbxproj`, `.github/workflows/*`, current source/test files
- Track only: this plan's checkbox state

- [x] **Step 1: Confirm workspace state.** Run `git status --short`, `git branch --show-current`,
  `git rev-parse HEAD`, and `git worktree list`. Confirm the only intentional pre-task changes are
  the audited `PLANS.md`, `PROGRESS.md`, `AUDIT_REPORT.md`, and unrelated screenshot plus the
  approved design/plan documents.
- [x] **Step 2: Resolve the local test destination.** Run `xcrun simctl list devices available` and
  record an installed iPhone simulator UDID. If CoreSimulator is unavailable, record that exact
  blocker and retain the generic simulator build/direct typecheck fallbacks.
- [x] **Step 3: Baseline compile/test signal.** Run the narrowest viable existing unit test command
  before changes, without claiming suites that do not execute. Preserve the command output in the
  execution ledger.

### Task 2: Preserve exercise identity during Reset Sample Plans

**Files:**
- Modify: `GymFlow/Services/SampleDataSeeder.swift`
- Modify: `GymFlow/Views/Settings/SettingsView.swift`
- Modify: `GymFlowTests/ExerciseLibraryCalendarTests.swift`

**Interface:**

```swift
static func resetSamplePlans(
    context: ModelContext,
    defaults: UserDefaults = .standard
) throws
```

The operation removes `WorkoutPlan` rows only, preserves every `ExerciseDefinition`, resets sample
seed markers, then calls existing seed/reconciliation logic.

- [x] **Step 1: RED identity test.** Seed an in-memory store, retain the built-in definition UUID,
  insert a completed historical session whose `ExerciseRecord.exerciseID` points to it, invoke the
  current reset workflow through the proposed interface, and assert the definition UUID and
  historical link survive. Run the focused test and observe failure because the interface/behavior
  does not exist yet.
- [x] **Step 2: RED PB/idempotence assertions.** In the same fixture, assert
  `ExercisePerformanceService.summary` still returns the historical Personal Best after reset, then
  reset a second time and assert normalized exercise names are unique and the definition count/IDs
  are unchanged. Observe RED before implementation.
- [x] **Step 3: GREEN reset operation.** Implement `SampleDataSeeder.resetSamplePlans`: fetch and
  delete plans, preserve definitions/sessions, set the plan/library seed markers so canonical
  built-ins and sample plans reconcile, save, and call `seedIfNeeded`. Do not modify an
  `ExerciseRecord` or create a replacement for an already matching normalized definition.
- [x] **Step 4: Wire Settings and correct its copy.** Replace `SettingsView.resetSamples` deletion
  logic with the service call. Update only reset-specific confirmation/success wording so it no
  longer claims the exercise library will be replaced; leave the separate Delete All Workout Data
  action unchanged.
- [x] **Step 5: Verify and commit.** Run the focused reset tests, then the complete unit target if
  available. Run the generic `GymFlow` build. Inspect the diff for any history mutation and commit
  only Task 2 files plus checkpoint documentation.

### Task 3: Make historical share-card wording truthful

**Files:**
- Modify: `GymFlow/Models/WorkoutShareSummary.swift`
- Modify: `GymFlow/Views/Share/WorkoutShareCardView.swift`
- Modify: `GymFlow/Views/Share/WorkoutShareCardSections.swift`
- Modify: `GymFlowTests/WorkoutSharingTests.swift`

**Interface:**

```swift
func contextHeading(
    relativeTo referenceDate: Date,
    calendar: Calendar
) -> String
```

- [x] **Step 1: RED deterministic tests.** Use a fixed Gregorian calendar/time zone and fixed
  dates. Assert same-local-day summaries return `TODAY'S WORKOUT`, past summaries return
  `WORKOUT SUMMARY`, and `summary.date` remains the original historical date. Run the focused
  sharing tests and observe RED.
- [x] **Step 2: GREEN heading flow.** Add the pure helper to `WorkoutShareSummary`, pass its result
  into `ShareCardHeroPanel`, and replace the hard-coded label. Make the accessibility description
  use the same contextual wording. Do not change renderer dimensions or date formatting.
- [ ] **Step 3: Render regression.** Re-run summary tests and the existing 1179×2556 render tests to
  ensure the label change does not break export.
- [ ] **Step 4: Verify and commit.** Run the focused/full unit target and generic app build, inspect
  the rendered-card diff if an attachment can be produced, then commit Task 3 files.

### Task 4: Centralize the estimated 1RM policy

**Files:**
- Modify: `GymFlow/Services/ExercisePerformanceService.swift`
- Modify: `GymFlow/Utilities/StrengthProgressionMetrics.swift`
- Modify: `GymFlow/Components/StrengthProgressionChart.swift`
- Modify: `GymFlow/Views/History/ExerciseProgressView.swift`
- Modify: `GymFlowTests/ExercisePerformanceServiceTests.swift`
- Modify: `GymFlowTests/StrengthProgressionTests.swift`
- Modify if wording references the old range: `PROJECT_SPEC.md`, `README.md`

**Canonical policy:**

```swift
// Epley: weight * (1 + Double(repetitions) / 30)
// Valid only for finite weight > 0 and repetitions in 1...15; otherwise nil.
static func estimatedOneRepMax(weight: Double, repetitions: Int) -> Double?
```

- [x] **Step 1: RED boundary tests.** Add explicit cases for reps 0, 1, 15, and 16; zero,
  negative, infinity, and NaN weight; and expected Epley values at both valid boundaries. Existing
  service behavior should satisfy some assertions, establishing the canonical contract.
- [x] **Step 2: RED progress-consumer tests.** Change progression expectations so an unsupported
  high-rep set has no e1RM, all-invalid sets yield no strongest set/chart point, and a valid set is
  selected over a heavier invalid set. Run focused tests and observe failures from the separate
  1...30/raw-weight fallback.
- [x] **Step 3: GREEN shared calculation.** Make `StrengthSetMetrics.estimatedOneRepMax` optional
  and delegate directly to `ExercisePerformanceService`. Make `strongestSet` compare only valid
  estimates. Make `StrengthDataPoint` creation failable (or require a validated shared estimate)
  so charts never label raw weight as e1RM. Update `ExerciseProgressView` to skip sessions without a
  canonical valid e1RM point.
- [x] **Step 4: Verify all consumers.** Trace and test Personal Best summary/events, Exercise
  Detail, Exercise Progress, chart construction, and share-card PR building. Confirm no other
  formula or repetition ceiling remains with `rg`.
- [ ] **Step 5: Verify and commit.** Run focused performance/progression/sharing tests, all unit
  tests, generic app build, and semantic lint. Commit Task 4 files.

### Task 5: Search backward for a valid workout prefill

**Files:**
- Modify: `GymFlow/Services/WorkoutService.swift`
- Modify: `GymFlowTests/GymFlowTests.swift`

**Interface:** Keep `WorkoutService.makeSession` unchanged. Replace the single newest-record lookup
with a per-set historical lookup over completed sessions sorted newest-first.

- [x] **Step 1: RED newest-incomplete regression.** Create a newer completed session with a
  matching exercise but only an incomplete set and an older completed session with a valid
  completed working set. Assert the new session receives the older weight/reps. Run the focused
  test and observe current plan fallback instead.
- [x] **Step 2: RED invalid-history coverage.** Add cancelled, warm-up, non-finite/negative weight,
  zero-repetition, and mismatched-exercise records ahead of a valid older record. Assert they are
  ignored. Add a multi-set case proving each target set finds its newest valid matching set and a
  no-history case proving plan fallback remains.
- [x] **Step 3: GREEN backward scan.** Build the `ExerciseIdentity` once per planned exercise. For
  each target set number, lazily scan completed sessions newest-first and all matching records until
  finding a completed non-warm-up set with finite nonnegative weight and positive reps. Preserve
  ID-first matching and legacy normalized-name fallback.
- [ ] **Step 4: Verify and commit.** Run focused workout-service tests, all unit tests, and the
  generic build. Inspect for changes to session snapshots or warm-up creation; commit Task 5 files.

### Task 6: Establish explicit non-destructive SwiftData migration safety

**Files:**
- Add: `GymFlow/Models/GymFlowSchema.swift`
- Modify: `GymFlow/Services/GymFlowDataStore.swift`
- Modify: `GymFlow/Utilities/PreviewData.swift`
- Add: `GymFlowTests/GymFlowDataStoreMigrationTests.swift`
- Inspect only unless required for compilation: `GymFlow/GymFlowApp.swift`,
  `GymFlow.xcodeproj/project.pbxproj`

**Interfaces:**

```swift
enum GymFlowSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static let models: [any PersistentModel.Type] = [/* existing nine model types */]
}

enum GymFlowMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [GymFlowSchemaV1.self]
    static let stages: [MigrationStage] = []
}
```

`GymFlowDataStore` will expose the shared current `Schema` and an internal configuration-injection
path for disk migration tests, while its production `makeContainer()` call stays source-compatible.

- [x] **Step 1: RED schema contract test.** Assert the current version is exactly 1.0.0, all nine
  expected persistent model types are registered, and the migration plan includes V1. Run the
  focused test before adding the schema types and observe RED.
- [x] **Step 2: RED disk compatibility fixture.** In a temporary directory, create and close a
  persistent store with the pre-change implicit `Schema`. Insert an `ExerciseDefinition`, linked
  `WorkoutPlan`/`PlannedExercise`, completed `WorkoutSession`/`ExerciseRecord`/`WorkoutSetRecord`,
  plus stable UUIDs and a historical snapshot name. Reopen the same URL through the proposed
  versioned `GymFlowDataStore`; observe failure before the new interface exists.
- [x] **Step 3: GREEN V1 registration.** Add `GymFlowSchemaV1` and `GymFlowMigrationPlan`, construct
  the production container with `migrationPlan:`, and make PreviewData use the same complete schema
  (including playlists). Do not add a delete/recreate catch path.
- [x] **Step 4: Prove retained data.** Complete the disk test assertions for session status/date,
  definition UUID, planned/session exercise UUIDs, workout/set UUIDs and values, relationship
  ordering, and unchanged historical snapshot names. Add a negative inspection asserting no reset
  or store deletion code exists in `GymFlowDataStore`.
- [x] **Step 5: Verify migration behavior.** Run the migration test repeatedly against fresh
  temporary stores, then all unit tests and the generic app build. Document that this validates
  adoption of an implicit V1 store, not a future V1→V2 transformation.
- [ ] **Step 6: Verify and commit.** Run semantic lint/diff checks and commit Task 6 files.

### Task 7: Full release-stabilization gate and documentation

**Files:**
- Modify: `AUDIT_REPORT.md`
- Modify: `PLANS.md`
- Modify: `PROGRESS.md`
- Modify only if test infrastructure requires it: existing CI scripts/configuration

- [ ] **Step 1: Main app build.** Run:

  ```bash
  xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -sdk iphonesimulator \
    -configuration Debug -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath /tmp/GymFlowDerivedData CODE_SIGNING_ALLOWED=NO build
  ```

  Record success/failure, warnings, and errors exactly.
- [ ] **Step 2: Unit tests.** Run the entire `GymFlowTests` target on the installed simulator. Record
  total passed/failed/skipped from actual output. If CoreSimulator prevents execution, run every
  viable direct SDK/typecheck harness and explicitly label the normal test run blocked.
- [ ] **Step 3: UI tests.** Run every locally available partition previously audited: standard,
  workout flows, accessibility light, and accessibility dark. Record each command and outcome; do
  not convert environment-blocked tests into passes.
- [ ] **Step 4: Static gates.** Run `git diff --check` and:

  ```bash
  xcrun swift-format lint --recursive --parallel \
    GymFlow GymFlowActivityShared GymFlowLiveActivityExtension GymFlowTests
  ```

  Typecheck all application, extension, and test sources if the normal build remains blocked.
- [ ] **Step 5: Scope and security inspection.** Confirm no Google Drive branch merge, Drive source,
  UI redesign, charts feature addition, unit conversion, RIR, plate-calculator, or music changes
  entered the diff. Confirm no database deletion/reset fallback was added.
- [ ] **Step 6: Read-only whole-change review.** Apply the code-review checklist to the complete
  diff. Resolve any Critical/Important finding through a fresh RED→GREEN cycle, then rerun affected
  gates. Multi-agent review is unavailable by session instruction, so report that limitation rather
  than claiming an independent reviewer.
- [ ] **Step 7: Documentation.** Update the audit result, feature matrix/risks, milestone
  checkboxes, exact commands/results, migration boundary, remaining risks, and physical-device
  status. Do not claim a device run unless performed during this task.
- [ ] **Step 8: Final status.** Report exact files changed, root cause/fix/tests for each defect,
  build/test results, remaining migration risks, current branch/HEAD/status, and whether evidence
  supports using `main` as the Google Drive integration base. Stop without starting the Drive work.
