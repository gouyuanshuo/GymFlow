# GymFlow Product Specification

## Product goal and scope

GymFlow is a personal, native iPhone fitness app that works entirely offline. A user can create and edit ordered workout plans, add library or custom exercises, start a plan, log every set's weight and repetitions, use a resilient rest timer, review snapshot-based workout history and exercise progress, import local audio from Files, and control a persistent workout playlist while navigating the app.

GymFlow must not include authentication, cloud services, remote databases, backend APIs, analytics, advertisements, subscriptions, AI services, or extraction of protected subscription music.

## Platform and technology

- Swift, SwiftUI, SwiftData, AVFoundation, UniformTypeIdentifiers, SwiftUI FileImporter, XCTest, and Swift Testing.
- Native Apple frameworks only; no UIKit storyboards, Core Data, React Native, Flutter, Firebase, or Supabase.
- iPhone target, portrait-first UI, iOS 17 minimum deployment target, and the current installed stable SDK.
- Dark Mode, Dynamic Type where practical, semantic colors, system fonts/spacing, SF Symbols, accessible controls, and large workout-friendly touch targets.
- Lightweight MVVM structure with business rules outside large view bodies, reusable components, explicit errors, no force unwraps, and localizable user-facing copy.

## Persisted model requirements

### WorkoutPlan

UUID id, name, notes, created/updated dates, sort order, and an ordered collection of planned exercises. A name is required.

### ExerciseDefinition

UUID id, name, primary and optional secondary muscle groups, equipment, optional default sets/repetitions/rest, notes, custom/archive flags, and created/updated dates. Seed a manageable built-in strength, core, and cardio library exactly once per library version. Users can search, filter, sort, create, edit, archive, restore, and safely delete unused custom exercises. Duplicate names are rejected using trimmed, case/diacritic-insensitive exact matching.

### PlannedExercise

UUID id, optional exercise identifier, exercise-name snapshot, target sets/repetitions/weight, rest seconds, notes, and sort order. Order is preserved. Sets are at least one; repetitions, weight, and rest are nonnegative.

### WorkoutSession

UUID id, optional source plan UUID, plan-name snapshot, start/completion dates, notes, status (`planned`, `active`, `completed`, or `cancelled`), and ordered exercise records. Active sessions persist and restore. History remains readable after a source plan changes or is deleted.

### ExerciseRecord and WorkoutSetRecord

Each exercise record has a UUID, optional source exercise UUID, name snapshot, sort order, notes, configured rest seconds, and ordered sets. Each set has a UUID, set number, nonnegative weight/repetitions, completion state/date, and warm-up flag.

### ImportedTrack

UUID id, title, artist, stable stored filename, original filename, extension, optional duration, creation date, and sort order. Imported files are copied to app-owned Application Support storage; no temporary absolute picker URL is persisted. Duplicate imports receive unique filenames and deletion removes both the file and record.

## Navigation and screens

The root is a five-tab `TabView`: Today, Plans, History, Music, and Settings. A mini-player remains available above tab content when a track is loaded.

### Today

Show the date, selected plan, summary, exercise count, expected duration, most recent completion date, plan picker, prominent Start Workout action, now-playing access, active-session resume, and an empty state.

### Plans and plan editor

List, create, rename, edit notes, duplicate, delete with confirmation, reorder where practical, and open plans. The editor supports safe save/cancel, filtered available-library selection, in-flow custom exercise creation, removal/reordering, and editing target sets, repetitions, weight, rest, and notes without accidental loss. Definition defaults prefill a new plan row but never prevent plan-specific overrides. Current definition names are used by linked plans; missing definitions fall back to the stored planned-exercise snapshot.

### Active workout and completion

Show workout name, elapsed time, exercise progress/current exercise, prior performance, all editable sets, completion toggles, warm-up options, add/remove extra set, exercise notes, previous/next controls, rest timer, compact music controls, finish, and confirmed cancel. Save every change immediately. Completing a set starts configured rest, gives optional haptics, and preserves the session across interruptions. Values start from useful plan targets and remain editable. Completion shows duration, completed exercise/set counts, repetitions, training volume (`sum(weight * repetitions)`), editable notes, a Share Workout action, and a save/return action.

