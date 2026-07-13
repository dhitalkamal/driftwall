#!/bin/bash
# notarize and staple dist/Driftwall.app for direct distribution.
# requires an Apple Developer Program account and a one-time keychain credential profile:
#   xcrun notarytool store-credentials driftwall-notary \
#     --apple-id "you@example.com" --team-id "YOURTEAMID" --password "app-specific-password"
# the app must already be signed with a Developer ID (run build_app.sh with
# DEVELOPER_ID_IDENTITY set) before notarizing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Driftwall.app"
ZIP="$ROOT/dist/Driftwall-notarize.zip"
PROFILE="${NOTARY_PROFILE:-driftwall-notary}"

if [ ! -d "$APP" ]; then
	echo "error: $APP not found. run scripts/build_app.sh first." >&2
	exit 1
fi

echo "zipping for submission"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "submitting to apple notary service (waits for result)"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait

echo "stapling ticket"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
rm -f "$ZIP"
echo "notarized and stapled: $APP"
