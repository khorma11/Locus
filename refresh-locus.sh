#!/bin/bash
# Re-sign and reinstall Locus. Free Apple ID certs expire every 7 days.
set -euo pipefail

DEVICE_NAME="${1:?Usage: DEVELOPMENT_TEAM=YOUR_TEAM_ID $0 \"Your iPhone Name\"}"
TEAM="${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to your Apple Developer Team ID}"
DERIVED_DATA="${TMPDIR:-/tmp}/Locus-refresh"

cd "$(dirname "$0")"
xcodegen generate
xcodebuild -project Locus.xcodeproj -scheme Locus -configuration Debug \
  -destination "platform=iOS,name=$DEVICE_NAME" -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=$TEAM build
APP="$DERIVED_DATA/Build/Products/Debug-iphoneos/Locus.app"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")
xcrun devicectl device install app --device "$DEVICE_NAME" "$APP"
xcrun devicectl device process launch --device "$DEVICE_NAME" \
  --terminate-existing "$BUNDLE_ID"
echo "Done. Locus is installed and running."
