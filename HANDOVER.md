# Handover

## Current state, 2026-09-20

Switcher focus was stabilised and instrumented on 2026-09-25. It is treated as fixed but remains under
observation; reuse `docs/switcher-focus-diagnosis.md` for the exact diagnosis command, trace interpretation
and manual regression cases.

The latest state is the third Codex handover below. The six commits from `docs/handover-codex-session2`
were fast-forwarded into local `main` on 2026-09-20; publishing `main` remains a separate step. V-22 has a
code fix and unit coverage but still needs the A1–A18 device run. V-23 is open and registered in
`backlog.md`. `Panion` is the accepted product name; run the permission-sensitive device checks before
changing the bundle identifier. Earlier sections are chronological records and may describe branches or
findings that later sections supersede.

Written 2026-08-05, revised 2026-08-10, 2026-08-14 and 2026-09-16, for whoever picks this up next. It records what is built, what is
genuinely verified, and the traps this codebase has already sprung — so they need not be sprung twice.

The feature branch was merged to `main` on 2026-08-09 with its history intact rather than squashed, because
several commit messages carry reasoning this file only summarises.

`backlog.md` is the specification and `ROADMAP.md` the phase overview; both are current. This file adds the
part that is easy to lose: which claims rest on measurement and which do not.

## Where the work stands

| Area | Built | Operated on the target machine |
|---|---|---|
| Action registry, window layouts, Spaces | yes | yes |
| Spaces menubar row | yes | yes — checklist run 2026-08-06, three defects found and fixed |
| Pointer acceleration/speed ownership (S-03) | yes, **rebuilt 2026-08-07** | **yes — V-10 run 2026-08-13/14**, three defects found and fixed on the way |
| Cursor AX window core (3A) | yes | indirectly, through the drag |
| Modifier move, snapping, overlay (3B) | yes | yes, repeatedly |
| Resize (3C) | yes | yes |
| Menubar drop target, stage 1 | yes | yes |
| Menubar drop target, stage 2 | yes, 2026-08-07 | **no** |
| Shortcut Clues (2E) | yes | reader measured; overlay **still not operated**, two defects found by reading |
| Leader and FlickRing (Phase 4) | yes, 2026-08-18 | **no** — `docs/leader-flickring-checklist.md` |
| Profiles, window drag quarters, reverse scroll and speed | yes | **no** |
| Window focus, system actions, screen tools, Keep Awake, Debug submenu (stories 10, 12–14) | yes, 2026-09-16 | partly — menu structure, settings, mic icon, browser list seen; actions not run |
| Grouped menubar menu (story 15) | yes, 2026-09-16 | yes, by the user |
| Settings window rework (story 16) | yes; later merged through PR #71 | yes — pages, search, lists, profile add/delete, overview and `Show` |

The unit-test suite passes. Build with `./build.sh --test`; `SCHEME=Release ./build.sh` also works again.

## What happened between 2026-08-10 and 2026-08-14

