# Input Safety Checklist

Run this checklist after changes to Hyper, event taps, global shortcuts, gestures, or window-layout dispatch.

Current user-facing Hyper and Caps Lock behavior was manually accepted on 2026-07-27. This does not replace the full recovery and release-gate checks below after relevant changes.

## Normal operation

- Keep Caps Lock mapped to `Caps Lock` in macOS.
- Enable Hyper in `Settings > Hyperkey`.
- Tap Caps Lock twice and confirm that typing works in both Caps Lock states.
- Hold Caps Lock with each configured arrow and confirm that every action runs once.
- Hold Caps Lock with an unconfigured key and confirm that its system-wide Hyper shortcut runs once.
- Release Caps Lock before the paired key-up and confirm that no later key is modified.

## Recovery

- Put the Mac to sleep while Caps Lock is held, wake it, and confirm that normal typing and Hyper both work.
- Disable Hyper while Caps Lock is held and confirm that normal typing resumes immediately.
- Quit AltTab+ while Caps Lock is held, relaunch it, and confirm that no Hyper state remains.
- Revoke Accessibility while AltTab+ is running and confirm that the existing permission flow remains bounded.

## Emergency shortcut

- Press `Command+Control+Option+Shift+Escape`.
- Confirm that Hyper and gestures are disabled, the switcher closes, and window-layout actions stop.
- Confirm that normal keyboard and mouse input remain usable.
- Re-enable Hyper deliberately and confirm that safe mode clears.

## Safe start

- Quit AltTab+.
- Run `defaults write com.gcolicig.alttab-plus inputModulesSafeMode -bool true`.
- Start AltTab+ and confirm that Hyper, gestures, and window layouts remain disabled.
- Clear the override with `defaults write com.gcolicig.alttab-plus inputModulesSafeMode -bool false`.
- To exercise crash recovery, set `hyperKeyArmingMarker` to `true` before launch and confirm that AltTab+ starts in safe mode with a visible warning.

## Circuit breaker

- Use a debug build or debugger to deliver two keyboard tap-disabled events within ten seconds.
- Confirm that the first event re-enables the keyboard tap.
- Confirm that the second event disables Hyper, enables safe mode, and shows one warning.
- Confirm that AltTab's normal keyboard switching remains available after the tap is restored.

## Known observations

- On 2026-07-27, recording a Space shortcut only became possible after toggling Hyperkey off and on in Settings. The cause is still unverified.
- On 2026-07-28 the observation recurred twice after the stale-route fix, so that fix did not remove the cause. The event tap absorbs every physical Caps Lock event while Hyper is enabled and relies on the HID monitor to report the press, so a monitor that stopped delivering leaves both Caps Lock and Hyper dead until Hyper is toggled by hand, which re-registers it. A watchdog that re-armed the monitor was tried on 2026-07-28 and removed again: its liveness check could not tell the normal HID-before-tap ordering from a silent monitor, so it re-armed on ordinary presses and reset the Hyper hold mid-press, which broke Hyper shortcut recording. Any retry needs a liveness signal that survives that ordering.
- Static analysis found one path that produces exactly this symptom: a routed key code survived a missed key-up, so every later press of that key kept carrying the Hyper modifiers until `resetHyperKeyState` ran, which is what toggling Hyperkey does. The state machine now drops such a stale route on the next fresh press. Whether this was the observed cause is unconfirmed; re-check the recorder on the target machine.

## Stale Hyper routes

- Hold Caps Lock, press and hold a letter, focus a password field, and release the letter there.
- Return to a normal text field and type the same letter; confirm that it types normally instead of triggering a Hyper shortcut.
- Repeat with Caps Lock released before the letter and confirm that holding the letter still autorepeats its Hyper combination.
