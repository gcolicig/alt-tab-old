# Scroll Direction Checklist (Story 6a / V-17)

Run this on the supported Apple-silicon Mac, with a mouse that has a notched wheel **and** a trackpad
attached at the same time. The setting is `Reverse the mouse wheel` in `Settings > Pointer & Scroll`.

The module rewrites events instead of writing system state, so the failure that matters is different from
the pointer module's. Nothing here can destroy a value another tool owns. What it can do is sit in the
input path of every scroll event on the machine, invert what the user did not ask to invert, or stay
behind after the safety path pulled it.

Two facts decide every step below:

- macOS marks trackpad and Magic Mouse scrolling as **continuous** (`scrollWheelEventIsContinuous`), and a
  notched wheel as **discrete**. Step 6a rewrites discrete events only.
- The tap has two independent reasons to run: absorbing continuous scrolling while a switcher gesture is
  held, and rewriting direction. With the setting off, the second reason is absent and the tap behaves
  exactly as it did before Story 6a.

## Not covered by automated tests

`ScrollWheelPolicy` decides per event and is unit-tested. Everything the tap itself does — being in the
stream, mutating a live `CGEvent`, coming back after a timeout, and the cost of all that — is only
observable at the device. That is this checklist.

## Steps

| # | Action | Expectation |
|---|---|---|
| 1 | Setting off. Scroll the wheel in Finder, Safari and Terminal | Direction unchanged in all three |
| 2 | Setting off. Hold the switcher gesture and scroll the trackpad | Underlying app does not scroll, as before |
| 3 | Turn the setting on. Scroll the wheel up and down in an AppKit app (Finder) | Content moves the opposite way, both directions, no stutter |
| 4 | Same, in a browser (Safari) | Same. This is the pixel-precise reader: it proves the fixed-point field was flipped too |
| 5 | Same, in Terminal and in a long list (Settings) | Same |
| 6 | Setting on. Scroll with the trackpad, two fingers | **Unchanged.** The trackpad still follows the system's Natural Scrolling preference |
| 7 | Setting on. Scroll with a Magic Mouse, if one is available | Unchanged; it reports continuous like a trackpad |
| 8 | Setting on. Scroll sideways with a tilt wheel, if one is available | Unchanged; only the vertical axis is in scope |
| 9 | Setting on. Hold shift and scroll the wheel where that scrolls sideways (Finder column view, a wide table) | Decide and record what you see. A shift-scroll carries its movement on the vertical axis, so it is mirrored with it. If that reads wrong, the axis-1 rule needs an exception for a held shift |
| 10 | Setting on. Turn on `Disable input extensions (safe mode)` | Wheel direction returns to normal at once, no restart |
| 11 | Still in safe mode, toggle the scroll setting off and on | A notice says the module stays off in safe mode; the direction does not change |
| 12 | Turn safe mode off | The setting still shows on, and the direction is inverted again, without a restart |
| 13 | Setting on. Trigger the input safety kill switch | Direction returns to normal, together with the other input modules |
| 14 | Setting on. Let the machine sleep and wake it | Direction still inverted; the tap survived or was re-enabled |
| 15 | Setting on. Provoke a tap timeout: hold a heavy load, or leave the machine busy while scrolling | The direction comes back on its own; a `tapDisabledByTimeout` line is in the log |
| 16 | Setting on. Quit and relaunch AltTab+ | Direction inverted from launch, without opening Settings |
| 17 | Setting on, then delete the app's preferences and relaunch | The module is off. Q-08: nothing enables it but the user |
| 18 | **Latency.** Setting on. Scroll a long list fast, watch for lag against the same list with the setting off | No perceptible difference |
| 19 | **Energy.** Setting on, machine idle for 10 minutes. Compare against the documented idle baseline | No measurable increase. An idle machine produces no scroll events, so the active tap should cost nothing |

Steps 18 and 19 are the ones ROADMAP Phase 7 gates the module on. They are the reason this module keeps a
permanently active tap while the trackpad module deliberately does not: a `scrollWheel` tap never sees
gesture or `mouseMoved` events, so the WindowServer only waits for this process while the user is actually
scrolling. That reasoning is an argument, not a measurement, until step 18 and 19 are filled in.

## Results

Not run yet.
