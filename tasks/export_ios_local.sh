#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
cd "$ROOT_DIR"

if ! command -v godot >/dev/null 2>&1 && ! command -v Godot >/dev/null 2>&1; then
  echo "Godot executable not found in PATH." >&2
  exit 1
fi

GODOT_BIN="godot"
if ! command -v godot >/dev/null 2>&1; then
  GODOT_BIN="Godot"
fi

DEFAULT_EXPORT_ROOT="/tmp/signal_dark_build"
EXPORT_ROOT="${SIGNAL_DARK_IOS_EXPORT_ROOT:-$DEFAULT_EXPORT_ROOT}"
EXPORT_DIR="$EXPORT_ROOT/ios"
EXPORT_PATH="$EXPORT_DIR/SignalDark.xcodeproj"
LOG_PATH="$EXPORT_DIR/export-ios.log"
PRESET_PATH="$ROOT_DIR/export_presets.cfg"
BACKUP_PATH="$ROOT_DIR/export_presets.cfg.bak"
EXPORT_KIND="${SIGNAL_DARK_IOS_EXPORT_KIND:-debug}"

TEAM_ID="${SIGNAL_DARK_IOS_TEAM_ID:-}"
BUNDLE_ID="${SIGNAL_DARK_IOS_BUNDLE_ID:-com.weeksdev.signaldark.dev}"

if [[ -f "$BACKUP_PATH" ]]; then
  mv "$BACKUP_PATH" "$PRESET_PATH"
fi

if [[ -z "$TEAM_ID" ]]; then
  echo "SIGNAL_DARK_IOS_TEAM_ID is required for iOS export." >&2
  exit 1
fi

cleanup() {
  if [[ -f "$BACKUP_PATH" ]]; then
    mv "$BACKUP_PATH" "$PRESET_PATH"
  fi
}

cp "$PRESET_PATH" "$BACKUP_PATH"
trap cleanup EXIT INT TERM

perl -0pi -e 's/application\/app_store_team_id="[^"]*"/application\/app_store_team_id="'"$TEAM_ID"'"/g' "$PRESET_PATH"
perl -0pi -e 's/application\/bundle_identifier="[^"]*"/application\/bundle_identifier="'"$BUNDLE_ID"'"/g' "$PRESET_PATH"

rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"
rm -f "$LOG_PATH"

GODOT_EXPORT_FLAG="--export-debug"
if [[ "$EXPORT_KIND" == "release" ]]; then
  GODOT_EXPORT_FLAG="--export-release"
fi

if ! "$GODOT_BIN" --headless --verbose --path "$ROOT_DIR" --log-file "$LOG_PATH" "$GODOT_EXPORT_FLAG" iOS "$EXPORT_PATH"; then
  echo "iOS export failed." >&2
  echo "Verbose log: $LOG_PATH" >&2
  if [[ -f "$LOG_PATH" ]]; then
    echo "---- export-ios.log (tail) ----" >&2
    tail -n 120 "$LOG_PATH" >&2
    echo "---- end log tail ----" >&2
  fi
  exit 1
fi

echo "Exported iOS Xcode project to $EXPORT_PATH"
echo "Verbose log: $LOG_PATH"
echo "Export kind: $EXPORT_KIND"
echo "Export root: $EXPORT_ROOT"
echo "Next: open it in Xcode, sign with your Apple account/team, and run on the connected iPhone."
