#!/usr/bin/env bash
set -e

DEVICE_ID="00008110-000C30A621C0A01E"       # xcodebuild UDID
DEVICECTL_ID="36206F28-2166-5A28-A701-3C577939CE7A" # xcrun devicectl UUID
TEAM_ID="XQ9D888PGU"
PROJECT="build/ios_export/SignalDark.xcodeproj"

echo "==> Exporting from Godot..."
/Applications/Godot.app/Contents/MacOS/Godot --headless --export-debug "iOS" "$PROJECT"

echo "==> Patching TARGETED_DEVICE_FAMILY..."
sed -i '' 's/TARGETED_DEVICE_FAMILY = "2"/TARGETED_DEVICE_FAMILY = "1"/g' "$PROJECT/project.pbxproj"

echo "==> Building with Xcode..."
xcodebuild \
  -project "$PROJECT" \
  -scheme SignalDark \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  build | grep -E "(error:|warning: .*error|FAILED|SUCCEEDED|BUILD)"

echo "==> Installing on device..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/SignalDark-*/Build/Products/Debug-iphoneos \
  -name "SignalDark.app" 2>/dev/null | xargs ls -dt 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
  echo "ERROR: Could not find built .app" >&2
  exit 1
fi

xcrun devicectl device install app --device "$DEVICECTL_ID" "$APP_PATH"
echo "==> Done. Launch Signal Dark on your iPhone."
