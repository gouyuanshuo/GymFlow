# UI/UX Modernization Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct the reviewed numerical, history, timer, readability, and motion regressions before merging the UI/UX branch.

**Architecture:** Work on the modernization branch in the project's sole root worktree, preserving the unrelated screenshot there. Use deterministic calculation/service tests for plate and timer behavior, route chart metrics through existing history values, and apply adaptive foreground roles without changing neon decoration. Preserve SwiftData and existing native services.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, Charts, XCTest/Swift Testing, iOS Simulator.

**Spec:** `docs/superpowers/specs/2026-09-29-ui-ux-hardening.md`

## Global Constraints

- Apple frameworks only; fully useful offline; no analytics, ads, subscriptions, or backend.
- Keep session history snapshot-based and never rewrite completed records.
- Preserve existing rest notifications, Live Activity behavior, and imported-audio service ownership.
- Build after each meaningful change; record exact commands/outcomes in `PROGRESS.md` and mark milestones in `PLANS.md`.
- Semantic `swift-format` findings must stay at zero; do not reformat unrelated SwiftUI layout.

## Review Focus

- A 24 kg target on a 20 kg bar can use four 0.5 kg plates per side despite greedy 1.25 + 0.5 kg being short: exact load wins.
- Switching from a 15 kg to a 20 kg bar at a 15 kg target must not say the empty bar matches the target.
- A session with 100 kg × 1 and 90 kg × 10 must report a 100 kg best weight even if e1RM chooses the other set.
- A legacy persisted rest state lacks any new interval-duration field: restore a valid ring and preserve the old restart duration.
- Accessibility text and Reduce Motion must not hide controls or start repeating decoration.

---

### Task 1: Exact plate loading and truthful labels

**Files:**
- Modify: `GymFlow/Utilities/PlateCalculator.swift`, `GymFlow/Components/PlateCalculatorSheet.swift`
- Test: `GymFlowTests/PlateCalculatorTests.swift`

**Interfaces:**
- Consumes: existing `PlateCalculator.calculate(targetWeight:barWeight:availablePlates:) -> PlateLoadingResult`.
- Produces: the same result interface with a closest-not-above target and minimal-plate selection; `OlympicPlate.displayName` preserves hundredths.

- [ ] **Step 1: RED tests.** Add literal expectations for 24 kg on a 20 kg bar (four 0.5 kg plates per side, zero remainder) and every standard plate label including `1.25`. Run `xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -destination 'platform=iOS Simulator,id=<INSTALLED-UDID>' -derivedDataPath /tmp/GymFlowDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:GymFlowTests/PlateCalculatorTests test`; expect failures in those new assertions.
- [ ] **Step 2: GREEN implementation.** Search integer quarter-kilogram units for maximal load not above target, minimizing plate count on ties; keep descending loaded order. Format plate labels with at most two decimal places without dropping significant hundredths. Add a UI test that changes from a 15 kg bar at a 15 kg target to a 20 kg bar and expects the displayed target to become 20 kg; watch RED, then clamp `targetWeight` to the newly selected `barWeight` on bar changes and watch GREEN.
- [ ] **Step 3: Verify.** Re-run targeted tests, all unit tests, generic simulator build, and semantic lint. Record commands/outcomes, then commit task files and milestone documentation.

### Task 2: Truthful strength metrics and accessible set history

**Files:**
- Modify: `GymFlow/Components/StrengthProgressionChart.swift`, `GymFlow/Views/History/ExerciseProgressView.swift`
- Test: new `GymFlowTests/StrengthProgressionTests.swift`; modify `GymFlowUITests/GymFlowUITests.swift`

**Interfaces:**
- Consumes: `ExerciseProgressView.bestWeight`, completed set snapshots, `StrengthDataPoint`.
- Produces: `StrengthProgressionChart(dataPoints:bestWeight:)`, one shared e1RM calculation used for point selection and plotting, a horizontally scrollable recent-set row with stable accessibility identifiers.

- [ ] **Step 1: RED tests.** A session with `100 × 1` and `90 × 10` selects the higher valid e1RM point but reports best weight `100`; a `50 × 40` set cannot beat a valid `70 × 5` point by applying an unsupported high-rep formula. Add a UI flow with at least six completed sets and assert the last set capsule becomes reachable by horizontal scrolling. Run the relevant focused unit/UI tests and observe the expected failures.
- [ ] **Step 2: GREEN implementation.** Pass `bestWeight` separately to the chart; extract and use one e1RM policy (matching the existing `StrengthDataPoint` 1–30 rep rule); wrap set capsules in an explicitly labelled horizontal `ScrollView` with stable per-set identifiers.
- [ ] **Step 3: Verify.** Run focused tests, full unit suite, generic simulator build, and semantic lint; record commands/outcomes and commit.

