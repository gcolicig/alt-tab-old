# AltTab+

AltTab+ is an independent GPL-3.0 fork of [AltTab](https://github.com/lwouis/alt-tab-macos), based on
upstream `v10.12.0` (commit `317a485b`, 13 April 2026). It is not affiliated with, endorsed by, or
supported by the upstream project.

It is no longer only an application switcher. It combines the window and desktop controls that used to need
several menu bar utilities into one app, with one set of settings, one permission prompt, and one emergency
shortcut.

Clone it, build it, run it, read it, change it. The repository needs no Apple certificate, no bot token, no
Sparkle key, and no release infrastructure of the original project.

## Thanks

This app stands on other people's work.

- **Louis Pontoise ([lwouis](https://github.com/lwouis)) and every AltTab contributor**, including
  translators, testers, and issue reporters. Seven years of work on window switching on macOS, and the code
  this fork starts from. Nothing here would exist without it.
- **The tools that shaped keyboard-driven macOS workflows**, among them Rectangle, Magnet, Hyperkey,
  Karabiner-Elements, LeaderKey, Supercharge, Hammerspoon, BetterTouchTool, Raycast and Alfred.
- **The library authors**: ShortcutRecorder, Sparkle, LetsMove and SwiftyBeaver. See
  [docs/acknowledgments.md](docs/acknowledgments.md) and [THIRD-PARTY.md](THIRD-PARTY.md).
- **The free software community**, whose licences make inspection, forking and independent maintenance
  possible in the first place.

## Why This Fork Exists

I use macOS with the expectations of a long-time Windows user: switching should be window-centric, keyboard
workflows should be consistent, and the desktop should not need a row of partly overlapping menu bar
utilities. Over the last ten to fifteen years this became harder rather than easier on macOS. Native window
management stays limited, application-centric switching is often not enough, and useful utilities compete
for the same global shortcuts and Accessibility permissions.

AltTab came very close to solving a large part of this. The surrounding tool chain and its integration work
never did.

In May 2026, upstream released `v11.0.0` and introduced AltTab Pro. The upstream repository continues to be
published under GPL-3.0, and upstream describes the core app as free and open source. This fork therefore
makes no claim about a licence change. The Pro transition was a good moment to reassess the setup: some
capabilities became associated with a Pro badge and a licence check, and I prefer a desktop control stack
whose behaviour stays locally auditable, modifiable, and free of licence-gated states.

Rather than starting another search through fragile tool combinations, I took the route OpenBao took with
HashiCorp Vault: start from the last release before the change, keep the freedoms GPL-3.0 grants, and build
the integrated tool I want to use. Generative AI and agentic coding made that practical for one person.

The result looks like a Frankenstein of several familiar macOS utilities. That is deliberate. The aim is not
to copy every feature of every tool, but to need fewer tools, remove duplicated global hooks, and make the
remaining behaviour predictable.

## What It Does

- **Switcher**: open windows with previews, titles, fuzzy search and mouse hover.
- **Window layouts**: thirds, two-thirds, three-quarters, focus layouts, moves between displays, and a
  restore step, on shortcuts you assign yourself.
- **Spaces**: switch Spaces by shortcut, read them next to the menu bar icon, and open a preview of every display's Spaces from that row.
- **Hyper key**: Caps Lock acts as ⌃⌥⇧⌘ while held, and still toggles Caps Lock on a short tap.
- **Leader sequences**: a trigger, then a short sequence of letters; an overlay shows what may follow.
- **FlickRing**: hold a mouse button, flick in a direction, run the action bound to it.
- **Move and resize with a modifier**, with snapping and a target frame overlay.
- **Menu bar actions**: window and app actions, screen tools, Keep Awake, Cat Mode, Auto-Quit, mute
  indicators for microphone and sound, and a Debug submenu.
- **Pointer and scroll**: separate direction and speed for mouse and trackpad.
- **Profiles** for apps, layout and Space.

Everything that takes over a key, a mouse button or a system value is off by default, names what it takes
over before it is armed, and can be switched off again with one fixed emergency shortcut.

## Screenshots

| Switcher | Spaces in the menu bar | Leader overlay |
|---|---|---|
| ![Switcher](docs/images/switcher.png) | ![Spaces row](docs/images/spaces-row.png) | ![Leader overlay](docs/images/leader-overlay.png) |

## Status

This is an opinionated project under active development. Shortcuts, settings, internal structure and
behaviour still change. Use it if you are comfortable granting Accessibility and Screen Recording
permissions, reading the source, and treating desktop control software as part of your trusted computing
base.

## Fork Lineage

| | |
|---|---|
| Upstream project | [lwouis/alt-tab-macos](https://github.com/lwouis/alt-tab-macos) |
| Fork base | `v10.12.0`, commit `317a485b`, 13 April 2026 |
| Upstream Pro introduction | `v11.0.0`, 21 May 2026 |
| Upstream licence | GPL-3.0 |
| This project's licence | GPL-3.0 |
| Bundle identifier | `com.gcolicig.alttab-plus` |

Upstream commits are reviewed and ported selectively; see [backlog.md](backlog.md) for what was taken and
what was left out.

## Fork Changes

- Support, feedback, manual update checks, update policy, and crash-report policy UI have been removed from the app.
- Auto-update and crash-report preferences are forced to disabled fork defaults at launch.
- When `After keys are released` is set to `Focus selected window`, pressing Escape while the configured hold shortcut is still down cancels the switch without focusing the selected window. This works for Shortcut 1 and Shortcut 2.
- While using `Focus selected window`, pressing the physical ISO Section key above Tab while the configured hold shortcut is still down opens fuzzy search without focusing it first. This works across keyboard layouts that expose that physical ISO key, independent of the printed character.
- The switcher shows the search field by default without focusing it. Normal Tab cycling continues until search is activated with the mouse, `S`, or the physical ISO Section key above Tab.
- Mouse hover selection is enabled by default.
- Apps with no open window are hidden by default for Shortcut 1, Shortcut 2, and gestures.
- The `Window Layouts` settings section provides unassigned global shortcuts for thirds, two-thirds, three-quarters, edge-revealing focus layouts, moving a window between displays, and restoring the previous frame.
- An optional dual-role Caps Lock key provides system-wide Hyper shortcuts while preserving normal Caps Lock toggling on a short tap.
- Leader sequences, a mouse-button action ring (FlickRing), modifier-drag move and resize with snapping, profiles, and separate scroll direction and speed for mouse and trackpad are built in.
- The menubar menu carries window focus actions, system actions, screen tools, Keep Awake, and a Debug submenu (see below).
- A click on a Space segment in the menu bar opens a preview of the Spaces of every display, laid out the way the displays stand on the desk. Each Space is a miniature of its windows; a click on one switches to it.
- The settings window shows one section at a time, grouped in the sidebar, with a `Shortcuts` page that lists every action shortcut and its conflicts.

## Window Layouts

Open `Settings > Window Layouts` and record the global shortcuts you want to use. No shortcuts are assigned by default, so the feature does not take over existing macOS or AltTab+ key combinations.

`Move to next display` and `Move to previous display` move the focused window between displays in their physical order, from left to right and then top to bottom. The window keeps its relative position and size, and is bounded by the target display when that one is smaller. A display move is not a layout, so it does not become the frame that `Restore` returns to.

The `Window Layouts` and `Spaces` sections each offer presets that assign a whole set with one click and remove it the same way. Assigning a preset overwrites what the keys carried, and removing it restores exactly that earlier state. Presets of the same area assign the same shortcuts, so only one of them can be assigned at a time; the others stay disabled until it is removed. A preset whose shortcuts you changed since assigning it is marked `Modified`. Removing it asks first, because restoring the earlier state discards those changes. Presets that use `Control` also take the matching macOS shortcuts over for as long as they are assigned.

`Restore` returns a window to the frame it had before its first AltTab+ layout action in the current app session. Fullscreen, minimized, non-standard, and non-resizable windows are left unchanged.

### Dual-Role Hyper Key

Keep Caps Lock mapped to `Caps Lock` in `System Settings > Keyboard > Keyboard Shortcuts > Modifier Keys`, then enable `Use Caps Lock as system-wide Hyper key` in `Settings > Hyperkey`. AltTab+ suppresses the native event while the module is enabled and emits a single Caps Lock tap only for a short physical press. Once a press crosses the configured hold threshold, the Caps Lock indicator is kept off.

A short Caps Lock tap still toggles Caps Lock on or off. Holding Caps Lock while pressing another key sends that key with Command, Control, Option, and Shift, so the combination can be used by macOS and other apps. The tap/hold threshold is configurable and defaults to 200 ms.

Hyper combinations use the same global shortcuts configured in `Window Layouts`; there is no second set of arrow-action mappings. Left and Right focus reveal 24 pixels at the opposite edge, while Center focus leaves 12 pixels visible on both sides. AltTab+ keeps the last Center focus window between the two side windows in the stacking order so all three remain reachable by mouse. The module is disabled by default.

The implementation adds Hyper modifiers to complete key-down/key-up pairs instead of posting standalone modifier-down events. Its own synthetic Caps Lock tap is tagged so AltTab+ does not process it recursively. Leader sequences, FlickRing, and mouse-driven move/resize are described in [ROADMAP.md](ROADMAP.md) and specified in [backlog.md](backlog.md).

### Input Safety

`Command+Control+Option+Shift+Escape` is a fixed emergency shortcut. It disables Hyper and gestures, ends Cat Mode, closes the switcher, and blocks AltTab+ window-layout and window-focus actions until an input extension is deliberately enabled again.

Repeated keyboard event-tap failures disable Hyper instead of retrying indefinitely. A startup marker also puts input extensions into safe mode if AltTab+ did not finish the previous Hyper activation. Safe mode can be set before launch with:

```bash
defaults write com.gcolicig.alttab-plus inputModulesSafeMode -bool true
```

The manual verification procedure is in [docs/input-safety-checklist.md](docs/input-safety-checklist.md).

## Menu Bar Menu

The menubar menu is grouped by what the entries do:

```text
Settings…
Switcher        Show
Windows         Isolate Window · Minimize App Windows Except Frontmost · Hide Other Apps · Hide All Windows
Other…      >   Apps           Quit All Apps… · Quit All Apps Except Frontmost…
                Tools          Pick Color · Capture Text · Capture & Translate · Scan QR Code · Scan QR Code from Clipboard
                Notifications  Clear Visible Notifications · Clear All Notifications
                System         Paste and Match Style · Clear Clipboard · Eject All Disks · Sleep Displays
                Toggles        Mute Sound · Mute Microphone · Function Keys · Press and Hold for Accents · Auto-Quit Apps · Cat Mode · Keep Awake >
                Defaults       Default Browser >
About AltTab+ · Check permissions… · Debug > · Quit AltTab+
```

Every action can also get a global shortcut in `Settings > Shortcuts`, and Leader and FlickRing can trigger it. No shortcut is assigned by default. An entry that cannot run right now is greyed out and its tooltip says why.

- `Isolate Window` hides every other app and minimizes the other windows of the front app. Fullscreen windows and windows on other Spaces are left alone.
- `Quit All Apps…` always asks first and never force-quits; apps with unsaved documents ask themselves.
- `Auto-Quit Apps` quits a listed app some time after its last window closed. Configure the list and delay in `Settings > System Actions`. Finder is never quit.
- The screen tools work locally: captures stay in memory, text recognition uses Vision, translation uses the macOS Translation framework (macOS 26 and later). A scanned link is copied and only opened after you confirm.
- `Clear … Notifications` remote-controls Notification Center through accessibility and is only enabled on macOS versions whose structure is known.
- `Mute Microphone` shows a crossed-out microphone in the menu bar while the default input is muted, also when another app muted it. Click it to unmute. Turn the icon off in `Settings > System Actions`.
- `Paste and Match Style` pastes the clipboard as plain text into the front app, in any app, and puts the original clipboard back half a second later unless something else was copied meanwhile.
- `Function Keys` switches F1–F12 between media and standard function keys; `Settings > System Actions` can give the earlier mode back.
- `Press and Hold for Accents` switches between the accent popup and key repeat for a held letter key. Apps read the setting when they start, so restart an app to see the change there. AltTab+ does not give the earlier value back.
- `Cat Mode` locks the keyboard. It ends from the menu, by typing `unlock`, with the emergency shortcut, after a configurable time, and on sleep or screen lock.
- `Keep Awake` uses public power assertions only, never persists them, ends on low battery if configured, and releases everything when AltTab+ quits. Configure it in `Settings > Keep Awake`.
- `Default Browser >` lists apps that open both web links and HTML files; macOS asks for confirmation when you switch.
- `Debug >` copies a debug report or the accessibility tree of the front window, resets AltTab+'s permissions, or opens the debug window. Copied text leaves out window titles, URL slots, text field contents, and your user name.

The manual verification procedure is in [docs/system-actions-checklist.md](docs/system-actions-checklist.md).

## Settings Window

The sidebar groups the sections under AltTab+, Switcher, Windows, Triggers, Devices, and Actions. Without a search, only the chosen section is shown; a search lists every matching section and clearing it returns to the chosen one.

- `Shortcuts` lists every action shortcut with its status: used twice, reserved by macOS, used by the Game Overlay, or replacing a macOS shortcut while assigned. A shortcut that belongs to another page shows `Show`, which opens that page and marks the row. Switcher triggers, the Leader key, and the FlickRing button stay on their own pages.
- `Apps & URLs` and `Profiles` show only filled entries. Add apps from a dialog; there are nine app places, nine link places, and five profiles.
- Export, import, the creator's settings, and resetting all settings are in `General`.

The manual verification procedure is in [docs/settings-window-checklist.md](docs/settings-window-checklist.md).

## Build

```bash
./build.sh
```

This builds the `Debug` scheme without requiring an Apple Developer certificate. For day-to-day testing, set up the local self-signed signing identity once:

```bash
scripts/codesign/setup_local.sh
```

The setup imports a private key into the login keychain and trusts its self-signed certificate for code signing. After that, `build.sh` automatically signs AltTab+ with `AltTab+ Local Codesign`. This keeps macOS Accessibility and Screen Recording permissions stable across rebuilds.

For details, see [docs/setup.md](docs/setup.md).

Requirements: Xcode 16 or newer, command line tools for `xcodebuild`, and Git. XcodeGen is installed/checked for the future generated-project workflow; the current upstream `.xcodeproj` remains the source of truth until a complete `project.yml` is added.

Run the complete local build and unit-test workflow with:

```bash
./build.sh --test
```

## Test Without Installing

```bash
./build.sh --run
```

This builds the app and launches it from:

```text
DerivedData/Build/Products/Debug/AltTab+.app
```

If the app is already built, you can launch it directly:

```bash
open -n DerivedData/Build/Products/Debug/AltTab+.app
```

## Install To Applications

```bash
./build.sh --install
```

This copies the app to:

```text
/Applications/AltTab+.app
```

Run the command as your normal user, not with `sudo`. If `/Applications` needs elevated permissions, the script asks only for the copy step so the build can still use the signing identity from your login keychain.

If you already ran `sudo ./build.sh --install`, fix the build output once with `sudo chown -R "$USER" DerivedData`, then run `./build.sh --install` again.

You can then launch it like any other macOS app. If you previously ran the app from `DerivedData`, quit that copy first so you are testing the installed app.

## Required macOS Permissions

- Accessibility: needed to observe, list, and focus windows, for the window focus actions, for clearing notifications, and for copying an accessibility tree.
- Screen Recording: needed for live window thumbnails and for the screen tools that capture an area.

These permissions are granted locally in System Settings. The app does not upload window titles, screenshots, or usage statistics.

Because this fork uses the bundle identifier `com.gcolicig.alttab-plus`, macOS treats it as separate from the original AltTab app and earlier AltTab Old builds. You can install them side by side, but running them simultaneously may cause global shortcut conflicts.

If permissions appear enabled in System Settings but AltTab+ still says `Not allowed`, rebuild with the local signing identity above, then remove and grant the AltTab+ permission entries once. Ad-hoc builds can look like a different app to macOS after every rebuild.

## Interacting macOS Settings

AltTab+ changes system settings only on request:

- the keyboard shortcuts a preset or an assigned shortcut needs, which it gives back when the shortcut is removed
- pointer acceleration and speed, handed back when you pick `System default` or quit
- the function key mode, when you use `Function Keys`
- the press-and-hold setting (`ApplePressAndHoldEnabled`), when you use `Press and Hold for Accents`
- mute of the default audio devices, when you use `Mute Sound` or `Mute Microphone`; a microphone without a mute control is muted through its volume, which AltTab+ restores when it quits
- the default browser, through the macOS confirmation dialog

Everything below is left alone, but it does change how the modules behave, so it is listed here rather than silently worked around.

| Setting | Where | Effect on AltTab+ |
|---|---|---|
| When switching to an application, switch to a Space with open windows for the application | Desktop & Dock > Mission Control | Applies to app activation, not to focusing a window. On a Space without windows the previously active app stays active, so macOS pulls the screen back to that app's Space. Switching to an empty Space only stays put with this off. |
| Automatically rearrange Spaces based on most recent use | Desktop & Dock > Mission Control | Reorders Spaces behind your back, which moves the target of `Space 1` to `Space 9` and of the menubar row. Keep it off if you use numbered Space actions. |
| Displays have separate Spaces | Desktop & Dock | Decides whether a Space switch affects one display or all of them. AltTab+ follows the system semantics and does not offer its own mode. |
| Reduce motion | Accessibility > Motion | Replaces the Space switching animation with a cross-fade. Multi-step Space jumps traverse every Space in between, so this noticeably calms them. |
| Secure Keyboard Entry | Terminal > Terminal menu | While a terminal with this enabled is focused, macOS blocks keyboard monitoring. The Hyper key stops responding for that time. |
| Group windows by application | Desktop & Dock > Mission Control | Only affects Mission Control itself, not the switcher. |

### Native Shortcuts You Can Hand Over

macOS owns several shortcuts that overlap with what AltTab+ does. A system shortcut wins over any app, so a combination has to be free before AltTab+ can use it. The ids below are symbolic hotkey ids, readable with `CGSGetSymbolicHotKeyValue`; the state was surveyed on macOS Tahoe.

| Combination | macOS function | Ids | To use it in AltTab+ |
|---|---|---|---|
| `Control+1` … `Control+0` | Switch to Desktop 1-10 | 118-127 | Usually already off by default, so `Space 1` to `Space 9` can be assigned directly |
| `Control+Left` / `Control+Right` | Move one Space left or right | 79, 199, 240 / 81, 200, 241 | Several ids share the combination. Disable them one at a time and check after each step that native window tiling still works, since `Fn+Control+Arrow` belongs to Apple |
| `Command+Tab` / `Shift+Command+Tab` | App switcher | 1, 2 | Handled automatically when the shortcut is assigned |
| `Command+§` / `Shift+Command+§` | Next or previous window in the application | 27, 220 | Handled automatically when the shortcut is assigned |
| `Control+Down` | Application windows | 33, 198, 243 | Only worth taking over for a shortcut that shows the windows of the current application |
| `Control+Up` | Mission Control | 32, 242 | No AltTab+ equivalent; leave it |

AltTab+ assigns none of these by itself. The Spaces section offers them as a preset: assigning it takes the matching system shortcuts over, removing it gives them back, and a shortcut you assigned yourself is never replaced. Ownership is remembered across launches, so a system shortcut AltTab+ disabled is restored even if the app was killed.

Disabling a symbolic hotkey persists after AltTab+ quits. Anything AltTab+ does not manage itself should therefore be changed in System Settings, so it stays visible where you expect it.

Space switching moves through the Spaces in between, because the only mechanism available without disabling SIP is a synthetic swipe. Jumping straight to a Space is possible through a private call, but it desynchronizes the Dock and the WindowServer on Tahoe, so it is deliberately not used.

## Data Flow

```text
Keyboard / mouse input
        |
        v
AltTab+ running locally
        |
        +--> macOS Accessibility APIs
        +--> macOS Screen Recording APIs (thumbnails, screen tools)
        +--> Vision and Translation frameworks, on this Mac only
        +--> CoreAudio, IOKit power assertions, HID system parameters
        +--> local UserDefaults preferences
        +--> clipboard, only when you copy a result

Optional, disabled unless configured:
        +--> Sparkle update feed
        +--> GitHub Issues feedback
```

## Fork-Friendly Defaults

- Bundle identifier is fork-specific: `com.gcolicig.alttab-plus`.
- Sparkle automatic update checks are disabled by default.
- AltTab+ contains no crash reporting SDK and sends no crash reports.
- The in-app feedback form falls back to opening this repository's Issues page unless a token is configured.
- The original upstream remote is kept as `upstream`; pushes should go to this fork's `origin`.

## Project Structure

- `src/logic`: window discovery, preferences, event handling, and app behavior.
- `src/ui`: settings, menu bar, switcher UI, dialogs, and panels.
- `resources`: icons, fonts, localization, and illustrations.
- `config`: Xcode build settings using Swift 5.10.
- `scripts`: upstream build, release, signing, localization, and website helpers.
- `docs`: setup, privacy, support material, and upstream website docs.

## Release Notes

Local builds do not need notarization. Public distribution may require:

- your own Apple Developer ID certificate
- your own bundle identifier
- your own Sparkle feed and signing key, or updates disabled
- updated branding if distributing outside personal use

Before publishing a release, run through [docs/open-source-preflight.md](docs/open-source-preflight.md).

## Contributing

Contributions are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), [SUPPORT.md](SUPPORT.md), and [ROADMAP.md](ROADMAP.md).

## License

AltTab+ is licensed under the [GNU General Public License, version 3.0](LICENCE.md). It contains and
modifies code from [AltTab](https://github.com/lwouis/alt-tab-macos), which is published under the same
licence. The upstream licence file is kept unchanged, and upstream copyright and third-party notices stay
in place.

You may run, study, modify and redistribute this software under the terms of GPL-3.0. If you distribute
modified versions or binaries, you must meet the corresponding source and notice obligations of that
licence: ship or link the exact source of the version you distribute.

The AltTab name, icon, website and other branding may be associated with the upstream project. See
[TRADEMARKS.md](TRADEMARKS.md).
