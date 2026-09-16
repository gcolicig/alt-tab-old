# Scroll Checklist (Reverse and Speed, V-17)

Run this on the supported Apple-silicon Mac, with a mouse that has a notched wheel **and** a trackpad
attached at the same time, and record the macOS build. The settings live in `Settings > Pointer & Scroll`:
`Reverse Mouse/Trackpad vertical scrolling` and `Mouse/Trackpad scroll speed`.

The module rewrites events instead of writing system state, so the failure that matters is different from
the pointer module's. Nothing here can destroy a value another tool owns. What it can do is sit in the
input path of every scroll event on the machine, change what the user did not ask to change, or stay
behind after the safety path pulled it.

Two facts decide every step below:

- macOS marks trackpad and Magic Mouse scrolling as **continuous** (`scrollWheelEventIsContinuous`), and a
  notched wheel as **discrete**. That is the only device distinction available without enumerating
  devices, and it is what routes an event to the mouse or the trackpad settings.
- The tap has two independent reasons to run: absorbing continuous scrolling while a switcher gesture is
  held, and applying a scroll setting that changes something. With every setting at its default, the
  second reason is absent and the tap behaves exactly as it did before Story 6.

## Not covered by automated tests

`ScrollTransformTests` cover the pure part: category selection (continuous → trackpad, discrete → mouse),
the vertical factor (reverse flips the sign, speed scales), horizontal scaling only, and the neutral default
as a no-op. Everything the tap itself does — being in the stream, mutating a live `CGEvent`, coming back
after a timeout, and the cost of all that — is only observable at the device. That is this checklist.

## Before starting

- Emergency shortcut: `Command+Control+Option+Shift+Escape` disables input modules and turns on safe mode.

## Steps

| # | Action | Expectation |
|---|---|---|
| 1 | Every setting at default (no reverse, 1×). Scroll wheel and trackpad in Finder, Safari and Terminal | Direction and distance unchanged in all three; the tap is not running for scrolling |
| 2 | Settings at default. Hold the switcher gesture and scroll the trackpad | Underlying app does not scroll, as before |
| 3 | Turn on `Reverse Mouse vertical scrolling`. Scroll the wheel up and down in an AppKit app (Finder) | Content moves the opposite way, both directions, no stutter |
| 4 | Same, in a browser (Safari) | Same. This is the pixel-precise reader: it proves the fixed-point field was flipped too |
| 5 | Same, in Terminal and in a long list (Settings) | Same |
| 6 | Mouse reverse on. Scroll with the trackpad, two fingers | **Unchanged.** The trackpad still follows the system's Natural Scrolling preference |
| 7 | Mouse reverse on. Scroll with a Magic Mouse, if one is available | Unchanged; it reports continuous like a trackpad |
| 8 | Mouse reverse on. Scroll sideways with a tilt wheel, if one is available | Unchanged; only the vertical axis is reversed |
| 9 | Mouse reverse on. Hold shift and scroll the wheel where that scrolls sideways (Finder column view, a wide table) | Decide and record what you see. A shift-scroll carries its movement on the vertical axis, so it is mirrored with it. If that reads wrong, the axis-1 rule needs an exception for a held shift |
| 10 | Mouse reverse off, trackpad reverse on | The trackpad flips, the mouse does not. This is the separation macOS itself cannot do |
| 11 | Trackpad reverse on. Flick with momentum | Scrolls the opposite way smoothly, with no jump between the active and momentum phases |
| 12 | Set mouse speed to 2×, then 0.5× and 3× | Each wheel notch scrolls about that much further or shorter; horizontal keeps its direction and scales too. Repeat for the trackpad independently |
| 13 | Any setting on. Open the switcher and scroll | Continuous scrolling does not scroll the app underneath, discrete scrolling still moves the selection, regardless of the reverse/speed settings |
| 14 | Any setting on. Turn on `Disable input extensions (safe mode)` or fire the emergency shortcut | Direction and speed return to system behaviour at once, no restart |
| 15 | Still in safe mode, toggle a scroll setting off and on | A notice says the module stays off in safe mode; scrolling does not change |
| 16 | Turn safe mode off | The settings still show on, and their effect is back, without a restart |
| 17 | Any setting on, system idle | The tap does not raise idle CPU or wakeups against the unchanged fork baseline |

## What a failure looks like

Trackpad scrolling blocked outside the switcher, a reverse or speed that leaks across mouse/trackpad, a
momentum flick that jumps, or the tap staying active with every setting at default.
