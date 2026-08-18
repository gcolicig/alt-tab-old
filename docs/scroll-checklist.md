# Scroll Checklist (Reverse and Speed)

Separate scroll direction and speed for mouse and trackpad run through the `scrollWheel` tap that already
exists for the switcher. Run on the supported Mac and record the macOS build.

## What automated tests cover

- `ScrollTransformTests`: category selection (continuous → trackpad, discrete → mouse), the vertical factor
  (reverse flips the sign, speed scales), horizontal scaling only, and the neutral default as a no-op.

The tap wiring — reading and writing the event fields, and enabling the tap only when needed — needs a Mac.

## Before starting

- Emergency shortcut: `Command+Control+Option+Shift+Escape` disables input modules and turns on safe mode.
- Settings live in `Pointer & Scroll`.

## Manual steps

1. **No tap when idle.** With every scroll setting at its default (no reverse, 1×), scrolling behaves exactly
   as macOS does. The tap should not be running for scrolling.
2. **Reverse mouse only.** Turn on `Reverse Mouse vertical scrolling`. A classic wheel mouse scrolls the
   opposite way; the trackpad is unchanged. Horizontal scrolling keeps its direction.
3. **Reverse trackpad only.** Turn on the trackpad reverse instead: the trackpad flips, the mouse does not.
   This is the separation macOS itself cannot do.
4. **Speed.** Set mouse speed to 2×: each wheel notch scrolls about twice as far. Try 0.5× and 3×. Repeat for
   the trackpad independently.
5. **Switcher is unaffected.** Open the switcher and scroll: continuous (trackpad) scrolling does not scroll
   the app underneath, discrete (mouse) scrolling still moves the selection — same as before this feature,
   regardless of the reverse/speed settings.
6. **Momentum and phase.** With trackpad reverse on, a flick with momentum scrolls the opposite way smoothly,
   with no jump between the active and momentum phases.
7. **Safe mode.** Fire the emergency shortcut: scroll modification stops (direction and speed return to
   system behaviour); turning a setting off and on, or leaving safe mode, restores it.
8. **Energy.** With a setting active and the system idle, confirm the tap does not raise idle CPU or wakeups
   against the unchanged fork baseline.

## What a failure looks like

Trackpad scrolling blocked outside the switcher, a reverse or speed that leaks across mouse/trackpad, a
momentum flick that jumps, or the tap staying active with every setting at default.
