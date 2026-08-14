# Handover

Written 2026-08-05, revised 2026-08-10 and 2026-08-14, for whoever picks this up next. It records what is built, what is
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
| Leader (Phase 4) | core only, **no caller** | no |

The unit-test suite passes. Build with `./build.sh --test`; `SCHEME=Release ./build.sh` also works again.

## What happened between 2026-08-10 and 2026-08-14

- **V-10 ran, at last.** Steps 1–10 and 12 pass. Three defects were found by operating, none by tests:
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
- Switching the Space of a display the cursor is not on is not possible. Four routes were measured on
  2026-08-07 and all failed: the gesture carries no target display, a cursor warp does not move the active
  menubar display, the setter meant for it is accepted and ignored, and moving the Space layers changes the
  reported value without changing the picture. The menubar row therefore refuses such a click and says so
  rather than doing nothing. See S-10, S-10b and S-10c in `backlog.md`. One route was never measured,
  though: the synthetic gesture is posted without ever setting `event.location`. Whether a location on
  the target display addresses it is the first spike of the current Spaces plan.
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
