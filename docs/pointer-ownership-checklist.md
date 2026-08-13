# Pointer Ownership Checklist (S-03 / V-10)

Run this on the supported Apple-silicon Mac. It decides whether AltTab+ may own the global pointer scaling
values at all. Pointer speed and acceleration are system-wide state shared with System Settings and with
tools like LinearMouse, Logi Options or Mac Mouse Fix, so the failure that matters is not a wrong value but
a value AltTab+ writes back over somebody else's, or destroys on restore.

The effective values live in the HID system as `HIDMouseAcceleration` and `HIDTrackpadAcceleration`, and
that is where AltTab+ reads and writes them since the 2026-08-09 rework. `0` means acceleration off; a
positive value is the speed. **Negative values do not exist on this path**: measured 2026-08-10, the HID
system clamps every negative input to `0` and still returns `KERN_SUCCESS`. The negative convention belongs
to the old `com.apple.mouse.scaling` preference and cost the module a defect when it was carried over.

**Do not read them with `defaults read -g com.apple.mouse.scaling`.** The preference and the effective
value can diverge — writing the preference while the pointer stays untouched is exactly the failure that
forced the rework — and on a machine where System Settings never wrote the pair, the preference does not
exist at all (measured 2026-08-10: `defaults read` errors while the HID system reports a value).

Read the current values at any point with:

    swift scripts/utils/read_pointer_acceleration.swift

The script queries the HID system in its own process, so it stays independent of the app under test: the
app once judged its own success by reading back what it had just written, which always succeeds.

Note the values before you start. Every step below is per category, so run it once for Mouse and once for
Trackpad.

## Not covered by automated tests

The decision logic is unit tested in full. The path that actually touches the system is not: no test writes
a global preference. Everything in the table below is therefore a first execution of that path.

## Steps

| # | Step | Expectation |
|---|---|---|
| 1 | Note the untouched value. Settings show `Not managed by AltTab+` | State is `unmanaged` |
| 2 | Pick `Disabled`, then read the value | Value is `0`, label says `Managed by AltTab+` |
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

## Run of 2026-08-10 / 2026-08-13

macOS 26.5.1, Apple silicon, two displays, wireless mouse plus internal trackpad.

| # | Result |
|---|---|
| 1 | pass |
| 2 | **failed, then fixed** — `Disabled` asked for `-1`, which the HID system clamps to `0`, so the read-back disagreed with the write: the pointer moved and ownership was refused in the same step, and the baseline was discarded with it. Sentinel corrected to `0.0`; re-run passes with the baseline intact |
| 3 | pass — all eleven speed steps were separately measured to round-trip exactly on both categories |
| 4 | pass |
| 5 | **failed, then fixed** — no write-back (watched 12 s), and a single dropdown change relinquishes correctly. But a *continuous slider drag* relinquished on its first tick and re-acquired on the next, adopting the other owner's value as its own baseline and writing over it. The slider no longer acquires |
| 6 | pass |
| 7 | pass — the current value becomes the new baseline, not the original |
| 8 | **fails** — nothing is restored at quit, not even through the app's own *Quit AltTab+* button. The next launch restores it via `recoverAfterUncleanExit`. The exposure is therefore temporal, not permanent: whoever uninstalls AltTab+ or disables its autostart keeps the foreign value |
| 9 | pass |
| 10 | pass |
| 11 | pass for the positive half — value and ownership survive sleep and wake. **The negative half is untested**: the run that would have proved AltTab+ leaves a foreign value alone did not sleep at all (`pmset sleepnow` reported success while the power log shows no transition, a `PreventSystemSleep` assertion was held). Trigger the sleep from the Apple menu instead |
| 12 | pass, but not by AltTab+'s doing — `reapplyAfterSystemEvent` is called from the wake notification only, and nothing observes device attach or detach. It passes because the value is category-global, not per-device, so unplugging cannot reset it |
| 13 | no fight, no write-back loop. AltTab+ never writes unprompted — there is no timer, no polling, no reconciliation — so a fight is structurally impossible whatever the other tool does. **Not shown**: that AltTab+ notices a takeover *by LinearMouse* specifically. LinearMouse reaches the same value the same way (`IOServiceOpen` plus `dlsym`, and it logs *"Update/Restore pointer acceleration for device"*), but it would not apply an injected config scheme, and its menubar-only UI cannot be driven by the harness |

### Findings that are not covered by a step

- **The ownership label is stale until the next interaction.** `PointerOwnership.state` re-reads the persisted record, never the system. After System Settings took the value the row still read `Managed by AltTab+`. `refreshControlsFromPreferences` was written for exactly this case and cannot help, because the record — not the control — is what is stale.
- **`defaults delete` behind a running app does not reset it.** The app keeps the record in `CachedUserDefaults`. Reset through the UI or restart the app, otherwise the run measures against a cache.
- **AltTab+ writes no preference.** System Settings writes both `com.apple.mouse.scaling` and the HID value; AltTab+ writes only the HID value. See S-12.

Step 9 and 10 are the pair that matters most: they separate "our value is still there, so restoring is safe"
from "somebody else's value is there, so restoring would destroy it".

To simulate the unclean exit:

    pkill -9 -f '/Applications/AltTab+.app'

## What each result means

- **All steps pass**: S-03 passes. Pointer ownership may ship.
- **Any restore overwrites a foreign value**: S-03 fails. The sub-module does not ship; per the backlog no
  event-rewriting substitute is allowed.
- **The written value moves the pointer immediately** — that is what the HID path was chosen for, and the
  read-back in step 2 confirms it. What this checklist does **not** decide is whether the value survives a
  logout; that is tracked separately as S-12 and needs its own before/after measurement around a logout.

## Decision

Record the outcome under `S-03` in `Spikes mit Exit-Kriterien` and under `V-10` in `Verifikationspunkte` in
`backlog.md`. Re-run after every supported macOS major update.
