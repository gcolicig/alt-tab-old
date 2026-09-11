# Window Reachability Checklist

This decides one thing: does AltTab+ still list every window the user can reach, after it started dropping
windows the user cannot reach.

## Why the rule exists

An application can hide a window without destroying it. Electron does this with OAuth helper windows.
Claude Desktop (`com.anthropic.claudefordesktop` 1.32352.1, Electron 42.9.2) left two 800x600 windows behind
after a sign-in. Both stayed layer-0 windows in the window server, both kept the `AXStandardWindow` subrole,
and both passed every check in `WindowDiscriminator`. The switcher showed three Claude windows instead of one.

`WindowReachabilityPolicy` (`src/logic/WindowReachability.swift`) drops such a window. It reads no title, no
size, and no `kCGWindowIsOnscreen` on its own. It drops a window only when all of these hold:

- the application did not return it in `kAXWindowsAttribute`, or we never read a usable list,
- `kAXMinimized` is false,
- it is not a background tab of a window tab group,
- its application is not hidden,
- it carries no title of its own, from accessibility or from the window server,
- `CGSCopySpacesForWindows` returns no Space for it,
- `kCGWindowIsOnscreen` is not true.

The title condition exists because of a measurement, not because of a guess. See below.

A window that is added from a window-created notification is never refused; the application has not been
asked about it yet. Such a window is only hidden later, if it stays orphaned.

## Measured on macOS 26.6, 2026-08-18

A live comparison of the same session, once with the previous build and once with the fix:

| Window | In `kAXWindowsAttribute` | Space | On screen | Own title | Verdict |
|---|---|---|---|---|---|
| Claude 1799, main | yes | 3 | yes | `Claude` | kept |
| Claude 1803, 1804, OAuth helpers | no | none | no | none | dropped |
| Finder 762, background tab `_notizen` | no | none | no | `_notizen` | kept |
| Markdown Viewer 833, `Claude-Masterclass.md` | no | none | no | title | kept |
| Bitwarden 41, minimized | no | 3 | no | title | kept |

Two findings came out of it:

- A **minimized window keeps its Space**. Bitwarden 41 was minimized and still reported Space 3. So the
  Space condition alone already protects minimized windows; `kAXMinimized` is the second guard, not the first.
- A **background tab is indistinguishable from a hidden window in the window server**. Finder 762 reported
  no Space and no `kCGWindowIsOnscreen`, exactly like the Claude helper windows. Worse, AltTab+ does not
  always know that a window is a tab: it reads the tab titles from an `AXTabGroup` child, and an application
  that draws its own tab bar exposes none. Without the title condition, the fix dropped a Finder tab and a
  Markdown Viewer window. The title is what still separates the two: a tab names its document, a forgotten
  helper window names nothing.

## Automated coverage

`unit-tests/WindowReachabilityTests.swift` covers the policy itself. The wiring around it needs a Mac.

## Manual steps

Run every step and record the macOS build.

1. **Claude sign-in.** Sign out of Claude Desktop, quit it, start it again, and stop on the first sign-in
   screen. Open AltTab+: exactly one Claude window is listed. Click `Get started`, and check again: the same
   single window is listed. Complete the sign-in, then open AltTab+ again: still exactly one Claude window.
2. **Minimized window.** Minimize a window of any application. Open AltTab+ with
   `Show minimized windows` on: the window is listed, with its minimized marker.
3. **Other Space.** Move a window to a second Space, switch back, and open AltTab+ with
   `Spaces to show: all`: the window is listed with the right Space index.
4. **Hidden application.** Hide an application with `cmd+h`. Open AltTab+ with
   `Show hidden windows` on: its windows are listed.
5. **Tab group.** Open three Finder tabs in one window, then open AltTab+ with
   `Show tabs as windows` on: all three tabs are listed.
6. **Application without accessibility support.** Open a window of an application that exposes no
   `kAXWindowsAttribute` list (for example a Wine or a Steam window) and check that it is still listed.
7. **Only show applications.** Set `Show: applications`, repeat step 1, and check that Claude still appears
   with its main window as the entry, not with a hidden helper window.

## What a failure looks like

A missing window in steps 2 to 7 means the policy is too strict. Turn on debug logging and look for
`Window rejected` and `removing unreachable windows` lines: they carry the facts that led to the decision.
