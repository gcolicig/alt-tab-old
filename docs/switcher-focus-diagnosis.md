# Switcher focus diagnosis

## Status, 2026-09-25

The intermittent switcher defect is treated as fixed, but remains under observation. Its reports were:

- the selected original window did not appear after leaving the switcher;
- Tab and Shift-Tab could select a tile, but another window appeared;
- cycling could appear on another display;
- returning from Finder to ChatGPT could fail;
- after selecting the second entry, the former window could unexpectedly appear above the active window.

The failure was not reproduced by the available runtime traces. The recorded focus operations all activated the
requested application and completed their WindowServer and Accessibility focus requests successfully.

## Implemented stabilisation

`Windows.setInitialSelectedAndHoveredWindowIndex()` now records the focused source window as the baseline for
the new switcher session. The first refresh therefore no longer compares against the previous session and
reinitialises the same selection a second time.

After an explicit navigation, the selection is pinned by `selectedWindowTarget` (the stable window ID):

- Tab and Shift-Tab use `Windows.cycleSelectedWindowIndex`;
- vertical keyboard navigation and mouse hover mark the selection as explicit too;
- an asynchronous window-list refresh may change the selected tile's index, but must restore the same target
  while it remains visible;
- an external focus change may rebuild only an untouched initial selection. It cannot overwrite an explicit
  user selection.

The focus path in `Window.focus()` first activates the target app, then requests the specific WindowServer
window, sends the key-window event and finally raises the Accessibility window. Fifty milliseconds later it
refreshes the target's Screen/Space facts and records the resulting foreground app and focused window.

Relevant implementation files:

- `src/logic/Windows.swift`: selection baseline, explicit-selection preservation and bounded diagnostics.
- `src/ui/App.swift`: session opening, confirmation and closing trace points.
- `src/ui/main-window/TilesView.swift`: vertical navigation marked as explicit.
- `src/logic/Window.swift`: per-step focus trace and delayed outcome capture.
- `src/logic/events/CliEvents.swift`: diagnostic CLI endpoint.

## Diagnostic ring buffer

The running app keeps the most recent 128 switcher events in memory. It stores no window titles or window
contents. Each event may contain only window IDs, bundle ID, selection index, Screen ID, Space indexes, the
first 16 visible/MRU window IDs, target PID and focus outcome.

Retrieve it while the failure state still exists:

```bash
/Applications/AltTab+.app/Contents/MacOS/AltTab+ --switcher-diagnostics
```

Do not restart AltTab+ before retrieval: the buffer is intentionally in-memory and is lost on restart. Ensure
only one AltTab+ instance is running after an installation; parallel instances compete for the same CLI message
port and can make the command reach the older process.

### Event sequence and interpretation

| Trace event | Meaning | Fault indication |
|---|---|---|
| `switcher-opened` | New switcher session | A second `initial-selection` in the same session indicates a selection reset. |
| `initial-selection` | Default target chosen | Its ID should be the expected alternate window. |
| `cycle-forward` / `cycle-backward` | Tab / Shift-Tab result | `selectedWindowId` must follow the displayed order. |
| `selection-changed` | Keyboard, vertical or mouse selection | The selected ID must persist across later refreshes. |
| `focus-confirmed` | Selected target at release | This is the window expected to appear. |
| `focus-requested` through `ax-focus-requested` | Individual focus steps | A missing step or `succeeded: false` identifies the failed API stage. |
| `focus-result` | Result after 50 ms | `frontmostPid` must equal `targetPid`; `focusedWindowId`, when present, must equal `selectedWindowId`. Screen/Space must still match the target. |

If `focus-confirmed` already names the wrong ID, diagnose selection ordering or a refresh reset. If it names the
right ID but `focus-result` has another foreground PID, diagnose activation. If the app is foreground but the
focused window ID differs, diagnose exact-window focusing. If IDs are correct but Screen/Space differ, diagnose
the Space/display transition.

## Reproduction and regression checks

Run these manually after changes to ordering, accessibility focus, Space handling or screen selection:

1. ChatGPT → Finder → ChatGPT. On every reopen, the active window is first and the previous window is second.
2. From window A select the second entry B; reopen and return to A; reopen again. B is second and A never
   appears above the currently active window.
3. Repeat both directions with Tab and Shift-Tab, including rapid cycling and key repeat.
4. Repeat with windows on two displays and with different Spaces. The switcher must remain on the configured
   display and reveal the exact selected window.
5. Trigger window creation, close, move and resize while the switcher is open. A selected reachable window
   must not be replaced by another tile.
6. Repeat Finder ↔ ChatGPT after visiting a third application and with several windows from the same browser.

## Verification

On 2026-09-25, `./ai/build.sh` completed successfully: 370 unit tests passed. The locally installed app was
built with `./build.sh --install` and started as a single fresh instance. Automated tests cannot prove the
visible macOS switching behaviour; retain the manual checks above and retrieve the ring buffer immediately if
the symptom returns.
