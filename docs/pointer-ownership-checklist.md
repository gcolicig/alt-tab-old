# Pointer Ownership Checklist (S-03 / V-10)

Run this on the supported Apple-silicon Mac. It decides whether AltTab+ may own the global pointer scaling
values at all. Pointer speed and acceleration are system-wide state shared with System Settings and with
tools like LinearMouse, Logi Options or Mac Mouse Fix, so the failure that matters is not a wrong value but
a value AltTab+ writes back over somebody else's, or destroys on restore.

The values live in `NSGlobalDomain` as `com.apple.mouse.scaling` and `com.apple.trackpad.scaling`, verified
present on macOS 26.5.1 (build 25F80). A negative value means acceleration off; a positive one is the speed.

Read the current values at any point with:

    defaults read -g com.apple.mouse.scaling
    defaults read -g com.apple.trackpad.scaling

Note the values before you start. Every step below is per category, so run it once for Mouse and once for
Trackpad.

## Not covered by automated tests

The decision logic is unit tested in full. The path that actually touches the system is not: no test writes
a global preference. Everything in the table below is therefore a first execution of that path.

## Steps

| # | Step | Expectation |
|---|---|---|
| 1 | Note the untouched value. Settings show `Not managed by AltTab+` | State is `unmanaged` |
| 2 | Pick `Disabled`, then read the value | Value is `-1`, label says `Managed by AltTab+` |
| 3 | Pick `Custom` and move the speed slider | Value follows the notch; still `managed` |
| 4 | Pick `System default` | The value from step 1 is back, label returns to `Not managed by AltTab+` |
| 5 | Take ownership again, then change the value in System Settings > Mouse | AltTab+ does not write back. Label becomes `Changed outside AltTab+` |
| 6 | Restart AltTab+ while `relinquished` | Still `relinquished`; the value stays as System Settings left it |
| 7 | From `relinquished`, pick a mode again | Ownership resumes and the *current* value becomes the new baseline, not the one from step 1 |
| 8 | While managed, quit AltTab+ cleanly | Baseline restored |
| 9 | While managed, `kill -9` AltTab+, then start it | Baseline restored, module starts disabled, value not re-applied silently |
| 10 | While managed, `kill -9`, change the value externally, then start AltTab+ | No restore. State goes to `relinquished` |
| 11 | While managed, sleep and wake | Value re-applied only if it is still the one AltTab+ wrote |
| 12 | While managed, disconnect and reconnect the mouse | Same as step 11 |
| 13 | Run a second pointer tool (LinearMouse or similar) while managed | AltTab+ yields, no write-back loop, no fight over the value |

Step 9 and 10 are the pair that matters most: they separate "our value is still there, so restoring is safe"
from "somebody else's value is there, so restoring would destroy it".

To simulate the unclean exit:

    pkill -9 -f '/Applications/AltTab+.app'

## What each result means

- **All steps pass**: S-03 passes. Pointer ownership may ship.
- **Any restore overwrites a foreign value**: S-03 fails. The sub-module does not ship; per the backlog no
  event-rewriting substitute is allowed.
- **The written value has no effect until logout**: the value is settable and restorable, which is what the
  exit criterion asks, but record it — a setting that only takes effect after a logout needs to say so in
  the UI rather than look broken.

## Decision

Record the outcome under `S-03` in `Spikes mit Exit-Kriterien` and under `V-10` in `Verifikationspunkte` in
`backlog.md`. Re-run after every supported macOS major update.
