# Leader and FlickRing Checklist

Phase 4 adds two triggers on top of the shared action registry: Leader (keyboard sequences) and FlickRing (a
mouse-button ring). Both run actions only from the registry, and both must leave nothing armed when disabled.

## What automated tests cover

- `LeaderSequenceTests`: the trie, session state machine, timeout, Escape, building a trie from flat
  bindings (empty/duplicate/prefix conflicts), the overlay's `level(after:)`, and the editor's text parsing.
- `FlickRingTests`: the four sectors, the 5pt dead zone, and the +y-is-up contract.

The wiring around them needs a Mac: the keyboard tap, the mouse tap, the overlays, and the settings editors.

## Leader — manual steps

Run every step and record the macOS build.

1. **Arm and run.** In `Leader`, enable the module, set a trigger key, and bind sequence `wl` to a window
   layout and `s` to a Space action. Press the trigger: the overlay appears listing `w` and `s`. Press `w`:
   the overlay narrows to `l`. Press `l`: the layout runs and the overlay closes.
2. **Trigger is absorbed.** With Leader on, pressing the trigger in a text field types nothing; the following
   sequence keys type nothing either. Pressing the trigger with the module off types normally.
3. **Escape and wrong key.** Arm a session, press `Escape`: it closes with no action. Arm again, press a key
   that no sequence expects: it closes with no action rather than swallowing further keys.
4. **Timeout.** Arm a session and wait two seconds without pressing a key: the overlay closes on its own, and
   the next keystroke reaches the app in front.
5. **Invalid bindings.** In the editor, give two rows `w` and `wl`: the warning names a prefix conflict, and
   the module does not act on either until it is resolved. A row with keys but no action, or text with a
   non-letter, shows the matching warning.
6. **Sleep/wake and safe mode.** Arm a session, let the display sleep, wake it: no session is left armed. Fire
   the emergency shortcut (`Command+Control+Option+Shift+Escape`): Leader is disabled with the other modules.

## FlickRing — manual steps

1. **Ring and directions.** In `FlickRing`, enable the module, keep the side button, and bind the four
   directions to four actions. Hold the side button: the ring appears under the cursor with four sectors.
   Drag toward one: it lights up. Release: that action runs.
2. **Dead zone.** Hold and release the button without moving past the hub: nothing runs, and the hub makes
   that visible rather than feeling like a swallowed click.
3. **Button is reserved.** With the ring on its button, a plain press-and-release of that button in a browser
   does not reach the page (no middle-click paste / no back navigation on the chosen button). With the module
   off, the button behaves normally — no tap exists.
4. **Release outside.** Drag far past a sector and release off any sector edge: it closes with no action.
5. **Button choice.** Switch the button to another one and confirm the ring now opens on that button and the
   previous button is free again.
6. **Safe mode.** Fire the emergency shortcut while the ring is open: it closes, the button is released, and
   the module is disabled.

## What a failure looks like

A key or button that reaches the app while a module should have absorbed it, an overlay that stays up after a
run/abort/timeout, or a button that stays captured after the module is turned off. Turn on debug logging and
look for the module's disable path and the circuit-breaker trip line.