- **V-10 ran, at last.** Steps 1–10 and 12 pass. Step 8 failed, was fixed by #21, and passed when run again
  on 2026-09-16. Three defects were found by operating, none by tests:
  a disabled sentinel the HID system silently clamped to 0 while reporting success (#16), a speed slider
  that could re-acquire mid-drag and adopt a foreign value as its own baseline (#18), and a quit path
  that kept the value instead of handing it back (#21). Step 11's negative half (sleep) is still open —
  the machine refuses `pmset sleepnow` under a WindowServer assertion; it needs the Apple menu or the lid.
- **S-12 is answered.** A value written through the HID system alone does not survive a reboot; System
  Settings survives because it writes the preference as well. Consequence recorded in `backlog.md`:
  re-apply at launch, do not write the preference.
- **4c measured.** Per-device pointer values (`HIDPointerAcceleration` in a device's
  `HIDEventServiceProperties`) are addressable and independent of the category values. Open before any
  write path: a trustworthy read path — `hidutil --get` returns null while `ioreg` shows the value.
- **Upstream: no merge, port instead.** A probe merge against `lwouis/alt-tab-macos` measured 85
  conflicting files with 22 modify/delete conflicts in this fork's most-invested files; the cause is
  upstream's 1868-file "alt-tab pro" restructuring. Decision and numbers in `backlog.md` under
  `Upstream-Abgleich`. Three upstream fixes were ported individually and verified (#25): hover no longer
  scrolls the list, the synthetic makeKey click can no longer resize a window (down-only, far-away
  point), and the gesture tap was split so an active tap only exists while it may absorb — the cursor no
  longer waits on our callback. Note from that work: **CGEvent tap creation order decides run order**
  (created second runs first), not the order sources are added to the run loop.
- **Settings reshaped.** Sections renamed (`Appearance` → `Cmd-Tab`, `Controls` → `Cmd-Tab Controls`, ids
  untouched) and the sidebar reordered from system-wide to per-app (#22, #24). Creator's Settings now arm
  Hyperkey — a deliberate, user-decided exception to Q-08, carried by amending the rule, not bypassing it.
- **Drag modifiers extended** (#26): picker order is now disabled, ⌘⌃, ⌘⌥, fn, ⌘⇧, ⌥⇧, with a one-shot
  index migration because the preference stores an index into that list.

## What happened on 2026-09-16

- **Two machines, one history.** The histories were merged (`merge/reunify`); reverse scrolling, built on
  both, now has one implementation (`ScrollTransform`), with a one-time migration of `scrollReverseMouse`.
- **Supercharge comparison.** Every Supercharge menu entry was classified in `backlog.md`
  (`Supercharge-Abgleich`). Stories 10 (Keep Awake MVP), 12 (window focus), 13 (Debug submenu), 14 (system
  actions and tools) and 15 (grouped menu) were built and merged as PR #56. Start device testing with
  `docs/system-actions-checklist.md`, then V-19 to V-21.
- **Found by running the app, not by tests** (again): a duplicate bundle id from Edge's updater copies
  crashed the action registry's precondition on the first menu click; a settings switch read a
  preference with no registered default and crashed the settings window; the Keep Awake entry was hidden
  by default; the new action shortcuts were registered as local ones and only fired with the switcher
  open (PR #57, not yet merged when this was written).
- **CI is Xcode 16.4, local is Xcode 27.** Three traps: `resources/l10n/Localizable.strings` must be
  regenerated with `scripts/l10n/extract_l10n_strings.sh` whenever a string changes; APIs from the
  macOS 26 SDK need `#if compiler(>=6.2)` on top of `#available`; and the 250 ms type-check limit is hit far
  earlier on the old compiler — long `+` chains of arrays and untyped array literals in tests failed there
  while passing locally. Build such lists step by step and annotate literals.
- **Settings window rework (story 16)** sits on three stacked branches above PR #57:
  `feat/settings-pages` → `feat/settings-lists` → `feat/settings-shortcut-overview`. Merge them in that
  order; after a squash merge, move the next one with `git rebase --onto`. The app, link and profile
  slots stay the storage on purpose, because shortcuts, Leader and FlickRing bindings refer to slot
  numbers.
- **A settings layout trap:** a wrapping `NSTextField` without `preferredMaxLayoutWidth` asks for its
  one-line width. One long section description widened the fixed-width settings window to 1141 pt, and
  the frame autosave kept it.
- Settings sidebar now: General and Shortcuts; Cmd-Tab, Cmd-Tab Controls, Exceptions; Window Layouts,
  Spaces, Profiles; Hyperkey, Leader, FlickRing; Pointer & Scroll; System Actions, Keep Awake, Apps & URLs.

## The most important thing to understand

**The unit tests have never found a real defect in this project.** Every one of the roughly ten defects
found so far came from operating the app or measuring the system. The tests are worth keeping — they caught
several regressions while refactoring — but they are not evidence that a module works.

**Reading the code does find them, and cheaply.** The 2026-08-07 session found five that way, before
anything was operated: a stale cursor group that left menubar segments dead to the click, a refresh trigger
too narrow to notice a Space being created, a pointer write path that could not fail because it checked
itself against its own write, a menu scan shown against the wrong session, and a declared layout width the
panel never applied. Prefer it for any path the table above marks as not operated — that is where the
never-executed code is.

The defects they did not catch, by cause:

- **Coordinate spaces.** Three separate times: an edge model written in AppKit coordinates while events
  arrive in Quartz, so top and bottom were swapped; the screen looked up by its visible frame, which starts
  below the menubar, so the fill zone was dead exactly where it lives; and neighbour detection that only
  ever checked left and right, so vertically stacked displays reported no neighbour at all.
- **Blocking AX calls.** Two hangs of the whole machine. One from asking AX for the window id on every
  frame of a 60 Hz drag, which queued behind a global lock inside HIServices. One from querying our own
  process, which deadlocks because the answer must come from the thread already waiting for it.
- **Assumptions about system encodings.** `AXMenuItemCmdModifiers` does encode Command inverted, but on
  bit 8, not bit 1 as assumed. The guess would have mislabelled nearly every shortcut in the system.
- **Code that claims a capability it does not deliver.** Escape had a state transition and a test but
  nothing ever sent the event. A wake re-apply existed and was never called. A diagnostic ring was filled
  and never read. A cache was never cleared.

## Traps that have already cost hours

- **`pkill -f 'AltTab+'` matches nothing.** The `+` is a regex quantifier. Use `pkill -9 -f 'MacOS/AltTab'`.
- **`NSScreen.screensHaveSeparateSpaces` lies outside an app bundle.** A helper script reported `false`
  while the app and `defaults read com.apple.spaces spans-displays` said the setting was on. A display rule
  and a backlog entry were built on that misreading before it was caught. Measure system state inside the
  app, or read the underlying preference.
- **Launching the binary from a terminal breaks TCC.** The accessibility grant is then credited to the
  terminal and the app reports no permission. Use `open -a`, and for logs pass
  `--logs=debug --logs-file=<path>` — a LaunchServices-launched app has no usable stdout.
- **`kill -9` within five seconds of arming an input module leaves the arming marker behind**, and the next
  launch starts in safe mode. That is the marker working, but it looks like a bug and it silently disables
  the module.
- **`tr` is shadowed on this machine** by an unrelated binary. Use Python for text processing in scripts.
- **A private symbol that resolves says nothing about whether it works.** Measured 2026-08-07: writes to the
  WindowServer's Space model are accepted and ignored from an ordinary app connection. Setting the active
  menubar display returns success and changes nothing; setting a display's current Space moves the reported
  value while the screen keeps showing the old one; moving a window between Spaces does nothing at all. Only
  `CGSMoveWorkspaceWindowList` says so out loud, with `kCGErrorNotImplemented`, because it is the one that
  returns a status. Reads all work. Assume any write there is refused until measured otherwise.
- **Verifying a value is readable does not verify it is writable.** The pointer module was built on
  `NSGlobalDomain` because the scaling values could be *read* there. Writing them changes nothing; the HID
  system is the real path. The module could not notice, because it checked its own success by reading back
  the preference it had just written.
- **Judge a visual change against content that differs.** A spike was declared successful from a screenshot
  of an empty desktop, which looks identical whether or not the Space switched. Use a screen with
  distinguishable windows in both states, or the measurement proves nothing.
- **A menu bar manager sits between you and the status item.** `Ice` runs on the target machine. It blocks
  automated clicks on the menubar entirely, and it is a plausible confounder for any "the first click does
  nothing" report — rule it in or out before blaming this app.
- **`build.sh --install` needs the app bundle writable, not `/Applications`.** On a managed machine the user
  is not in `admin` and `sudo` is denied outright; the check was corrected on 2026-08-07 so a plain copy into
  the existing bundle is used when it is possible.
- **The shell has no accessibility permission; the app does.** Questions about what another app's menu bar
  reports cannot be answered from a script. The debug window now carries a button that dumps the frontmost
  app's menu shortcut encodings for exactly this.

## How to diagnose a hang

This has worked twice, in minutes, where reasoning would have taken hours:

```bash
sample <pid> 2 -f /tmp/hang.txt
```

Then read the main thread's stack. Both hangs were immediately obvious from it. **Take the sample before
restarting anything** — a restart destroys the evidence, and the failure has not been reproducible on
demand.

## What needs the target machine next

In rough priority. Everything here needs a human at the keyboard; none of it can be reached from a script.

1. **V-10 step 11, negative half**: sleep must be triggered from the Apple menu or the lid —
   `pmset sleepnow` is refused on this machine. Everything else in the checklist has run.
2. **V-16**, attributing the two-click Dock activation recorded in `backlog.md` under 2A-1. The deciding
   test is one line: quit the app (`pkill -9 -f 'MacOS/AltTab'`) and repeat the click.
3. **Shortcut Clues** (`docs/shortcut-clues-checklist.md`). The overlay has still never been shown. The
   trigger has no default and must be recorded first, or nothing happens at all.
4. **The drag checklist** (`docs/window-drag-checklist.md`), app-class matrix. Needs two displays.
5. **Stage 2 of the menubar drop**: dropping on a display's group should move the window to that display.
   Built 2026-08-07, never operated. Needs two displays and an assigned drag modifier — the module is off by
   default.
6. **S-08 remainder**: toggling `Displays have separate Spaces` was never operated with two displays.
7. **S-01/S-02** and the app-class matrix for the AX core.

## Known open behaviour, not defects

- Dragging a window across a display boundary still flickers and sometimes changes size. Unattributed: it
  may be macOS adjusting the window for the target display, or our writes racing the app. The debug profile
  under `Window drag AX deviations` distinguishes the two — entries there mean the app or system changed
  the frame, no entries mean it is us.
- A window filled through the drag keeps that size when dragged away; there is no memory of the previous
  frame. Specified in `backlog.md` under "Vorherige Groesse merken", not built.
- The AltTab+ settings window cannot be moved by the modifier. Deliberate: querying our own AX tree
  deadlocks.
- Gemini clamps the y coordinate at the display edge while x follows. App behaviour, documented for the
  matrix.
- Claude briefly exposed a second, untitled, off-screen window that passed every window check. Not
  reproducible; neither visibility nor Space membership separates it from a legitimately minimized window.
- **Corrected 2026-09-16 (S-10d in `backlog.md`):** a synthetic swipe whose `event.location` lies on
  another display switches *that* display, with the cursor left where it is. Measured with a control run
  on macOS 26.7: without a location the display under the cursor switched, with the location the target
  switched, both independent of the active menubar display. The paragraph below is the state of
  2026-08-07 and is wrong about the event route. Remote switching is therefore reachable but not built.
- (State of 2026-08-07.) Switching the Space of a display the cursor is not on is not possible. Four routes were measured on
  2026-08-07 and all failed: the gesture carries no target display, a cursor warp does not move the active
  menubar display, the setter meant for it is accepted and ignored, and moving the Space layers changes the
  reported value without changing the picture. The menubar row therefore refuses such a click and says so
  rather than doing nothing. See S-10, S-10b and S-10c in `backlog.md`. The `event.location` route,
  which this section used to call unmeasured, was in fact measured on 2026-08-06: setting the location to
  the centre of the target display had no effect, and a control run without it behaved identically
  (`backlog.md`, S-10). The branch `spike/spaces-remote-gesture` (2026-08-14) repeated that
  measurement on 2026-09-16 with a control run and found the opposite; see the correction above. The
  branch is deleted.
- Dropping a window on a switcher tile to send it to that tile's Space (story 2H) has no system path. Every
  known call for moving a window between Spaces is either a stub or silently refused. The story is
  specified and resting.

## Working agreements that produced the good results

- Measure before building on an assumption. The spec for Shortcut Clues demanded it explicitly, and the
  assumption was wrong twice in that one module.
- When a hypothesis is disproved, say so plainly and record the disproof — the retracted
  `screensHaveSeparateSpaces` finding is in `backlog.md` with its cause, so nobody rebuilds on it.
- Do not commit code that claims more than it delivers. If a wiring step is missing, the status line says
  so rather than the module looking finished.

## Handover to Codex, 2026-09-20

This section hands the work over to a Codex session. It adds what changed on 2026-09-19/20 and states,
per open story, whether the specification is complete enough to implement without asking the author.

### What changed on 2026-09-19/20 (all merged to `main`)

| PR | Change |
|---|---|
| #64 | Settings window overhaul: modal sheets became collapsible sections, sidebar regrouped (`Input`), search shows a path and jumps to the first match, inline notes for disabled controls, permission rows, per-page `Reset to defaults`, plain-text shortcut recorders, `SettingsWindow.swift` split into focused files |
| #65 | Smoothed scrolling for classic mouse wheels (story 6c) |
| #66 | Sentence-case labels, explained shortcut-set states, chevron in the shortcut overview |
| #67 | App icon: grey background `#9D9C9C`, colored traffic lights, one look in light and dark |
| #68 | Exceptions page rebuilt as rows with app name, icon and labelled options; old 4-column `TableView` deleted |
| #69 | First open of the settings window: 3.7 s → 0.33 s. Pages are built on demand, shortcut registration no longer runs while pages are built, Cmd-Tab editors build when selected |
| #71 | Pointer & Scroll grouped into `Mouse`/`Trackpad`, System Actions app lists with icons, long help texts moved into info buttons, recorder text right-aligned |

Measured, not assumed: the settings numbers come from in-app probes (build 3713 ms → 1767 ms → 330 ms;
show 253 ms → 38 ms; the background chain finishes ~1.5 s after the window is visible). The greyscale
illustration path was measured at ~13 ms per image before and ~4 ms after #68.

Not verified by operating: every page was checked in screenshots, but the interactions were not run —
recording a shortcut, the conflict dialog across two Cmd-Tab slots, `Reset to defaults` on each page,
adding and removing apps in System Actions and Exceptions, and smoothed scrolling with a real wheel mouse
in several apps. `docs/settings-window-checklist.md` has one item open from before.

### Open stories and their specification quality

**Ready to implement as written**
- **Story 9, Thumbnail-Drop, rest**: the drop path exists (`src/ui/main-window/TilesView.swift:674`);
  spring-loading (TD-01/TD-02), the settings switch and the dwell preference are missing. The backlog has
  the state machine, acceptance criteria and defaults (1.5 s, range 0.5–3.0 s).
- **Story 17, URL scheme**: full spec, allowlist per action, default off. One open decision: the scheme
  name (`alttabplus` is a proposal).
- **Story 11, switcher deltas**: four named deltas with a preserved default; preference keys are not
  named, pick them in the established style.

**Needs a decision from the author first**
- **Story 6b, SwiftFormat**: `.swiftformatignore` ends in `**/*`, so the pre-commit lint checks nothing.
  Three ways out, the backlog says the work is the decision itself.
- **Story 2G follow-up**: two candidate paths for the native title-bar drag, neither chosen.
- **Story 6b, Move/Resize exception column**: one shared column or two.

**Blocked by a spike, do not start**
- **Story 18, apps bound to spaces**: two proofs required first; only the private wrapper exists
  (`src/api-wrappers/private-apis/SkyLight.framework.swift:129`).
- **Story 2F, linked spaces across displays**: spike open. Read S-10d (2026-09-16) before the older
  2026-08-07 paragraph, which it disproves but does not delete.
- **Story 2H**: no system path; specified and resting.
- **Story 7, three-finger middle click**: design constraints only — no acceptance criterion, no UI
  placement, no preference key.
- **Story 4c, per-device pointer settings**: its own exit criterion forbids building while the read path
  is unresolved.

### Verification debt (checklists never run on the target machine)

`docs/tahoe-tiling-checklist.md` (blocks the Phase 5 residue), `docs/leader-flickring-checklist.md`,
`docs/profiles-checklist.md`, `docs/window-drag-checklist.md` (needs two displays),
`docs/system-actions-checklist.md`, `docs/scroll-direction-checklist.md` (V-17, and V-18 has no checklist
yet), `docs/shortcut-clues-checklist.md`, `docs/space-identity-checklist.md`, menubar drop stage 2,
V-10 step 11 negative half, V-16.

### Conventions a new session must follow

- Swift 5.8 only, no SwiftUI, no Interface Builder, no Xcode GUI (`AGENTS.md`).
- `./build.sh --test` before every commit; Conventional Commits with a subject of at most 72 characters.
- Any changed `NSLocalizedString` needs `scripts/l10n/extract_l10n_strings.sh`; CI fails otherwise. When a
  key is renamed, rename it in all 59 `resources/l10n/*.lproj/Localizable.strings` files, or the
  translations are lost.
- New files must be registered by hand in `alt-tab-macos.xcodeproj/project.pbxproj`, `*Testable.swift`
  files in the app target and the unit-tests target.
- Local Xcode is 27, CI runs `macos-15`. Guard macOS 26 SDK APIs, and keep expressions short: the build
  enforces a 250 ms type-check limit per expression.
- PRs go to `gcolicig/alt-tab-old`; `gh` needs `--repo gcolicig/alt-tab-old`, otherwise it targets the
  upstream repository.
- Settings pages are built on demand since #69. A page may not exist when other code runs: never force
  unwrap a control of another page, and route conflict resolution through preferences, not the UI.

## Handover to Codex, second session of 2026-09-20

This section continues the handover above. It covers the work of 2026-09-19/20 that the first section
does not, and states per item whether it is specified well enough to implement without asking the author.

### What shipped

| PR | Change |
|---|---|
| #63 | `Focus on 3 Foremost Windows`, menu reorder, microphone key, plus two new system actions: `Paste and Match Style` (`system.pasteAsPlainText`) and `Press and Hold for Accents` (`keyboard.pressAndHold.toggle`) |
| #70 | README and changelog for both actions |
| #72 | Spaces preview from a Space segment |

`Paste and Match Style` replaces the clipboard with its plain text, posts `Cmd+V` to the front app, and
restores the original clipboard 0.5 s later unless something else wrote to it. It does not send the system
`Cmd+Option+Shift+V`, because apps may ignore that. Operated on 2026-09-19: the paste arrived, the
formatting was gone, and the rich clipboard came back. Steps 42 and 43 of
`docs/system-actions-checklist.md` are therefore closed; 44 to 50 are open.

`Press and Hold for Accents` writes the global `ApplePressAndHoldEnabled` preference. Apps read it at
launch, so a notice asks for an app restart. Unlike `Function Keys`, it never gives the earlier value
back; the README says so. Not operated.

### Open defects

**V-22, a segment click opens the menu instead of the preview.** Reported 2026-09-20, not reproducible
by eye. The click path and the three ways it falls through to the menu are written up in
`docs/spaces-menubar-checklist.md`, together with an 18-step click matrix (A1–A18). The y axis is ignored
on purpose in `handleSegmentClick()`; the comment there says why, so a fix must not simply add a y test
without taking the 37 pt menu bar into account.

Neither Codex nor Claude can click a menu bar item here: `osascript` has no accessibility permission, and
granting it is out of scope. So the pure hit-test maths belongs in `MenubarSpaceRow` with unit tests, and
the clicks stay with the author. The app takes `--logs-file=<path>`, because a GUI app has no usable
stdout and launching its binary from a terminal misattributes the TCC grant.

**V-23, `⌃1` cannot be recorded for `Space 1`.** Step 13 of `docs/settings-window-checklist.md`, failed
on 2026-09-18. The recorder ends up holding `⌃` alone: the digit never reaches it, and the recorder
accepts modifiers on their own, so releasing the key saves the modifier. Steps 12 and 14 of that
checklist passed the same day.

Ruled out by measurement on 2026-09-18:
- macOS: the symbolic hotkeys 118–127 (`⌃1` to `⌃0`, switch to desktop) read back disabled, and
  `com.apple.symbolichotkeys` has no stored entry for 118 or 119.
- AltTab+ owns none of them: its `ownedSystemHotkeys` record is empty.
- No AltTab+ shortcut is `⌃` plus a digit.
- No menu item or window key equivalent uses a digit.
- The silent rejection in `CustomRecorderControlTestable.isShortcutAcceptable`
  (`modifiersOnlyButContainsKeycode`) applies to `holdShortcut…` ids only, not to `space1Shortcut`.

Open hypothesis: something swallows the digit while `⌃` is held — another app's Carbon hotkey, or a path
inside AltTab+ between the event tap and the recorder. The measurement was prepared but never ran: two
probe lines (one in the tap for key code 18 with `⌃`, one in `recorderControl(_:canRecord:)`) wrote
nothing, and the code was removed again. Repeat it with `--logs=error --logs-file=<path>`, which keeps
window titles out of the file, and press `⌃1` once in the recorder for `Space 1`.

### Specification quality of what is left

**Ready to implement as written**
- **Story 17, URL scheme**: unchanged from the first section. Full spec, allowlist, default off. The
  scheme name is the one open decision (`alttabplus` is a proposal).

**Specified, but two gaps to close first**
- **Story 2D stage 2, profiles**: the backlog names the actions (start profile apps, assign windows to the
  profile Space, save and restore a session), the snapshot fields and the best-effort rules. Missing:
  preference keys, where the actions sit in the settings, and whether restore is one action or one per
  profile. Pick them in the established style, or ask.

**Closed in this session**
- Always on Top and a command palette are non-goals with a reactivation criterion, in `backlog.md` under
  `Nicht-Ziele fuer die erste Iteration`. Always on Top would need a SIP-weakening scripting addition;
  a spike that proves a way without one reopens it.

### Outside this repository

A specification for `New++`, a separate Finder-extension app that creates files from templates, was
written on 2026-09-19 and handed to the author as a file. It is deliberately not part of AltTab+; the only
planned link is a URL scheme on each side. Do not add file-creation features here.

## Handover to Codex, third session of 2026-09-20

This section covers the late work of 2026-09-20. It states per item whether it is specified well enough
to implement without asking the author.

### V-22 has a cause and a fix

`event.locationInWindow` is intermittently pinned to the status window's left content inset for clicks
on the part of the status item that was added beyond its original square. The recorded pair is
`(0, 11.21)` for a click whose live screen point converted to `(40.695, 11.21)`, which lies inside the
Spaces row. The x test failed, `handleSegmentClick()` returned false, and the menu opened.

The handler now converts `NSEvent.mouseLocation` through the status window. The hit test moved to
`MenubarSpaceRow.hitTarget(at:spacesRect:muteRects:)`, so it is unit-testable without a click: the
recorded pair, the half-open horizontal range at every menu bar height, and mute icons winning over the
row. 369 tests pass.

What is left is the device run: matrix A1-A18 in `docs/spaces-menubar-checklist.md`, now listed as V-22
in `backlog.md`. Neither Codex nor Claude can click a menu bar item here, so this stays with the author.
Do not add a y test to the hit target; the comment in `MenubarSpaceRow` states why the y axis is ignored.

### Renaming the app

The author decided on `Panion`, with the subtitle
`Keyboard-first window switching, layouts, focus, and workspace control for macOS.`

Measured against the name in an earlier session: the name is in use elsewhere. There is a Mac App Store
app `Panion - Panic Companion`, a company of that name, and the GitHub name is taken. The author accepts
this. Repeat the check for GitHub, Homebrew and the trademark register before the first public release,
because a release is the point where a clash starts to cost.

What the name touches, measured on 2026-09-20:

| Ort | Befund |
|---|---|
| `config/base.xcconfig` | `PRODUCT_NAME = AltTab+`, `PRODUCT_BUNDLE_IDENTIFIER = com.gcolicig.alttab-plus` |
| `src/ui/App.swift` | `App.name` reads `CFBundleName`, so most on-screen text follows the product name |
| Swift sources | 13 literals containing `AltTab` |
| `resources/l10n` | 7 English strings contain the name, across 59 locales |
| Bundle id | appears in 6 files: the xcconfig, `README.md`, `backlog.md`, two checklists, the install skill |
| `Info.plist` | `SUFeedURL` is empty, so no appcast breaks |
| Preferences and TCC | both are keyed by the bundle id |

Three stages, in this order:

1. Product name only, bundle id unchanged. Settings and permissions survive, because macOS keys both by
   the bundle id. Touches the xcconfig, the 13 literals, the 7 English strings, the README head and the
   GitHub description. The 58 translations keep the old name until Crowdin catches up.
2. Bundle id, with a one-shot preference migration in `PreferencesMigrations.swift` following the
   existing marker pattern. Accessibility and Screen Recording must be granted once more; that cannot be
   avoided, because macOS treats a new id as a new app.
3. Repository and delivery: rename the GitHub repository, set the description, adjust the zip name in
   `scripts/update_readme_and_website.sh`.

### When to rename

Do stage 1 and 2 together, in one release, and do it before the first public release, while the author is
the only user. Two reasons, both measurable rather than a matter of taste:

- The permission reset in stage 2 hits every installation. Today that is one machine. After a release it
  is every user, and each one must find two panes in System Settings.
- The 58 translations carry the name. Every week of further translation work adds strings that have to be
  regenerated a second time.

Do not rename in the middle of the open device runs. V-19 to V-22 and the system-actions checklist steps
44 to 50 are written against an installed `AltTab+`, and stage 2 resets the permissions those runs
depend on. Finish the open runs, rename, then re-run only the permission-sensitive steps.

### Specification quality of what is left

**Ready to implement as written**
- The rename, stages 1 to 3 above. The author accepted `Panion`; finish the permission-sensitive device runs first.
- Story 17, URL scheme. Unchanged. The scheme name is the one open decision, and it depends on the
  rename: pick it after stage 1, not before.

**Needs a device, not a coder**
- V-22 matrix A1-A18, V-19, V-20, V-21, and steps 44 to 50 of `docs/system-actions-checklist.md`.

**Specified, with two gaps**
- Story 2D stage 2, profiles. Unchanged from the second section: preference keys, the place in the
  settings, and whether restore is one action or one per profile are still open.
