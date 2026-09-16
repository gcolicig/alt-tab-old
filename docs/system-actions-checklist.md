# System Actions Checklist (Stories 10, 12, 13, 14, 15)

Run on the supported Apple-silicon Mac and record the macOS build. Everything here was built on
2026-09-16 and is covered only by unit tests for its pure parts (`MenuLayoutTests`, `WindowFocusTests`,
`SystemActionTests`, `ScreenToolsFormatTests`, `KeepAwakeTests`, `DebugToolsTests`). The app launched and
stayed idle at 0 % CPU; the menu itself has not been looked at on the device.

Emergency shortcut: `Command+Control+Option+Shift+Escape`.

## Menu (story 15)

| # | Action | Expectation |
|---|---|---|
| 1 | Open the menubar menu after the update | Groups Switcher, Windows, a `Tools >` submenu with all five tools, and the AltTab+ block; headings on macOS 14+; no double or trailing separator |
| 2 | `Settings > Menu Bar Menu`: turn every group on | All groups appear in order: Switcher, Windows, Apps, Tools, Notifications, System, Toggles, Defaults, AltTab+ |
| 3 | Turn one entry off, then its whole group | The entry disappears, then the heading and separator of the group |
| 4 | Assign a shortcut to `Isolate Window` in the same tab | The shortcut works outside the menu |
| 5 | Bind `Clear Clipboard` to a Leader key and a FlickRing direction | Both run it |
| 6 | Open the menu with a disabled entry (e.g. `Eject All Disks` with no disk) | Entry greyed out; tooltip names the reason |

## Windows (story 12)

| # | Action | Expectation |
|---|---|---|
| 7 | Isolate with Finder, Terminal and two Safari windows, Safari in front | Only the focused Safari window stays; the other is minimized; Finder and Terminal hidden |
| 8 | Isolate a fullscreen window | Other apps hide; no Space changes |
| 9 | Another app window in fullscreen | Stays in fullscreen, not minimized |
| 10 | Isolate with only the desktop focused | Beep, nothing changes |
| 11 | Two displays | Apps on the second display are hidden; minimizing only touches visible Spaces |

## Apps and system (story 14)

| # | Action | Expectation |
|---|---|---|
| 12 | `Quit All Apps…` | Prompt lists the apps; Cancel changes nothing; Quit terminates them; an app with an unsaved document asks itself |
| 13 | Auto-Quit on, TextEdit in the list, delay 10 s, close its last window, switch to another app | TextEdit quits after about 10 s; opening a new window inside the delay prevents it |
| 14 | `Sleep Displays` | Displays go dark and wake normally on a key press. If not: record which of `pmset displaysleepnow` and `IODisplayWrangler` failed (log) |
| 15 | `Mute Sound`, `Mute Microphone`, then switch AirPods on and off | Checkmarks follow the real device state |
| 16 | `Eject All Disks` with a USB stick, a disk image and a busy disk | First two ejected; the busy one named in the notice |
| 17 | `Default Browser >` | Installed browsers with icons, current one checked; choosing one shows macOS' own confirmation |
| 18 | `Function Keys` toggle (V-20) | F1–F12 switch between media and function keys at once; `Settings > System Actions > Restore Original Mode` gives back the earlier mode |
| 19 | Open `Settings`, then every sidebar entry | No crash; `Menu Bar Menu` lists every group with its switches |

## Tools (story 14I)

| # | Action | Expectation |
|---|---|---|
| 20 | `Pick Color` | Loupe appears; the hex value lands on the clipboard |
| 21 | `Capture Text` on two displays with different scaling | Crosshair on both; Escape cancels without leftovers; text lands on the clipboard |
| 22 | `Capture & Translate` (macOS 26) | Panel with original and translation; without installed languages the dialog offers System Settings |
| 23 | `Scan QR Code` on a URL code | Content copied; dialog offers Open, nothing opens by itself |
| 24 | `Scan QR Code from Clipboard` | Greyed out without an image on the clipboard; works with one |

## Notifications (story 14H, V-21)

| # | Action | Expectation |
|---|---|---|
| 25 | Produce three notifications, run `Clear Visible Notifications` | Visible banners close; the notice names the count. Record whether Notification Center had to open |
| 26 | `Clear All Notifications` | Notification Center is empty afterwards |

## Cat Mode (story 14K, V-19)

| # | Action | Expectation |
|---|---|---|
| 27 | Turn on, type anything | Nothing reaches the front app; overlay visible on every display |
| 28 | Type `unlock` | Cat Mode ends |
| 29 | Turn on, press the emergency shortcut | Cat Mode ends and safe mode turns on |
| 30 | Turn on, end it from the menu | Ends |
| 31 | Turn on, set auto-end to 5 min and wait; also lock the screen | Ends by itself in both cases |
| 32 | After every end, hold and release each modifier | No modifier stays pressed |

## Keep Awake (story 10)

| # | Action | Expectation |
|---|---|---|
| 33 | `Keep Awake > 15 Minutes` | Checkmark and remaining time in the menu; `pmset -g assertions` lists `AltTab+ Keep Awake` |
| 34 | `Keep Display Awake` on and off during a session | The display assertion appears and disappears |
| 35 | Session running, quit AltTab+ | Assertions are gone |
| 36 | On battery below the threshold | Session does not start or ends with a notice |
| 37 | `Until…` a time earlier than now | Session ends tomorrow at that time |

## Debug (story 13)

| # | Action | Expectation |
|---|---|---|
| 38 | `Debug > Copy Debug Info`, paste into a text editor | No URLs from Open-URL slots, no window titles, no user name in paths; permissions, signature and active modules present |
| 39 | `Copy Accessibility Tree` for Finder, Safari, an Electron app | Header plus indented tree; text fields and windows show only title lengths |
| 40 | Same with a hung app | Partial tree or a notice; the menu bar stays responsive |
| 41 | `Reset Permissions…` → Reset and Restart | App restarts and asks for both permissions again. If `tccutil` refuses, the dialog shows its output |
