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

Local builds do not require an Apple Developer certificate. For stable macOS permissions across rebuilds, set up the local self-signed signing identity once:

```bash
scripts/codesign/setup_local.sh
```

The setup imports a private key into the login keychain and marks its self-signed certificate as trusted for code signing. The generated certificate password and temporary key material are removed after setup and are not printed by the scripts.

After that, `build.sh` automatically signs the app with `AltTab+ Local Codesign`. This avoids the common TCC problem where System Settings shows Accessibility or Screen Recording as enabled, but a newly rebuilt ad-hoc app is treated as a different binary and still reports `Not allowed`.

The project currently keeps the upstream `.xcodeproj` as the source of truth. If a future `project.yml` is added, `build.sh` will run XcodeGen before building.

## Install Locally
```bash
./build.sh --install
```

This copies the app to `/Applications/AltTab+.app`. macOS may still ask for Accessibility and Screen Recording permissions on first launch.

Do not run the full build with `sudo`. The local signing identity lives in your login keychain, so the build should run as your normal user. If `/Applications` requires elevated permissions, `build.sh --install` asks for them only while copying the finished app.

If you already ran `sudo ./build.sh --install`, the build output may now contain root-owned files. Fix that once with:

```bash
sudo chown -R "$USER" DerivedData
```

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

If a permission gets stuck:

- Quit every running AltTab+ instance.
- Remove the AltTab+ entries from Accessibility and Screen Recording.
- Build once after running `scripts/codesign/setup_local.sh`.
- Launch that build and grant the permissions again.
