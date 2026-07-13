#!/bin/bash
# assemble Driftwall.app from the release build. signs with a Developer ID if
# DEVELOPER_ID_IDENTITY is set (required for a distributable, notarizable build); otherwise
# ad-hoc signs for local use. hardened runtime is always enabled.
# usage: scripts/build_app.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Driftwall"
PRODUCT_NAME="DriftwallApp"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
IDENTITY="${DEVELOPER_ID_IDENTITY:-}"

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
if [ -f "$ROOT/scripts/$APP_NAME.icns" ]; then
	cp "$ROOT/scripts/$APP_NAME.icns" "$APP/Contents/Resources/$APP_NAME.icns"
fi

if [ -n "$IDENTITY" ]; then
	echo "signing with Developer ID (hardened runtime): $IDENTITY"
	codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
	echo "signed. next: scripts/notarize.sh to notarize and staple."
else
	echo "ad-hoc signing (hardened runtime) for local use"
	codesign --force --options runtime --sign - "$APP"
	echo "note: set DEVELOPER_ID_IDENTITY to produce a distributable, notarizable build."
fi

echo "done: $APP"
