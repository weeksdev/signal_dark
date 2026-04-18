#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h}"
cd "$ROOT_DIR"

if command -v godot >/dev/null 2>&1; then
  exec godot --path "$ROOT_DIR"
elif command -v Godot >/dev/null 2>&1; then
  exec Godot --path "$ROOT_DIR"
else
  echo "Godot executable not found in PATH. Install Godot 4 or add it to PATH." >&2
  exit 1
fi
