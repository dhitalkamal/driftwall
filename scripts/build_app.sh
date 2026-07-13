#!/bin/bash
# assemble LiveWallpaper.app from the release build and ad-hoc sign it for local use.
# usage: scripts/build_app.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="LiveWallpaper"
PRODUCT_NAME="LiveWallpaperApp"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

echo "building release binary"
swift build -c release --package-path "$ROOT"
BIN="$(swift build -c release --package-path "$ROOT" --show-bin-path)/$PRODUCT_NAME"

if [ ! -f "$BIN" ]; then
	echo "error: built executable not found at $BIN" >&2
	exit 1
fi

echo "assembling bundle at $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/scripts/Info.plist" "$APP/Contents/Info.plist"

echo "ad-hoc signing"
codesign --force --sign - --timestamp=none "$APP"

echo "done: $APP"
