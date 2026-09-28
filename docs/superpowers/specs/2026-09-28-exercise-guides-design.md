# Exercise guidance animation design

## Intent and scope

GymFlow's owner wants short exercise guidance videos for Barbell Bench Press, Barbell Squat, and Romanian Deadlift. The first release uses simple original animations, not filmed footage or links to third-party videos. They are available offline and can be watched from Exercise Detail or while an active workout is open.

## Content and presentation

Create three small, silent MP4 clips from deterministic vector drawings. Each clip shows one controlled repetition from a useful viewing angle, with recognizable equipment and start, movement, and return phases. Keep technique words outside the rendered pixels so Dynamic Type and VoiceOver can read them. The clips contain no audio track, allowing workout music to continue.

The guide sheet shows the exercise title, an inline player with play/pause and replay controls, and concise text cues. Bench Press cues cover planted feet, a controlled lower to the chest, and pressing back up. Squat cues cover a stable bar position, hips moving back and down with the chest lifted, and pressing through the feet to stand. Romanian Deadlift cues cover soft knees, a hip hinge with the bar close to the legs, and standing by extending the hips. The pose sequence and wording are reviewed against the exercise-technique sources below; the drawings remain intentionally simple rather than claiming to represent every body type or lifting variation.

Clips loop only while the guide is open. Opening a guide does not pause music or change the workout timer. When Reduce Motion is enabled, the guide starts paused on a representative frame and waits for an explicit play action. Text cues remain usable if video playback fails.

## Components and data flow

- Add a small `ExerciseGuide` catalog with stable guide keys, resource names, captions, and accessibility descriptions. The three keys are attached to their built-in `ExerciseDefinition` records during an idempotent seed-version upgrade; optional keys mean custom and other built-in exercises remain unaffected.
- Exercise Detail presents **Watch Form Guide** when a guide exists. Active Workout resolves the current exercise's definition by its stable `exerciseID` when the button is tapped, then presents the same sheet. Completed session snapshots are not changed.
- A focused `ExerciseGuidePlayerView` uses `AVKit` for bundled MP4 playback and releases its player when dismissed. It reports missing or unreadable resources while preserving the text cues.
- Keep the vector animation source and a repeatable export script in the repository. Bundle only the compact final clips in `GymFlow/Resources`, so releases do not depend on a video service or runtime network access.

## Verification and rollout

- Check that the seed upgrade attaches each guide to the intended existing definition without duplicating exercises or changing custom entries. A built-in renamed after the upgrade retains its guide. An already-renamed legacy definition cannot safely be identified by its former name, so it is left without an automatic guide; legacy nil-ID workout records also do not acquire a guessed guide.
- Validate each bundled clip exists, has a video track and no audio track, and has the expected short duration. Inspect the rendered poses and captions at normal and large text sizes before shipping.
- Run semantic lint, a simulator build, relevant unit and UI tests, and a hands-on iPhone pass that checks playback during music and an active rest timer. Record commands and outcomes in `PROGRESS.md` and update `PLANS.md`, `PROJECT_SPEC.md`, and `README.md` after the milestone.

## Sources for movement and cues

- [ACE Chest Press](https://www.acefitness.org/resources/everyone/exercise-library/5/chest-press/)
- [ACE Back Squat](https://www.acefitness.org/resources/everyone/exercise-library/11/back-squat/)
- [NSCA Romanian Deadlift](https://www.nsca.com/education/articles/kinetic-select/romanian-deadlift-rdl/)
