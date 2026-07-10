#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

SCHEME="${SCHEME:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-DerivedData}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$SCHEME/AltTab.app"

usage() {
  cat <<'EOF'
Usage: ./build.sh [--run] [--install] [--clean]

Builds AltTab Old locally without Apple Developer secrets.

Options:
  --run      Launch the built app after a successful build.
  --install  Copy the built app to /Applications after building.
  --clean    Remove local build output before building.
EOF
}

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

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild was not found. Install Xcode from the App Store, then run this again." >&2
  exit 10
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild is not usable. Open Xcode once, accept the license, and check xcode-select." >&2
  echo "A common fix is: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 11
fi

if [[ ! -d alt-tab-macos.xcworkspace ]]; then
  echo "alt-tab-macos.xcworkspace is missing. Run this script from the repository root." >&2
  exit 12
fi

if [[ "$CLEAN" == true ]]; then
  rm -rf "$DERIVED_DATA_PATH"
fi

xcodebuild \
  -workspace alt-tab-macos.xcworkspace \
  -scheme "$SCHEME" \
  -configuration "$SCHEME" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build finished, but $APP_PATH was not produced." >&2
  exit 13
fi

if [[ "$INSTALL_APP" == true ]]; then
  ditto "$APP_PATH" "/Applications/AltTab Old.app"
  echo "Installed /Applications/AltTab Old.app"
fi

if [[ "$RUN_APP" == true ]]; then
  open -n "$APP_PATH"
fi

echo "Built $APP_PATH"
