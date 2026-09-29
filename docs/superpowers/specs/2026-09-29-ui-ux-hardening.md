# UI/UX Modernization Hardening

The approved Onyx & Volt modernization stays native, offline-first, and
compatible with GymFlow's existing workout, history, and rest workflows. Before
merging it, correct the user-visible issues found in review:

- Plate loading should reach an exact target when the available denominations
  permit it; otherwise it should load the closest weight not above target and
  report the shortfall. Prefer fewer plates among equally close combinations.
  Show 1.25 kg accurately and never claim a bar heavier than the target is a
  valid target load.
- Strength history should show the true heaviest completed set, select and plot
  estimated 1RM with one consistent validity rule, and keep every completed-set
  capsule accessible when there are many sets or large text.
- The rest ring should start full for any configured duration, decline with
  elapsed time, remain stable through pause/restore, and account for +30-second
  extensions while preserving the existing restart duration. Restore the prior
  timer labels and accessibility-size control layout.
- Accent text and controls must remain readable in light and dark appearance.
  Neon fill/line accents can remain where contrast is sufficient. Decorative
  confetti and pulsing must respect Reduce Motion.

Tests should cover the numerical and persistence boundaries; UI tests or
simulator inspection should cover actual swatch/control/overflow layouts and
accessibility labels. No third-party dependency, schema reset, or completed
history rewrite is authorized.
