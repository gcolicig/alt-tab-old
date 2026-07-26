#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

SCHEME="${SCHEME:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-DerivedData}"
if [[ "$DERIVED_DATA_PATH" != /* ]]; then
  DERIVED_DATA_PATH="$ROOT_DIR/$DERIVED_DATA_PATH"
fi
BUILD_PRODUCTS_PATH="$DERIVED_DATA_PATH/Build/Products"
APP_PATH="$BUILD_PRODUCTS_PATH/$SCHEME/AltTab+.app"
MIN_XCODE_MAJOR=16
DEFAULT_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
LOCAL_CODE_SIGN_IDENTITY="${LOCAL_CODE_SIGN_IDENTITY:-AltTab+ Local Codesign}"

usage() {
  cat <<'EOF'
Usage: ./build.sh [--run] [--install] [--clean]

Builds AltTab+ locally without Apple Developer secrets.

Options:
  --run      Launch the built app after a successful build.
  --install  Copy the built app to /Applications after building.
  --clean    Remove local build output before building.
EOF
}

if [[ "$EUID" -eq 0 ]]; then
  echo "Do not run the whole build with sudo." >&2
  echo "Run ./build.sh --install as your normal user; the script will ask for sudo only when copying to /Applications." >&2
  exit 15
fi

RUN_APP=false
INSTALL_APP=false
CLEAN=false

for arg in "$@"; do
  case "$arg" in
    --run) RUN_APP=true ;;
    --install) INSTALL_APP=true ;;
    --clean) CLEAN=true ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $arg" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "${DEVELOPER_DIR:-}" && -x "$DEFAULT_DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
  export DEVELOPER_DIR="$DEFAULT_DEVELOPER_DIR"
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild was not found. Install Xcode $MIN_XCODE_MAJOR or newer, then run this again." >&2
  exit 10
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild is not usable. Open Xcode once, accept the license, and check xcode-select." >&2
  echo "This script also accepts: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./build.sh" >&2
  exit 11
fi

xcode_version="$(xcodebuild -version | awk '/^Xcode / { print $2 }')"
xcode_major="${xcode_version%%.*}"
if [[ "$xcode_major" -lt "$MIN_XCODE_MAJOR" ]]; then
  echo "Xcode $MIN_XCODE_MAJOR or newer is required. Found Xcode $xcode_version." >&2
  exit 12
fi

if command -v xcodegen >/dev/null 2>&1 && [[ -f project.yml ]]; then
  xcodegen generate
elif [[ -f project.yml ]]; then
  echo "project.yml exists, but xcodegen was not found. Install XcodeGen and try again." >&2
  exit 13
fi

if [[ ! -d alt-tab-macos.xcodeproj ]]; then
  echo "alt-tab-macos.xcodeproj is missing. Run this script from the repository root." >&2
  exit 14
fi

if [[ "$CLEAN" == true ]]; then
  rm -rf "$DERIVED_DATA_PATH"
fi

if [[ -d "$DERIVED_DATA_PATH" ]]; then
  foreign_owner_path="$(find "$DERIVED_DATA_PATH" ! -user "$(id -u)" -print -quit 2>/dev/null || true)"
  if [[ -n "$foreign_owner_path" || ! -w "$DERIVED_DATA_PATH" ]]; then
    echo "The build output contains files not owned by your user, likely from a previous sudo build." >&2
    echo "Fix it once with: sudo chown -R $(id -un) \"$DERIVED_DATA_PATH\"" >&2
    echo "Or remove it with: sudo rm -rf \"$DERIVED_DATA_PATH\"" >&2
    exit 16
  fi
fi

APP_CODE_SIGN_SETTINGS=()
if security find-identity -v -p codesigning 2>/dev/null | grep -Fq "$LOCAL_CODE_SIGN_IDENTITY"; then
  APP_CODE_SIGN_SETTINGS=(CODE_SIGN_IDENTITY="$LOCAL_CODE_SIGN_IDENTITY" CODE_SIGN_STYLE=Manual)
  echo "Using local code signing identity: $LOCAL_CODE_SIGN_IDENTITY"
else
  echo "No local code signing identity named '$LOCAL_CODE_SIGN_IDENTITY' was found." >&2
  echo "Run scripts/codesign/setup_local.sh once to keep macOS permissions stable across local builds." >&2
fi

for pod_scheme in AppCenter LetsMove ShortcutRecorder Sparkle SwiftyBeaver Pods-alt-tab-macos; do
  xcodebuild \
    -project Pods/Pods.xcodeproj \
    -scheme "$pod_scheme" \
    -configuration "$SCHEME" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    SYMROOT="$BUILD_PRODUCTS_PATH" \
    BUILD_DIR="$BUILD_PRODUCTS_PATH" \
    build
done

if [[ "${#APP_CODE_SIGN_SETTINGS[@]}" -gt 0 ]]; then
  xcodebuild \
    -project alt-tab-macos.xcodeproj \
    -scheme "$SCHEME" \
    -configuration "$SCHEME" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    SYMROOT="$BUILD_PRODUCTS_PATH" \
    BUILD_DIR="$BUILD_PRODUCTS_PATH" \
    "${APP_CODE_SIGN_SETTINGS[@]}" \
    build
else
  xcodebuild \
    -project alt-tab-macos.xcodeproj \
    -scheme "$SCHEME" \
    -configuration "$SCHEME" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    SYMROOT="$BUILD_PRODUCTS_PATH" \
    BUILD_DIR="$BUILD_PRODUCTS_PATH" \
    build
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build finished, but $APP_PATH was not produced." >&2
  exit 13
fi

if [[ "$INSTALL_APP" == true ]]; then
  if [[ -w /Applications ]]; then
    ditto "$APP_PATH" "/Applications/AltTab+.app"
  else
    sudo ditto "$APP_PATH" "/Applications/AltTab+.app"
  fi
  echo "Installed /Applications/AltTab+.app"
fi

if [[ "$RUN_APP" == true ]]; then
  open -n "$APP_PATH"
fi

echo "Built $APP_PATH"
