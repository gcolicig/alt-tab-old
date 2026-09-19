# High CPU Troubleshooting

Use this guide when AltTab uses about 20-50 % of one CPU core with the switcher closed. In Activity Monitor, 100 % is one fully loaded CPU core. A high load with the switcher closed is not normal.

The most likely cause is the background capture of thumbnails and full-size previews. This capture is on by default. A missing Screen Recording permission is the second idle-load path.

The code references in this guide point to the fork build `v10.12.0-193-gab5470f4`. Check every result against the build that you run.

## Preparation

- Open Activity Monitor.
- Select `View > All Processes`.
- Watch four processes together: `AltTab`, `replayd`, `WindowServer`, and the suspect app.
- Remember the rule: 100 % is one fully loaded CPU core.

## Step 0 — Check the permission (this selects the path)

- Open System Settings > Privacy & Security > Screen Recording.
- Check that AltTab is on.
- Expected result: AltTab is on.
- Meaning if granted: The capture path is the main suspect. Go to Step 1.
- Meaning if missing: AltTab makes no screenshots. The idle load then comes from the 5-second permission timer. Grant the permission and measure again.

Reference: Without the permission, the thumbnail capture stops at once (`Windows.swift`, guard `ScreenRecordingPermission.status == .granted`). The timer runs every 5 seconds (`SystemPermissions.swift`).

## Step 1 — Measure the idle state

- Do not open AltTab.
- Do not move the mouse or the windows for two minutes.
- Expected result: AltTab at about 0-2 %, with short peaks only.
- Meaning: A load that stays high is a real background problem. Go to Step 2.

## Step 2 — Isolate the background capture (the key test)

- Turn off `Keep window previews up to date in the background`.
- Restart AltTab.
- Watch `AltTab`, `replayd`, and `WindowServer` for ten minutes.
- Expected result: The idle load falls to about 0-2 %. A short peak occurs when you open the switcher.
- Meaning if it falls: The capture pipeline is the cause. Go to Step 3.
- Meaning if it does not fall: The cause is not capture. Go to Step 5.

Reference: This setting is on by default (`"captureWindowsInBackground": "true"` in `Preferences.swift`).

## Step 3 — Narrow the capture cost driver

Run the tests one at a time. Measure after each test.

- Turn off `Preview selected window` (stored key: `previewFocusedWindow`).
- Expected result: A clear drop when you open and navigate.
- Meaning: The native window resolution of the preview is the driver (`WindowCaptureEvents.swift`).

- Change Appearance from `Thumbnails` to `App Icons`.
- Expected result: The capture load goes away for the most part.
- Meaning: The problem is the screenshots, not the window detection (guard `!onlyShowApplications()` in `Windows.swift`).

## Step 4 — Check the environment factors

Run the tests one at a time.

- Close video, browser, and Electron windows one by one.
- Disconnect the external display and a DisplayLink dock.
- Move all windows to one Space and remove the unused Spaces.
- Expected result: The load falls after one specific candidate.
- Meaning: The last removed candidate is the trigger. The cause is an event storm or the capture scaling.

## Step 5 — Check the non-capture causes

Use this step when Step 2 changed nothing.

- Quit other window managers one by one: Rectangle, yabai, AeroSpace, Magnet, BetterTouchTool, Hammerspoon.
- Open the AltTab+ menu `Debug > Debug Tools…` and watch the log window. `Debug > Copy Debug Info` copies a report with the active input modules.
- Expected result: The load returns to normal, or an event flood becomes visible.
- Meaning: A flood of `AXTitleChanged`, `AXWindowMoved`, or `AXWindowResized` is an accessibility event storm or a conflict.

Additional command in Terminal:

```sh
log stream --style compact --level info \
  --predicate 'process == "AltTab" OR process == "replayd" OR process == "WindowServer"'
```

- Do exactly one change during the stream, for example pause a video.
- Meaning: Repeated capture errors, or identical window events in fast sequence, show a bug.

## Step 6 — Confirm the mapping with process samples

- Select AltTab in Activity Monitor.
- Run `Sample Process` three times, 30 seconds apart.
- Expected result: Repeated entries in all three samples.
- Meaning: `SCScreenshotManager` or `CGSHWCaptureWindowList` is capture. `AXUIElement` is an event storm. One sample is not enough.

## Step 7 — Graded remediation

1. Quit AltTab and start it again.
   - Meaning on success: a stuck capture job.
2. Restart the Mac.
   - Meaning on success: a system state in `replayd` or `WindowServer`.
3. Update AltTab to the current version.
   - Meaning on success: a fixed version regression. On macOS 15, do not go back to an old v8 version.
4. Keep the settings from Step 2 and Step 3 turned off.
   - Meaning: an isolated function path as a workaround.
5. Export the settings, then run `Reset settings and restart`.
   - Meaning on success: a migrated or inconsistent setting.
6. Reinstall AltTab.
   - Note: This removes neither the preferences nor the permissions. It does not replace Step 5.
7. File a bug report.
   - Attach: the macOS version with build, the AltTab version and source, the chip, the display resolutions and scale, `Displays have separate Spaces`, the number of windows and Spaces, other window managers, the state of the three preview settings, the CPU values of the four processes, and three samples.
   - Name a minimal trigger, for example "the load goes away with the background capture off".

## Settings reference

| UI label | Stored key | Effect on load |
|---|---|---|
| Keep window previews up to date in the background | `captureWindowsInBackground` | Allows capture while the switcher is hidden. Main idle-load driver. |
| Preview selected window | `previewFocusedWindow` | Captures the selected window at native resolution. High cost on 4K/5K. |
| Appearance: Thumbnails vs App Icons | `appearanceStyle` | `App Icons` stops the screenshot capture. |
| Fade out animation of Switcher | `fadeOutAnimation` | Visible-UI cost only. No idle load. |
| Fade in animation of Preview | `previewFadeInAnimation` | Visible-UI cost only. No idle load. |

## Version note

- The local build is the fork `v10.12.0-193-gab5470f4`.
- Only upstream issue #5190 is documented in the code (`Windows.swift`).
- Unverified: upstream v11.6.1 and the issues #5188, #5861, #733.
