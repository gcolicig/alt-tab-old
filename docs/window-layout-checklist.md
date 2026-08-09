# Window Layout Checklist

Run this checklist on macOS Tahoe after changes to focused-window selection, layout geometry, restore, or global shortcut dispatch.

The current user-facing Window Layout behavior was manually accepted on 2026-07-27. Repeat the full matrix below after relevant changes and before a public release.

## Setup

- Keep every AltTab+ layout shortcut unassigned, then confirm that no layout action runs.
- Assign temporary conflict-free shortcuts to each layout action.
- Open one resizable window on the primary display and one on a secondary display when available.

## Geometry

- Run left/right third and left/right two-thirds; confirm exact visible-screen edges with no gap outside the target frame.
- Run left/right three-quarters; confirm the remaining quarter stays visible.
- Run left/center/right focus; confirm the active window is dominant while adjacent window area remains visible.
- Repeat on displays with different scale factors, menu-bar placement, Dock placement, and portrait orientation when available.

## Target And Restore

- Focus a window, invoke one layout, and confirm only that focused window changes.
- Invoke Restore and confirm the window returns to its frame before the first layout action.
- Change the frame externally after a layout and confirm Restore does not mutate another window.
- Try a non-resizable window, sheet, popover, minimized window, and fullscreen window; confirm refusal or bounded degradation without moving an unrelated window.

## Display Moves

- With a second display connected, run `Move to next display` repeatedly and confirm the window cycles through the displays in their physical order, left to right.
- Confirm the window keeps its relative position and size, and that a window larger than the target display is bounded by it instead of hanging over the edge.
- Invoke `Restore` after a display move and confirm it returns to the frame before the last layout action, not to the other display.
- Disconnect the second display and confirm the action reports that only one display is connected instead of doing nothing silently.

## Presets

- Assign a preset and confirm every listed shortcut is set and works.
- Assign a preset while one of its shortcuts is already taken by your own assignment, and confirm yours survives and the notice names how many were skipped.
- For a preset using `Control`: confirm the matching macOS shortcut stops working while assigned, and works again after removing the preset.
- Quit AltTab+ while a `Control` preset is assigned, confirm the macOS shortcut stays disabled, then remove the preset and confirm it returns.
- Kill AltTab+ instead of quitting it, remove the shortcut in the recorder before the next launch, and confirm the macOS shortcut is restored at that launch.

## App Matrix

- Repeat one layout and Restore in an AppKit app, a Catalyst app, Chromium or Electron, Java, Qt, and Terminal when installed.
- Record each app as `full`, `partial`, or `none`, rather than pass or fail: apps with their own keymap or window handling honour part of what they are told. Electron apps, JetBrains IDEs, and terminal emulators are the ones that have to be in the table.
- A `partial` or `none` result is a requirement, not a defect report: the action has to degrade visibly instead of half-applying.
- Record missing classes instead of substituting an unverified result.
- Confirm failure in one app does not block later layout actions in another app.

## Safety

- Revoke Accessibility and invoke a layout; confirm the permission flow remains bounded.
- Trigger the emergency shortcut and confirm layout actions remain blocked until an input extension is deliberately re-enabled.
- Remove the temporary shortcuts and confirm no defaults are recreated.
