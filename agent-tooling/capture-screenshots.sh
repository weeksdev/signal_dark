#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
RUNNER_SCRIPT="res://agent-tooling/screenshot_runner.gd"

if command -v godot >/dev/null 2>&1; then
  GODOT_BIN="godot"
elif command -v Godot >/dev/null 2>&1; then
  GODOT_BIN="Godot"
else
  echo "Godot executable not found in PATH. Install Godot 4 or add it to PATH." >&2
  exit 1
fi

MODE="all"
FORWARD_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --smoke)
      MODE="smoke"
      ;;
    *)
      FORWARD_ARGS+=("$arg")
      ;;
  esac
done

cd "$PROJECT_ROOT"
exec "$GODOT_BIN" --path "$PROJECT_ROOT" -s "$RUNNER_SCRIPT" -- --mode "$MODE" "${FORWARD_ARGS[@]}"
