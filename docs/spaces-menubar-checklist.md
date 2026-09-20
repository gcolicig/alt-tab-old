# Spaces Menubar Checklist

Run this on the supported Apple-silicon Mac. It covers the Space row next to the AltTab+ status item: which
display groups appear, whether clicking them reaches the Space, and how the row behaves as the arrangement
changes. It is the manual half of `V-14`.

## Before starting

- Settings → General → "Show Spaces next to the menubar icon" must be on.
- Note the state of `Desktop & Dock → Mission Control → Displays have separate Spaces`. Several expectations
  below depend on it, and macOS demands a restart to change it.
- Note how many displays are attached and how many Spaces each carries.

## Grouping

| # | Step | Expectation |
|---|---|---|
| 1 | Separate Spaces **off**, several displays, one carrying more than one Space | Only that display's group appears; no divider is left over |
| 2 | Separate Spaces **off**, every display carrying exactly one Space | The row still shows them rather than going blank |
| 3 | Separate Spaces **on**, a display carrying exactly one Space | Its group stays visible: the number reports a display that switches on its own |
| 4 | Separate Spaces **on**, several displays with several Spaces | One group per display, left to right, divider between them |
| 5 | Attach or detach a display | The row follows without a restart and keeps a stable order |

## Clicking

| # | Step | Expectation |
|---|---|---|
| 6 | Click a Space number on the display the cursor is on | That Space activates |
| 7 | Separate Spaces **off**: click while the cursor is on another display | It works — one gesture switches the whole arrangement |
| 8 | Separate Spaces **on**: click a group belonging to another display | Refused and shown as unreachable; a synthetic gesture carries no target display |
| 9 | Click the Space that is already active | Nothing changes, no flicker |
| 10 | With more than nine Spaces on one display | A `…` segment holds the rest and its menu switches correctly |

## State and updates

| # | Step | Expectation |
|---|---|---|
| 11 | Switch Spaces natively with `Control+Arrow` | The highlight follows, with the delay of the system notification |
| 12 | Switch through several Spaces quickly | The row shows the Space that was arrived at, not every one passed through |
| 13 | Create a Space in Mission Control | A segment appears |
| 14 | Delete a Space | Its segment disappears and the numbering closes up |
| 15 | Enter and leave a fullscreen Space | The row stays consistent with what the system shows |
| 16 | Sleep and wake | The highlight is correct without a restart |
| 17 | Open and close Mission Control | The row is correct afterwards |

## Appearance

| # | Step | Expectation |
|---|---|---|
| 18 | Compare the segments with neighbouring system status items | Same optical band, vertically centred against them |
| 19 | Switch between light and dark mode | The active Space stays legible in both |
| 20 | VoiceOver over the segments | Each names its Space and, with several groups, its display |

## After the run

- Note the value of "Displays have separate Spaces", the display count and the Spaces per display: nearly
  every expectation above is conditional on those three.
- Read the setting with `defaults read com.apple.spaces spans-displays` (1 means displays share Spaces, so
  separate Spaces is off) rather than from a helper script: `NSScreen.screensHaveSeparateSpaces` returns a
  default value outside an app bundle and reported the opposite of the truth on 2026-08-05, which is how a
  grouping rule came to be built on a misreading.
- Steps 1 and 2 have never been observed in the state they describe. They are the ones to run first.

## Defect V-22: a segment click opens the menu instead of the preview (reported 2026-09-20)

Since #72 a left click on a Space segment must open the Spaces preview. The menu opens instead,
depending on where and when the click lands. The failure is not reliably reproducible by eye.

The click path is `Menubar.statusItemOnClick()` → `handleSegmentClick()`. The handler returns false,
and the caller then pops `Menubar.menu`, when any of these is true:

- `NSApp.currentEvent` is nil, or its type is not `.leftMouseDown`
- `spacesRowRect` is nil, which `refreshSpaces()` sets while it rebuilds the row
- `point.x` falls outside `spacesRowRect`; only the x axis is tested, never y

### Cause found on 2026-09-20, fix pending the run below

`event.locationInWindow` is intermittently pinned to the status window's left content inset for clicks
on the part of the item that was added beyond its original square. The recorded pair is `(0, 11.21)`
for a click whose live screen point converted to `(40.695, 11.21)`, which is inside the row. The x test
therefore failed and the menu opened.

The handler now converts `NSEvent.mouseLocation` through the status window instead, and the hit test
moved to `MenubarSpaceRow.hitTarget(at:spacesRect:muteRects:)`, where three unit tests hold it: the
recorded pair, the half-open horizontal range at every menu bar height, and mute icons winning over the
row. The matrix below now verifies the fix.

Run every step twice and record which of the two appeared. The row is one rendered image, so a
segment is found by position, not by hit-testing a view.

| # | Action | Expectation |
|---|---|---|
| A1 | Click the left edge, the middle and the right edge of one segment | Preview each time |
| A2 | Click the 1 pt boundary between two segments | Preview, never the menu |
| A3 | Click the divider between two display groups | Preview, never the menu |
| A4 | Click the gap between the AltTab+ icon and the first segment | Menu (the gap is not the row) |
| A5 | Click a segment at the top edge of the menu bar, then at the bottom edge | Same result as in the middle |
| A6 | Click the same segment 20 times | 20 previews; record every menu that appears |
| A7 | Click a segment immediately after a Space switch, and again during the switch animation | Preview |
| A8 | Click a segment right after plugging or unplugging a display | Preview |
| A9 | Click a segment right after muting or unmuting the microphone | Preview |
| A10 | Add and delete a Space in Mission Control, then click a segment | Preview |
| A11 | Leave the Mac idle for 10 minutes, then click a segment | Preview |
| A12 | Click with tap-to-click on a trackpad, then with a physical click | Preview both times |
| A13 | Click while Command, Option, Control or Shift is held | Defined behaviour, and the same one each time |
| A14 | Double-click a segment | No menu, no double toggle |
| A15 | Click a segment while the preview is already open | The preview closes, no menu |
| A16 | Click the mute icon and the overflow button | Their own action, never the preview |
| A17 | Repeat A1 and A6 with one display, then with two displays | Same result |
| A18 | Repeat A1 on a display carrying a single Space | Preview |

Record for each failure: the macOS build, the number of displays, the number of Spaces per display,
and what happened right before the click. Start the app with `--logs-file=<path>` to keep a log.
