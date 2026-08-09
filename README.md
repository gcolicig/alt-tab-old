# AltTab+

AltTab+ is a fork-friendly snapshot of AltTab `v10.12.0`, the last known release before AltTab Pro was introduced upstream.

The goal of this repository is simple: clone it, build it, run it, read it, change it, and keep it understandable. This fork intentionally avoids requiring access to the original project's Apple certificates, AppCenter project, GitHub bot token, Sparkle private key, or release infrastructure.

Upstream project: https://github.com/lwouis/alt-tab-macos

## What It Does

AltTab brings Windows-style window switching to macOS. It lists open windows, supports keyboard shortcuts, shows previews when permitted by macOS, and lets you focus windows quickly.

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

## Window Layouts

Open `Settings > Window Layouts` and record the global shortcuts you want to use. No shortcuts are assigned by default, so the feature does not take over existing macOS or AltTab+ key combinations.

`Move to next display` and `Move to previous display` move the focused window between displays in their physical order, from left to right and then top to bottom. The window keeps its relative position and size, and is bounded by the target display when that one is smaller. A display move is not a layout, so it does not become the frame that `Restore` returns to.

The `Window Layouts` and `Spaces` sections each offer presets that assign a whole set with one click and remove it the same way. Assigning a preset overwrites what the keys carried, and removing it restores exactly that earlier state. Presets of the same area assign the same shortcuts, so only one of them can be assigned at a time; the others stay disabled until it is removed. A preset whose shortcuts you changed since assigning it is marked `Modified`. Removing it asks first, because restoring the earlier state discards those changes. Presets that use `Control` also take the matching macOS shortcuts over for as long as they are assigned.

`Restore` returns a window to the frame it had before its first AltTab+ layout action in the current app session. Fullscreen, minimized, non-standard, and non-resizable windows are left unchanged.

### Dual-Role Hyper Key

Keep Caps Lock mapped to `Caps Lock` in `System Settings > Keyboard > Keyboard Shortcuts > Modifier Keys`, then enable `Use Caps Lock as system-wide Hyper key` in `Settings > Hyperkey`. AltTab+ suppresses the native event while the module is enabled and emits a single Caps Lock tap only for a short physical press. Once a press crosses the configured hold threshold, the Caps Lock indicator is kept off.

A short Caps Lock tap still toggles Caps Lock on or off. Holding Caps Lock while pressing another key sends that key with Command, Control, Option, and Shift, so the combination can be used by macOS and other apps. The tap/hold threshold is configurable and defaults to 200 ms.

Hyper combinations use the same global shortcuts configured in `Window Layouts`; there is no second set of arrow-action mappings. Left and Right focus reveal 24 pixels at the opposite edge, while Center focus leaves 12 pixels visible on both sides. AltTab+ keeps the last Center focus window between the two side windows in the stacking order so all three remain reachable by mouse. The module is disabled by default.

The implementation adds Hyper modifiers to complete key-down/key-up pairs instead of posting standalone modifier-down events. Its own synthetic Caps Lock tap is tagged so AltTab+ does not process it recursively. Leader sequences, FlickRing, and mouse-driven move/resize remain planned work in [ROADMAP.md](ROADMAP.md).

### Input Safety

`Command+Control+Option+Shift+Escape` is a fixed emergency shortcut. It disables Hyper and gestures, closes the switcher, and blocks AltTab+ window-layout actions until an input extension is deliberately enabled again.

Repeated keyboard event-tap failures disable Hyper instead of retrying indefinitely. A startup marker also puts input extensions into safe mode if AltTab+ did not finish the previous Hyper activation. Safe mode can be set before launch with:

```bash
defaults write com.gcolicig.alttab-plus inputModulesSafeMode -bool true
```

The manual verification procedure is in [docs/input-safety-checklist.md](docs/input-safety-checklist.md).

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

- Accessibility: needed to observe, list, and focus windows.
- Screen Recording: needed for live window thumbnails.

These permissions are granted locally in System Settings. The app does not upload window titles, screenshots, or usage statistics.

Because this fork uses the bundle identifier `com.gcolicig.alttab-plus`, macOS treats it as separate from the original AltTab app and earlier AltTab Old builds. You can install them side by side, but running them simultaneously may cause global shortcut conflicts.

If permissions appear enabled in System Settings but AltTab+ still says `Not allowed`, rebuild with the local signing identity above, then remove and grant the AltTab+ permission entries once. Ad-hoc builds can look like a different app to macOS after every rebuild.

## Interacting macOS Settings

AltTab+ changes exactly one class of system setting, and only on request: the keyboard shortcuts a preset needs, which it gives back when the preset is removed. Everything below is left alone, but it does change how the modules behave, so it is listed here rather than silently worked around.

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
        +--> macOS Screen Recording APIs
        +--> local UserDefaults preferences

Optional, disabled unless configured:
        +--> Sparkle update feed
        +--> AppCenter crash reports
        +--> GitHub Issues feedback
```

## Fork-Friendly Defaults

- Bundle identifier is fork-specific: `com.gcolicig.alttab-plus`.
- Sparkle automatic update checks are disabled by default.
- Crash reporting starts only when an AppCenter secret is configured.
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

This fork keeps the upstream GPL-3.0 license. See [LICENSE](LICENSE).