### Rest timer

Dedicated deadline-based service supports start, pause/resume, cancel/restart, skip, add 30 seconds, remaining time, completion callback, persistence, and background/foreground recovery. Optional haptic and local sound fire on completion.

### History and progress

Completed sessions are newest first and searchable by plan/exercise. History switches between List and a Monday-first monthly Calendar without adding another tab. Calendar training days are grouped in memory by `Calendar.current.startOfDay(for: session.startedAt)`, so cross-midnight workouts belong to their local start date and cancelled/active/planned sessions are excluded. Month navigation, current-month return, accessible workout indicators, monthly workout/day/time totals, and empty/single/multiple-workout day sheets are supported. Read-only details show times, notes, all exercises and completed sets, total volume, and a Share Workout action. Entries can be deleted with confirmation. Exercise progress and definition details show dates, best/recent completed sets; charts remain optional.

### Workout result sharing

Completed workouts can create a private, local-only `WorkoutShareSummary` from the historical session snapshot. A dedicated 4:5 card displays GymFlow branding, date, duration, exercise/set/repetition/volume metrics, and up to three deterministic high-volume exercise highlights; notes, music, paths, identifiers, and device data are excluded. Ten original programmatic backgrounds support one-time random selection, non-repeating randomization, and manual choice. Native `ImageRenderer` exports 1080 × 1350 pixels, then `UIActivityViewController` provides system destinations such as Messages, AirDrop, Files, and installed social apps. No share record, account, upload, network, or Photos permission is required.

### Music and Now Playing

Import common AVFoundation-supported local audio via FileImporter. Display a persisted playlist and support play/pause, previous/next, seek, shuffle, repeat off/one/all, reorder where practical, and confirmed deletion. Missing, unreadable, unsupported, and duplicate files produce user-friendly outcomes. Now Playing shows track metadata, progress/duration, transport, shuffle, and repeat. Playback state lives in a dedicated shared audio service so navigation does not stop audio. Background audio and lock-screen controls are later enhancements if capability configuration is safe.

### Settings

Default kilograms unit, default rest duration, timer sound and haptics preferences, system appearance, app version, sample-data reset, strongly confirmed workout-data deletion, and strongly confirmed imported-audio deletion. No account settings.

## First-launch data

Seed the exercise library and exactly three plans only when no plans exist and initial seeding has not completed:

- Chest and Arms: Bench Press 4x8 at 60 kg/180 s; Incline Dumbbell Press 4x10 at 20 kg/120 s; Cable Fly 3x12 at 15 kg/90 s; Biceps Curl 4x10 at 12 kg/90 s; Triceps Pushdown 4x12 at 20 kg/90 s.
- Back and Shoulders: Lat Pulldown 4x10 at 55 kg/120 s; Seated Cable Row 4x10 at 50 kg/120 s; One-arm Dumbbell Row 4x10 at 24 kg/120 s; Dumbbell Shoulder Press 4x10 at 16 kg/120 s; Lateral Raise 4x12 at 7 kg/75 s.
- Legs: Barbell Squat 4x8 at 60 kg/180 s; Leg Press 4x10 at 120 kg/180 s; Romanian Deadlift 4x10 at 50 kg/150 s; Leg Curl 4x12 at 35 kg/90 s.

## Quality and verification

Unit coverage includes volume, plan duplication, session creation, immutable history snapshots, exercise creation/duplicates/defaults/archive/persistence/plan linking, local-day calendar grouping and summaries, share-summary metrics/formatting/highlight selection/background state/export dimensions, deadline timer math, unique audio destinations, playlist navigation/shuffle/repeat, and validation. Focused UI paths cover the workout, workout sharing, and read-only Exercise Library/Calendar navigation where reliable. Every milestone requires an app build and applicable tests. The final audit searches TODO/FIXME/placeholders/force unwraps, reviews relationships/file deletion/restoration, runs tests and a clean simulator build, and records commands, results, manual capability steps, and honest limitations.
