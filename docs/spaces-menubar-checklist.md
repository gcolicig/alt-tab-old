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
