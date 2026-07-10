# AltTab Old

AltTab Old is a fork-friendly snapshot of AltTab `v10.12.0`, the last known release before AltTab Pro was introduced upstream.

The goal of this repository is simple: clone it, build it, run it, read it, change it, and keep it understandable. This fork intentionally avoids requiring access to the original project's Apple certificates, AppCenter project, GitHub bot token, Sparkle private key, or release infrastructure.

Upstream project: https://github.com/lwouis/alt-tab-macos

## What It Does

AltTab brings Windows-style window switching to macOS. It lists open windows, supports keyboard shortcuts, shows previews when permitted by macOS, and lets you focus windows quickly.

## Build And Run

```bash
./build.sh --run
```

That is the normal local-development path. It builds the `Debug` scheme with ad-hoc signing, so no Apple Developer certificate is required.

For details, see [docs/setup.md](docs/setup.md).

Requirements: Xcode 16 or newer, command line tools for `xcodebuild`, and Git. XcodeGen is installed/checked for the future generated-project workflow; the current upstream `.xcodeproj` remains the source of truth until a complete `project.yml` is added.

## Install Locally

```bash
./build.sh --install
```

This copies the app to `/Applications/AltTab Old.app`.

## Required macOS Permissions

- Accessibility: needed to observe, list, and focus windows.
- Screen Recording: needed for live window thumbnails.

These permissions are granted locally in System Settings. The app does not upload window titles, screenshots, or usage statistics.

## Data Flow

```text
Keyboard / mouse input
        |
        v
AltTab Old running locally
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

- Bundle identifier is fork-specific: `com.gcolicig.alt-tab-old`.
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
