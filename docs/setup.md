# Setup

This fork is meant to be cloneable, buildable, and hackable without access to the original AltTab release infrastructure.

## Requirements

- macOS
- Xcode with command line tools selected
- Git

If `xcodebuild` reports that only Command Line Tools are active, select Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Build And Run

```bash
./build.sh --run
```

The script builds the `Debug` scheme with the local self-signed signing identity configured in `config/debug.xcconfig`.

## Install Locally

```bash
./build.sh --install
```

This copies the app to `/Applications/AltTab Old.app`. macOS may still ask for Accessibility and Screen Recording permissions on first launch.

## Optional Services

The fork does not require these services for local development:

- Sparkle updates are disabled by default.
- AppCenter crash reporting starts only when `AppCenterSecret` is configured.
- The in-app feedback form opens GitHub Issues unless a `FeedbackToken` is configured.
- Release notarization is not required for local builds.

## Permissions

AltTab-style window switching needs:

- Accessibility permission to observe and focus application windows.
- Screen Recording permission to show live window thumbnails.

Both are granted locally in macOS System Settings. They are not sent to any server.
