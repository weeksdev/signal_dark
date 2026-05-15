#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h:h}"
HEADLESS=0
if [[ "${1:-}" == "--headless" ]]; then
  HEADLESS=1
  shift
fi

SCENARIO="${1:-tests/agent/scenarios/hunter_basic_attack.json}"
RUNNER_SCRIPT="tests/agent/AgentHarness.gd"
FORWARD_ARGS=()

shift $(( $# > 0 ? 1 : 0 ))
FORWARD_ARGS+=("$@")

if command -v godot >/dev/null 2>&1; then
  GODOT_BIN="godot"
elif command -v Godot >/dev/null 2>&1; then
  GODOT_BIN="Godot"
else
  echo "Godot executable not found in PATH. Install Godot 4 or add it to PATH." >&2
  exit 1
fi

cd "$PROJECT_ROOT"
GODOT_ARGS=()
if [[ "$HEADLESS" == "1" ]]; then
  GODOT_ARGS+=("--headless")
fi

exec "$GODOT_BIN" "${GODOT_ARGS[@]}" --path . -s "$RUNNER_SCRIPT" -- --scenario "$SCENARIO" "${FORWARD_ARGS[@]}"
