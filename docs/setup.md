# Setup

This fork is meant to be cloneable, buildable, and hackable without access to the original AltTab release infrastructure.

## Requirements

- macOS
- Xcode 16 or newer
- Command line tools available for `xcodebuild`
- XcodeGen, for the future generated-project workflow
- Git

This repository's `build.sh` uses `/Applications/Xcode.app/Contents/Developer` automatically when it exists. You can also select Xcode globally if your user has permission:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Or set it only for one command:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./build.sh --run
```

## Build And Run

```bash
./build.sh --run
```

The script builds the `Debug` scheme with ad-hoc signing, so local builds do not require an Apple Developer certificate.

The project currently keeps the upstream `.xcodeproj` as the source of truth. If a future `project.yml` is added, `build.sh` will run XcodeGen before building.

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
