#!/bin/bash
# build Driftwall.app and install it to /Applications so it launches from Finder, Launchpad, and
# Spotlight. quits any running instance first, then registers the bundle with LaunchServices.
# usage: scripts/install.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Driftwall"
SRC="$ROOT/dist/$APP_NAME.app"
DEST="/Applications/$APP_NAME.app"

# build the bundle (release, ad-hoc signed for local use unless DEVELOPER_ID_IDENTITY is set).
"$ROOT/scripts/build_app.sh"

# quit any running instance so the bundle can be replaced cleanly and no stale copy keeps
# rendering. covers both the bundled app ("Driftwall") and dev/test builds ("DriftwallApp").
pkill -x "$APP_NAME" 2>/dev/null || true
pkill -x "${PRODUCT_NAME:-DriftwallApp}" 2>/dev/null || true

echo "installing to $DEST"
rm -rf "$DEST"
cp -R "$SRC" "$DEST"

# register so it appears in Launchpad/Spotlight right away.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
"$LSREGISTER" -f "$DEST"

echo "installed: $DEST"
echo "launch from Finder > Applications, Launchpad, or Spotlight (Cmd-Space, \"Driftwall\")."
