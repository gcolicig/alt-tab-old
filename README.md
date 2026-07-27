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
- The `Window Layouts` settings section provides unassigned global shortcuts for thirds, two-thirds, three-quarters, edge-revealing focus layouts, and restoring the previous frame.
- An optional dual-role Caps Lock key provides system-wide Hyper shortcuts while preserving normal Caps Lock toggling on a short tap.

## Window Layouts

Open `Settings > Window Layouts` and record the global shortcuts you want to use. No shortcuts are assigned by default, so the feature does not take over existing macOS or AltTab+ key combinations.

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
