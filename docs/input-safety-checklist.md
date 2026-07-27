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

- On 2026-07-27, recording a Space shortcut only became possible after toggling Hyperkey off and on in Settings. The cause and exact scope are unverified; no corrective app change was made.
