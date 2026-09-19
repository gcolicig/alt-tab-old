# Settings Window Checklist (Story 16)

Run on the supported Mac after installing a build of `feat/settings-shortcut-overview` or later. Seen on
2026-09-16: steps 1–3, 5, 7, 8, 10 and 11. Not yet run: 4, 6, 9 and 12–14.

## Pages and sidebar (stage 1)

| # | Action | Expectation |
|---|---|---|
| 1 | Open Settings | Only `General` is shown; the sidebar has the headings AltTab+, Switcher, Windows, Triggers, Devices, Actions; no buttons at the bottom of the sidebar |
| 2 | Click each sidebar entry | That section alone is shown, scrolled to the top; the window keeps its width |
| 3 | Pick `Window Layouts`, search for `record`, clear the search with the x button | Matching sections are stacked with highlights; after clearing, `Window Layouts` is shown again |
| 4 | Search for text that matches nothing | The sidebar is empty; clearing restores it |
| 5 | Look at any empty shortcut recorder | It reads `Record`, not truncated |
| 6 | `General > Settings file`: Export, Import, Apply, Reset | Each opens its dialog; Reset asks before it restarts |

## Lists (stage 2)

| # | Action | Expectation |
|---|---|---|
| 7 | `Apps & URLs` with nothing configured | Two empty states with `Add App…` and `Add Link…` |
| 8 | `Profiles` with nothing configured, then `New`, then `Delete…` → `Delete` | Empty state; the new profile shows its details; after deleting, the empty state returns |
| 9 | Add two apps and one link, assign a shortcut to each, remove the first app | The other entries keep their shortcuts; a Leader binding to the second app still opens it |
| 10 | Add apps to a profile with `Choose…`, remove one | The list shows app names; unknown ids are marked `Not installed on this Mac.` |

## Shortcut overview (stage 3)

| # | Action | Expectation |
|---|---|---|
| 11 | `Shortcuts`, then `Show` on `Left third` | `Window Layouts` opens and `Left third` flashes |
| 12 | Assign the same shortcut to two menu actions | The recorder warns and offers to unassign the other one. If a duplicate arrives through a settings import, the rows show `Also used by …` and `Conflicts (n)` counts them |
| 13 | Assign `⌃1` to `Space 1` | The row notes that it replaces a macOS shortcut; removing it gives the macOS shortcut back |
| 14 | Filter `Assigned`, then `Conflicts` | Only assigned rows, then only conflict rows or `No conflicts.` |
