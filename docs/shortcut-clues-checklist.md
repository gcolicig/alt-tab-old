# Shortcut Clues Checklist

Run this on the supported Apple-silicon Mac. The module reads other apps' menus over the public
Accessibility API and shows them while a trigger is held. It executes nothing, so the questions are: does it
show the truth, does it stay out of the way, and does it leave nothing behind.

## Before starting

- Settings → Window Layouts → "Show the active app's shortcuts while holding": record a trigger. There is
  no default, so nothing happens until one is set.
- The encoding behind the display was measured against Finder on macOS 26.5.1 (`spec-shortcut-clues.md`).
  If a shortcut below looks wrong, compare it with the app's own menu before assuming the app is at fault.

## Correctness

| # | Step | Expectation |
|---|---|---|
| 1 | Hold the trigger in Finder | Overlay appears after a short delay, grouped by menu in menubar order |
| 2 | Compare five entries against Finder's real menus | Identical, including modifier order like `⌥⇧⌘Q` |
| 3 | Check an entry with a special key, e.g. `Empty Trash…` | Shows `⇧⌘⌫`, not modifiers with nothing after them |
| 4 | Check an entry with a punctuation key, e.g. `Settings…` | Shows `⌘,` |
| 5 | Hold the trigger in an app with deep submenus | Nested items appear under their top-level menu |
| 6 | Hold the trigger in an Electron app | Either shortcuts or an explanatory message; never a wrong list |

## Behaviour while shown

| # | Step | Expectation |
|---|---|---|
| 7 | Release the trigger | Overlay disappears, nothing left on screen |
| 8 | While it is shown, press one of the listed shortcuts | It runs in the target app; the overlay closes |
| 9 | While it is shown, type ordinary text | Every keystroke reaches the app unchanged |
| 10 | While it is shown, click somewhere | The click reaches whatever is under it; the overlay never takes focus |
| 11 | Switch apps while holding the trigger | Either the new app's shortcuts or the overlay closes — never a mix of two apps |
| 12 | Tap the trigger briefly instead of holding | No flash: the delay exists so a quick press shows nothing |

## Degradation

| # | Step | Expectation |
|---|---|---|
| 13 | Hold the trigger over a browser with a large bookmarks menu | The app stays responsive; if the scan hit its budget the overlay says so |
| 14 | Hold the trigger with the AltTab+ settings window in front | Nothing, or an explanatory message — never a hang |
| 15 | Hold the trigger in an app whose menus carry no shortcuts | An explanatory message, not an empty panel |
| 16 | Revoke accessibility permission, then hold the trigger | An explanatory message naming the reason, no retry loop |
| 17 | Turn on safe mode, then hold the trigger | Nothing happens |
| 18 | Press the emergency shortcut while the overlay is shown | The overlay disappears with everything else |
| 19 | Clear the trigger in the settings | The module is off; no panel, no observer left |

## Performance

- Step 13 is the one the reference implementation is documented as failing. If the machine stutters, note
  the app and how many entries its menu holds; the budget is 800 scanned entries and 200 per menu.
- A visible delay before the overlay is expected — the menu walk is many synchronous AX calls. A delay of
  more than roughly a second in an ordinary app is a finding worth reporting.

## After the run

- Note which apps were covered and which app class each belongs to.
- Any shortcut shown wrongly is recorded with the app, the entry, what was shown and what the menu says.
  A wrong symbol is worse than a missing one: it teaches a shortcut that does not exist.
