# Release Stabilization Design

GymFlow's audited `main` branch remains the base. This stabilization changes only the five
confirmed defects: sample-plan reset identity, historical share-card wording, estimated 1RM
consistency, workout historical prefill, and explicit SwiftData migration safety. It does not add
features, redesign UI, merge Google Drive work, rewrite workout history, or delete a store after a
migration failure.

## Exercise identity during sample reset

`Reset Sample Plans` currently removes every `WorkoutPlan` and every `ExerciseDefinition`, while
retaining `WorkoutSession` snapshots that point to the deleted exercise UUIDs. The reset workflow
will move into `SampleDataSeeder` so it can be exercised without a Settings view. It will delete
only plans, retain all definitions, reset the sample-plan/library seed versions, save the deletions,
and invoke the existing normalized-name reconciliation. Existing matching definitions will be
reused, missing built-ins will be inserted, and custom exercises will remain untouched. A second
reset must make no additional definitions and must preserve the same IDs.

Historical `ExerciseRecord` values will not be mutated. Their `exerciseID` continues to resolve to
the retained definition, while `exerciseNameSnapshot` remains the readable historical name.

## Historical share-card context

The share summary will expose a deterministic context-heading helper that accepts a reference date
and calendar. A workout on the same local calendar day renders `TODAY'S WORKOUT`; any older or
future workout renders the neutral `WORKOUT SUMMARY`. The existing historical workout date remains
unchanged. The card hero and accessibility description will consume the same heading.

## Canonical estimated 1RM policy

`ExercisePerformanceService` remains the single owner of estimated 1RM:

- Formula: Epley, `weight * (1 + repetitions / 30)`.
- Minimum repetitions: 1.
- Maximum repetitions: 15.
- Valid weight: finite and greater than zero.
- Invalid input: return `nil`; never substitute raw weight and label it an estimate.

Personal Bests, Exercise Detail, Exercise Progress, the progression chart, and share-card PR logic
will all consume this implementation. Progress selection will ignore sets for which the canonical
calculation returns `nil`. This preserves the already-audited Personal Best semantics and removes
the separate 1...30 chart rule.

## Historical workout prefill

Prefill will search completed sessions from newest to oldest for each planned set number. It will
continue past a matching exercise record when that record does not contain a usable set. A usable
historical prefill is completed, is not a warm-up, has a finite nonnegative weight, and has positive
repetitions. ID-first exercise matching and exact normalized-name fallback for legacy nil-ID data
remain unchanged. When no usable historical set exists, the plan's weight and repetitions remain
the fallback.

## Explicit SwiftData migration boundary

The current nine persisted model types will be registered as explicit schema version 1.0.0 through
`VersionedSchema`. `GymFlowMigrationPlan` will list that schema and no migration stages because
there is no model-shape change in this task. Production and preview containers will use the shared
schema definition, and production creation will pass the explicit migration plan.

Compatibility will be tested with a disk-backed fixture created using the previous implicit schema,
then reopened through the versioned store. The test will verify important UUIDs, session/plan/set
relationships, values, and historical snapshot names. Container-open failures continue to surface
through the existing startup error UI; there is no destructive fallback.

This establishes the migration architecture but does not pretend to prove an unimplemented future
schema transition. Before changing a persisted model, development must freeze the preceding schema,
add a new schema version, declare a lightweight or custom stage, and extend the disk fixture.

## Verification

Each behavior change starts with a failing regression test. Targeted tests run after each fix,
followed by the full unit/UI suites, the main `GymFlow` simulator build, source typechecking if Xcode
remains environment-blocked, semantic lint, and `git diff --check`. Only tests actually executed will
be reported, and physical-iPhone status will remain unverified unless a device run occurs in this
task.
