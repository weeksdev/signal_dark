#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h}"
cd "$ROOT_DIR"

DEBUG_MODE=0
GODOT_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --debug)
      DEBUG_MODE=1
      ;;
    *)
      GODOT_ARGS+=("$arg")
      ;;
  esac
done

if [[ "$DEBUG_MODE" -eq 1 ]]; then
  echo "[run.sh] debug logging enabled"
  GODOT_ARGS+=("--" "--signal-dark-debug")
fi

if command -v godot >/dev/null 2>&1; then
  exec godot --path "$ROOT_DIR" "${GODOT_ARGS[@]}"
elif command -v Godot >/dev/null 2>&1; then
  exec Godot --path "$ROOT_DIR" "${GODOT_ARGS[@]}"
else
  echo "Godot executable not found in PATH. Install Godot 4 or add it to PATH." >&2
  exit 1
fi
