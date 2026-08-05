# Handover

Written 2026-08-05 for whoever picks this up next. It records what is built, what is genuinely verified,
and the traps this codebase has already sprung — so they need not be sprung twice.

`backlog.md` is the specification and `ROADMAP.md` the phase overview; both are current. This file adds the
part that is easy to lose: which claims rest on measurement and which do not.

## Where the work stands

| Area | Built | Operated on the target machine |
|---|---|---|
| Action registry, window layouts, Spaces, menubar row | yes | yes |
| Pointer acceleration/speed ownership (S-03) | yes | **no — V-10 has never run** |
| Cursor AX window core (3A) | yes | indirectly, through the drag |
| Modifier move, snapping, overlay (3B) | yes | yes, repeatedly |
| Resize (3C) | yes | yes |
| Menubar drop target (2G stage 1) | yes | yes |
| Shortcut Clues (2E) | yes | reader measured; overlay **not operated** |
| Leader (Phase 4) | core only, **no caller** | no |

188 unit tests pass. Build with `./build.sh --test`; `SCHEME=Release ./build.sh` also works again.

## The most important thing to understand

**The unit tests have never found a real defect in this project.** Every one of the roughly ten defects
found so far came from operating the app or measuring the system. The tests are worth keeping — they caught
several regressions while refactoring — but they are not evidence that a module works.

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

## How to diagnose a hang

This has worked twice, in minutes, where reasoning would have taken hours:

```bash
sample <pid> 2 -f /tmp/hang.txt
```

Then read the main thread's stack. Both hangs were immediately obvious from it. **Take the sample before
restarting anything** — a restart destroys the evidence, and the failure has not been reproducible on
demand.

## What needs the target machine next

In rough priority:

1. **V-10** for the pointer module (`docs/pointer-ownership-checklist.md`). Its writing path has never been
   executed, by a test or by a human. Given the hit rate elsewhere, assume something is wrong.
2. **The drag checklist** (`docs/window-drag-checklist.md`), remaining steps. Move, resize, snapping, the
   overlay and the drop have all been operated, but not systematically across app classes.
3. **Shortcut Clues** (`docs/shortcut-clues-checklist.md`). The reader was measured against Finder; the
   overlay has never been shown.
4. **S-01/S-02** and the app-class matrix for the AX core.
5. **The Spaces menubar checklist** steps 1 and 2, which describe a state never actually observed — see the
   `screensHaveSeparateSpaces` trap above.

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

## Working agreements that produced the good results

- Measure before building on an assumption. The spec for Shortcut Clues demanded it explicitly, and the
  assumption was wrong twice in that one module.
- When a hypothesis is disproved, say so plainly and record the disproof — the retracted
  `screensHaveSeparateSpaces` finding is in `backlog.md` with its cause, so nobody rebuilds on it.
- Do not commit code that claims more than it delivers. If a wiring step is missing, the status line says
  so rather than the module looking finished.