### Task 3: Stable rest-ring progress and accessible controls

**Files:**
- Modify: `GymFlow/Services/RestTimerService.swift`, `GymFlow/Services/RestTimerStorage.swift`, `GymFlow/Components/RestTimerRingCard.swift`
- Test: `GymFlowTests/GymFlowTests.swift`; modify `GymFlowUITests/GymFlowUITests.swift`

**Interfaces:**
- Consumes: existing persisted `originalDuration` (restart length), `remainingSeconds`, pause/restore/extension controls.
- Produces: a separately persisted current interval duration and a clamped `remaining / intervalDuration` fraction; +30 extends interval duration but `restart()` still uses original configured duration.

- [ ] **Step 1: RED tests.** Assert a new 30-second and 180-second timer each start at fraction 1; refresh halves a 30-second timer; pause/restore preserves the denominator; +30 increases denominator and remaining without exceeding 1; a legacy persisted timer without the new field restores a valid denominator; restart retains the configured duration. Run focused rest tests and observe failures.
- [ ] **Step 2: GREEN service.** Persist a new `intervalDuration` field, include it in migration/clear paths, and expose a bounded progress value. Fall back to a safe max of old `originalDuration` and current remaining for legacy state. Do not change notification scheduling or Live Activity deadlines.
- [ ] **Step 3: RED/GREEN UI.** Add UI assertions for the existing “Rest time remaining” and “More timer options” labels and accessible controls at accessibility text size; then restore a two-row accessibility-size control layout and scalable countdown typography. Suppress repeating pulse under Reduce Motion.
- [ ] **Step 4: Verify.** Run focused/full tests, generic simulator build, and semantic lint; record commands/outcomes and commit.

### Task 4: Adaptive readable accents and reduced decorative motion

**Files:**
- Modify: `GymFlow/Utilities/GymTheme.swift`, foreground uses in `GymFlow/Views/Today/TodayView.swift`, `GymFlow/Views/Workout/WorkoutCompletionView.swift`, `GymFlow/Components/WorkoutSetCard.swift`, `GymFlow/Components/StrengthProgressionChart.swift`, `GymFlow/Components/PlateCalculatorSheet.swift`, `GymFlow/Components/RestTimerRingCard.swift`, and `GymFlow/Components/ConfettiCanvas.swift`
- Test: new `GymFlowTests/GymThemeTests.swift`; modify `GymFlowUITests/GymFlowUITests.swift`

**Interfaces:**
- Consumes: neon `GymTheme.volt`, `.cyan`, `.gold`, `.coral` for decoration and fills.
- Produces: adaptive foreground variants for light/dark text and tint on adaptive cards; Reduce Motion gives a static celebration instead of timeline confetti.

- [ ] **Step 1: RED tests.** Resolve each foreground variant in light/dark traits and check at least 4.5:1 contrast against the corresponding system background; assert Reduce Motion suppresses repeating celebration/pulse in UI policy or UI tests. Run focused tests and observe failures.
- [ ] **Step 2: GREEN implementation.** Add dynamic foreground colors, use them only where the accent is text/outline/control tint on adaptive surfaces, and keep the neon fills/gradients where dark text or a dark surface provides contrast. Gate confetti timeline/haptic and ring pulse by `accessibilityReduceMotion`.
- [ ] **Step 3: Verify.** Run focused/full tests, generic simulator build, semantic lint, and visual inspection in light/dark and accessibility text sizes. Record exact outcomes and commit.

### Task 5: Branch-wide gate

**Files:**
- Modify: `PLANS.md`, `PROGRESS.md`

**Interfaces:**
- Produces: reviewed, clean `feature/ui-ux-modernization` ready for integration with the Drive/guides branch in the sole root worktree.

- [ ] **Step 1: Run gate.** Run `git diff --check`, `xcrun swift-format lint --recursive --parallel GymFlow GymFlowActivityShared GymFlowLiveActivityExtension GymFlowTests`, the generic simulator build, and all-target simulator tests. Expected: semantic lint zero and all tests pass; record the exact commands/results, including any pre-existing or environmental failures.
- [ ] **Step 2: Review and commit.** Request a fresh read-only whole-branch review; resolve Critical/Important findings by RED→GREEN test cycles; commit the final review fixes and documentation.
