#!/bin/bash
# package dist/Driftwall.app into a distributable dist/Driftwall.dmg with an Applications
# symlink for drag-to-install. run after build_app.sh (and notarize.sh for a shippable dmg).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Driftwall.app"
DMG="$ROOT/dist/Driftwall.dmg"

if [ ! -d "$APP" ]; then
	echo "error: $APP not found. run scripts/build_app.sh first." >&2
	exit 1
fi

STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "Driftwall" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"
echo "wrote $DMG"
