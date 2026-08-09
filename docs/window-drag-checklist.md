# Window Drag Checklist (Move, Resize, Snapping, Menubar Drop)

Run this on the supported Apple-silicon Mac after any change to the drag path. It covers the modules that
share one mouse tap and one drag session: modifier move, modifier resize, in-drag snapping, the target
overlay and the menubar drop target.

Two of the four defects found the first time this path was operated hung the whole machine, so the escape
route comes first.

## Before starting

- Emergency shortcut: `Command+Control+Option+Shift+Escape`. It disables every input module and turns on
  safe mode.
- From a terminal: `pkill -9 -f 'MacOS/AltTab'`. Note the `-f 'MacOS/AltTab'`: a pattern containing
  `AltTab+` does not match, because `+` is a regular-expression quantifier.
- **If something hangs, say so before restarting.** A `sample <pid> 2` of the stuck process names the cause
  in seconds; a restart destroys the evidence.
- Settings: Move on `⌘⇧`, Resize on `fn`. Record which modifiers were used if they differ.

## Move

| # | Step | Expectation |
|---|---|---|
| 1 | Drag a window by its middle, not the title bar | The window follows the cursor |
| 2 | Drag fast and far, several windows in a row | No stutter, no freeze, the switcher stays responsive |
| 3 | Press the modifier and the mouse button at the same instant, repeatedly | AltTab+ always takes the drag; macOS tiling never appears |
| 4 | Release the modifier mid-drag, keep the button down | The drag continues |
| 5 | Press Escape mid-drag | The window stays where it was before the drag |
| 6 | Drag with no modifier | Ordinary behaviour, unchanged |
| 7 | Drag over the AltTab+ settings window | Nothing happens, no hang — a deliberate exception |

## Resize

| # | Step | Expectation |
|---|---|---|
| 8 | Start near each of the four corners in turn and pull | The opposite corner stays exactly put |
| 9 | Cross the middle of the window mid-drag | The growing edge does not flip |
| 10 | Shrink far past the minimum | Stops at 120x80, the anchored corner never moves |
| 11 | Resize a Terminal or another app with a character grid | The app may clamp; the deviation appears in the debug profile |
| 12 | Switch between move and resize between drags | Each drag uses the modifier it was started with |

## Snapping and overlay

| # | Step | Expectation |
|---|---|---|
| 13 | Drag to the left and right screen edge | Overlay appears immediately, window snaps to that half on release |
| 14 | Drag to the top edge, into the menubar strip | Overlay fills the visible desktop; not a fullscreen Space |
| 15 | Drag to the bottom edge | Nothing — that edge is deliberately inert because of the Dock |
| 16 | Leave an edge again before releasing | The overlay disappears and the window keeps the free position |
| 17 | Release in the middle of the screen | The window stays where it was dropped |
| 18 | With several displays: approach an edge shared with another display | Snapping needs a short dwell, crossing to the other screen does not snap |

## Menubar drop

| # | Step | Expectation |
|---|---|---|
| 19 | Drag a window onto the AltTab+ status item | The overlay shows the destination display |
| 20 | Release there | The window lands on the next display, keeping how it sat on its old one |
| 21 | Drag a window that straddles two displays onto the item | It moves away from the display it mostly covered |
| 22 | With one display only | Nothing happens, no overlay |

## Safety

| # | Step | Expectation |
|---|---|---|
| 23 | Press the emergency shortcut mid-drag | Both modifiers go to Disabled, safe mode on, the window keeps its pre-drag frame |
| 24 | Choose a modifier while safe mode is on | A visible notice says the module stays off |
| 25 | Turn safe mode off with a modifier already chosen | The tap is rebuilt at once, without a restart |
| 26 | Give move and resize the same modifier | Refused with a notice |
| 27 | `pkill -9` within five seconds of choosing a modifier | The next launch starts in safe mode — the arming marker did its job |

## After the run

- Copy the debug profile and check `Window drag AX deviations`. Entries there are apps that did not apply a
  frame as proposed; they belong in the app-class matrix, not in a bug report against the drag path.
- Record which app classes were covered: AppKit, Catalyst, Chromium, Electron, AWT/Swing, Qt, Terminal.
- A step that fails is recorded with what was on screen and what the debug profile said, not summarised.
