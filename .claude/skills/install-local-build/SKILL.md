---
name: install-local-build
description: Build AltTab+ locally and replace the /Applications copy cleanly, so a fresh build actually runs. Use when the user says "install the build", "replace the app", "run my fixed build", or when a code change must be verified in the real running app on this Mac.
---

# Install a local build over the /Applications copy

Use this skill to put a fresh local build into `/Applications` and run it. Follow every
step in order. The pitfalls at the end explain why each step exists — skipping one
produced a nested bundle and a false measurement in the past.

## Facts

- App name: `AltTab+`. Bundle id: `com.gcolicig.alttab-plus`.
- The app uses LetsMove. It is present in `/Applications` after the first run.
- Debug and Release builds land in `./DerivedData/Build/Products/<config>-*/AltTab+.app`.

## Step 1 — Build the app

Release build (the project's own script):

```bash
scripts/build_app.sh
```

Debug build, signed with the local identity `AltTab+ Local Codesign`:

```bash
xcodebuild -workspace alt-tab-macos.xcworkspace -scheme Debug -configuration Debug \
  -derivedDataPath ./DerivedData \
  CODE_SIGN_IDENTITY="AltTab+ Local Codesign" CODE_SIGN_STYLE=Manual build
```

The stable identity keeps the Accessibility and Screen Recording grants across rebuilds.
An ad-hoc build (`CODE_SIGN_IDENTITY = -`, the Debug default) loses them on every rebuild.
Check that the identity exists before the build:

```bash
security find-identity -v -p codesigning | grep "AltTab+ Local Codesign"
```

If it is missing, run `scripts/codesign/setup_local.sh` once. `build.sh` uses the same identity.

Before you push a code change, also run the test suite that CI runs:

```bash
./build.sh --test
```

Record the built path. For Debug it is `DerivedData/Build/Products/Debug/AltTab+.app`.

## Step 2 — Quit every running instance

Quit both the DerivedData instance and the `/Applications` instance. Two instances at once
cause LetsMove to hand off between them.

```bash
osascript -e 'quit app "AltTab+"' 2>/dev/null
pkill -f 'AltTab\+\.app/Contents/MacOS/AltTab\+' 2>/dev/null
```

Confirm none remain before you continue:

```bash
ps -Ao pid,command | grep 'AltTab+.app/Contents/MacOS' | grep -v grep
```

## Step 3 — Remove the old /Applications copy, then copy the fresh build

Do not `cp -R` onto an existing bundle. `cp -R src /Applications/AltTab+.app` nests the
build as `/Applications/AltTab+.app/AltTab+.app` when the target already exists.

Make the installed bundle an exact copy of the build. The trailing slashes are required:

```bash
NEW="DerivedData/Build/Products/Debug/AltTab+.app"   # or the Release path
rsync -a --delete "$NEW/" "/Applications/AltTab+.app/"
```

`rsync --delete` also removes files that the new build no longer contains (for example a
removed framework). Do not use `rm -rf "/Applications/AltTab+.app"`: macOS refuses it with
"Permission denied". Do not use `ditto` alone: it leaves removed files in the bundle.

Verify the installed binary is the new one:

```bash
stat -f "%Sm %N" "/Applications/AltTab+.app/Contents/MacOS/AltTab+"
```

## Step 4 — Reset the app's permissions only when the signature changed

Skip this step when the installed app and the new build are both signed with
`AltTab+ Local Codesign`. The grants stay valid (measured 2026-09-15: three rebuilds, no new grant).

Do this step when the signing identity changed, for example from ad-hoc to the local identity.
macOS then still holds grants that do not match the new signature. The stale grants make the
new build misbehave and restart. Remove them BEFORE the first launch, so macOS asks again cleanly.

Check the installed signature:

```bash
codesign -dvv "/Applications/AltTab+.app" 2>&1 | grep -E "Authority|Signature=adhoc"
```

Command line:

```bash
tccutil reset Accessibility com.gcolicig.alttab-plus
tccutil reset ScreenCapture com.gcolicig.alttab-plus
```

Manual alternative, done before the first launch:
- Open System Settings > Privacy & Security > Accessibility.
- Select the `AltTab+` entry and click the minus button to delete it.
- Open System Settings > Privacy & Security > Screen Recording.
- Select the `AltTab+` entry and click the minus button to delete it.

Grant both permissions again after the first launch.

## Step 5 — Launch and confirm

```bash
open "/Applications/AltTab+.app"
```

Confirm one instance runs from `/Applications`:

```bash
ps -Ao pid,etime,command | grep 'AltTab+.app/Contents/MacOS' | grep -v grep
```

## Pitfalls

- LetsMove handoff. Launching a build from outside `/Applications` makes LetsMove defer to
  the `/Applications` copy. The DerivedData instance then does not own the menubar item, so
  its CPU reads near 0. Measure the `/Applications` instance, or you measure the wrong process.
- TCC permission loss. Sign with the local identity (Step 1) to avoid it. An ad-hoc re-signed build has a new code signature. macOS treats it
  as a new app and drops its Screen Recording and Accessibility grants. The app then
  re-requests them and restarts once. Grant the permissions again after the install.
- Nesting. See Step 3. Always remove or overwrite the target bundle; never copy into it.
- Verification. To test a menubar change, run the `/Applications` copy as the only instance,
  grant permissions, wait for a stable PID, then sample. A single confounded reading is not proof.
